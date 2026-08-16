//
//  MonthCalendarTests.swift
//  Lane04Tests
//
//  Vue MOIS du calendrier : grille de semaines complètes (lundi en tête), filtrage
//  au mois calendaire, navigation ‹ ›, et la garantie structurante — un protocole
//  SANS occasion planifiée n'apparaît nulle part, puisque la grille lit les
//  `PlannedSession`, jamais les `RunProtocol`.
//

import Testing
import Foundation
import SwiftData
@testable import Lane04

@MainActor
struct MonthCalendarTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(LaneSchema.models)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @discardableResult
    private func insertProtocol(_ ctx: ModelContext, _ discipline: Discipline = .vma) -> RunProtocol {
        let proto = RunProtocol(
            name: "Séance", discipline: discipline, isTemplate: false, state: .draft,
            blocks: [ProtocolBlock(title: "B", iterations: 1, steps: [
                ProtocolStep(role: .work, goalKind: .time, goalValue: 600, percentVMA: 100, targetsPace: true)
            ])]
        )
        ctx.insert(proto)
        try? ctx.save()
        return proto
    }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        PlanActions.weekCalendar.date(from: DateComponents(year: y, month: m, day: d, hour: 7))!
    }

    // MARK: - Grille

    /// Toujours des semaines complètes : un multiple de 7, lundi en tête.
    @Test(arguments: [(2026, 8), (2026, 2), (2026, 3), (2027, 2), (2024, 2)])
    func monthGrid_isWholeWeeksStartingMonday(year: Int, month: Int) {
        let grid = PlanActions.monthGridDays(containing: day(year, month, 15))

        #expect(grid.count % 7 == 0)
        #expect(grid.count >= 28 && grid.count <= 42)
        #expect(PlanActions.weekCalendar.component(.weekday, from: grid[0]) == 2) // lundi
    }

    /// La grille couvre tout le mois, débordement des mois voisins compris.
    @Test func monthGrid_coversEveryDayOfTheMonth() {
        let cal = PlanActions.weekCalendar
        let reference = day(2026, 8, 1)
        let grid = PlanActions.monthGridDays(containing: reference)
        let inMonth = grid.filter { PlanActions.isSameMonth($0, as: reference) }

        #expect(inMonth.count == cal.range(of: .day, in: .month, for: reference)!.count) // 31
        #expect(grid.first! <= day(2026, 8, 1))
        #expect(grid.last! >= day(2026, 8, 31))
    }

    // MARK: - Mois SANS séance

    @Test func emptyMonth_hasNoSessionsAndZeroLoad() throws {
        let ctx = try makeContext()
        let plans = try ctx.fetch(FetchDescriptor<PlannedSession>())

        #expect(PlanActions.sessions(inMonthOf: day(2026, 8, 15), in: plans).isEmpty)
        #expect(PlanActions.monthlyLoad(inMonthOf: day(2026, 8, 15), in: plans, vma: 16) == 0)
        #expect(!PlanActions.monthGridDays(containing: day(2026, 8, 15)).isEmpty) // la grille existe quand même
    }

    /// Un mois vide bordé de mois pleins ne récupère rien de ses voisins.
    @Test func emptyMonth_isNotPollutedByNeighbours() throws {
        let ctx = try makeContext()
        let proto = insertProtocol(ctx)
        PlanActions.plan(proto, on: day(2026, 7, 31), in: ctx)
        PlanActions.plan(proto, on: day(2026, 9, 1), in: ctx)
        let plans = try ctx.fetch(FetchDescriptor<PlannedSession>())

        #expect(PlanActions.sessions(inMonthOf: day(2026, 8, 15), in: plans).isEmpty)
        #expect(PlanActions.sessions(inMonthOf: day(2026, 7, 15), in: plans).count == 1)
        #expect(PlanActions.sessions(inMonthOf: day(2026, 9, 15), in: plans).count == 1)
    }

    // MARK: - Mois chargé

    @Test func loadedMonth_countsAndSumsOnlyItsOwnSessions() throws {
        let ctx = try makeContext()
        let vma = insertProtocol(ctx, .vma)
        let recup = insertProtocol(ctx, .recup)

        for d in [1, 5, 12, 12, 20, 31] {                    // 12 août porte 2 séances
            PlanActions.plan(d == 5 ? recup : vma, on: day(2026, 8, d), in: ctx)
        }
        PlanActions.plan(vma, on: day(2026, 9, 3), in: ctx)   // hors mois
        let plans = try ctx.fetch(FetchDescriptor<PlannedSession>())

        let august = PlanActions.sessions(inMonthOf: day(2026, 8, 15), in: plans)
        #expect(august.count == 6)
        #expect(august.map(\.date) == august.map(\.date).sorted())   // triées

        // Plusieurs séances le même jour : la case du 12 en porte bien 2.
        #expect(PlanActions.sessions(on: day(2026, 8, 12), in: plans).count == 2)

        let load = PlanActions.monthlyLoad(inMonthOf: day(2026, 8, 15), in: plans, vma: 16)
        #expect(load > 0)
        #expect(load == august.reduce(0) { $0 + WorkoutBuilder.trimp(for: $1.proto!, vma: 16) })
    }

    /// Le marqueur d'un jour tient au tag du protocole : la teinte vient de la rampe
    /// thermique existante, jamais d'une couleur inventée pour le calendrier.
    @Test func dayMarkers_carryTheDisciplineOfEachSession() throws {
        let ctx = try makeContext()
        PlanActions.plan(insertProtocol(ctx, .vma), on: day(2026, 8, 12), in: ctx)
        PlanActions.plan(insertProtocol(ctx, .recup), on: day(2026, 8, 12), in: ctx)
        let plans = try ctx.fetch(FetchDescriptor<PlannedSession>())

        let disciplines = PlanActions.sessions(on: day(2026, 8, 12), in: plans)
            .compactMap { $0.proto?.discipline }
        #expect(Set(disciplines) == [.vma, .recup])
        #expect(Discipline.vma.tint != Discipline.recup.tint)
    }

    // MARK: - Changement de mois

    @Test func shiftMonth_movesForwardAndBack() {
        let cal = PlanActions.weekCalendar
        let august = day(2026, 8, 15)

        let september = PlanActions.month(august, offset: 1)
        let july = PlanActions.month(august, offset: -1)

        #expect(cal.component(.month, from: september) == 9)
        #expect(cal.component(.month, from: july) == 7)
        #expect(cal.component(.year, from: september) == 2026)
    }

    @Test func shiftMonth_crossesYearBoundaries() {
        let cal = PlanActions.weekCalendar

        let january = PlanActions.month(day(2026, 12, 15), offset: 1)
        #expect(cal.component(.month, from: january) == 1)
        #expect(cal.component(.year, from: january) == 2027)

        let december = PlanActions.month(day(2026, 1, 15), offset: -1)
        #expect(cal.component(.month, from: december) == 12)
        #expect(cal.component(.year, from: december) == 2025)
    }

    /// 31 janvier + 1 mois doit borner à fin février, jamais déborder sur mars —
    /// sinon la navigation « saute » un mois sous les doigts de l'athlète.
    @Test func shiftMonth_clampsToShorterMonths() {
        let cal = PlanActions.weekCalendar
        let february = PlanActions.month(day(2026, 1, 31), offset: 1)

        #expect(cal.component(.month, from: february) == 2)
        #expect(cal.component(.day, from: february) == 28)   // 2026 n'est pas bissextile
    }

    @Test func shiftMonth_changesWhichSessionsAreShown() throws {
        let ctx = try makeContext()
        let proto = insertProtocol(ctx)
        PlanActions.plan(proto, on: day(2026, 8, 10), in: ctx)
        PlanActions.plan(proto, on: day(2026, 9, 10), in: ctx)
        PlanActions.plan(proto, on: day(2026, 9, 20), in: ctx)
        let plans = try ctx.fetch(FetchDescriptor<PlannedSession>())

        let august = day(2026, 8, 15)
        #expect(PlanActions.sessions(inMonthOf: august, in: plans).count == 1)
        #expect(PlanActions.sessions(inMonthOf: PlanActions.month(august, offset: 1), in: plans).count == 2)
        #expect(PlanActions.sessions(inMonthOf: PlanActions.month(august, offset: -1), in: plans).isEmpty)
    }

    // MARK: - Protocole sans date : invisible partout

    /// Un protocole sans `PlannedSession` n'a aucune date : il ne peut apparaître
    /// dans aucune case, aucun mois, et ne pèse sur aucune CHARGE.
    @Test func protocolWithoutPlannedSession_appearsNowhere() throws {
        let ctx = try makeContext()
        insertProtocol(ctx)                                   // jamais planifié
        let plans = try ctx.fetch(FetchDescriptor<PlannedSession>())

        #expect(plans.isEmpty)
        #expect(try ctx.fetchCount(FetchDescriptor<RunProtocol>()) == 1)   // il existe bien

        for offset in -2...2 {
            let month = PlanActions.month(day(2026, 8, 15), offset: offset)
            #expect(PlanActions.sessions(inMonthOf: month, in: plans).isEmpty)
            #expect(PlanActions.monthlyLoad(inMonthOf: month, in: plans, vma: 16) == 0)
            for d in PlanActions.monthGridDays(containing: month) {
                #expect(PlanActions.sessions(on: d, in: plans).isEmpty)
            }
        }
    }

    /// Planifier puis déplanifier remet le protocole hors calendrier (pas de résidu).
    @Test func removingThePlan_takesTheProtocolOffTheCalendar() throws {
        let ctx = try makeContext()
        let proto = insertProtocol(ctx)
        let session = PlanActions.plan(proto, on: day(2026, 8, 12), in: ctx)
        #expect(PlanActions.sessions(on: day(2026, 8, 12), in: try ctx.fetch(FetchDescriptor<PlannedSession>())).count == 1)

        _ = PlanActions.remove(session, in: ctx)

        let plans = try ctx.fetch(FetchDescriptor<PlannedSession>())
        #expect(plans.isEmpty)
        #expect(PlanActions.sessions(inMonthOf: day(2026, 8, 15), in: plans).isEmpty)
    }
}
