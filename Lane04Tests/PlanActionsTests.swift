//
//  PlanActionsTests.swift
//  Lane04Tests
//
//  Planification (calendrier) : création PLANNED, filtrage jour/semaine,
//  suppression, replanification (garde l'heure, repasse en PLANNED), grille semaine.
//

import Testing
import Foundation
import SwiftData
@testable import Lane04

@MainActor
struct PlanActionsTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([RunProtocol.self, ProtocolBlock.self, ProtocolStep.self,
                             OperatorProfile.self, RunLog.self, PlannedSession.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @discardableResult
    private func insertProtocol(_ ctx: ModelContext, name: String = "VMA courte") -> RunProtocol {
        let p = RunProtocol(name: name, discipline: .vma, isTemplate: false, state: .draft)
        ctx.insert(p); try? ctx.save()
        return p
    }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
    }

    @Test func plan_createsPlannedSessionOnDay() throws {
        let ctx = try makeContext()
        let proto = insertProtocol(ctx)
        let d = day(2026, 7, 9)

        let session = PlanActions.plan(proto, on: d, in: ctx)
        #expect(session.state == .planned)
        #expect(session.proto?.id == proto.id)
        // Heure par défaut = matin (07:00).
        let h = Calendar.current.component(.hour, from: session.date)
        #expect(h == PlanActions.defaultHour)
        #expect(Calendar.current.isDate(session.date, inSameDayAs: d))
        #expect(try ctx.fetchCount(FetchDescriptor<PlannedSession>()) == 1)
    }

    @Test func sessions_onDay_filtersCorrectly() throws {
        let ctx = try makeContext()
        let proto = insertProtocol(ctx)
        PlanActions.plan(proto, on: day(2026, 7, 9), in: ctx)
        PlanActions.plan(proto, on: day(2026, 7, 9), in: ctx)
        PlanActions.plan(proto, on: day(2026, 7, 11), in: ctx)

        let all = try ctx.fetch(FetchDescriptor<PlannedSession>())
        #expect(PlanActions.sessions(on: day(2026, 7, 9), in: all).count == 2)
        #expect(PlanActions.sessions(on: day(2026, 7, 11), in: all).count == 1)
        #expect(PlanActions.sessions(on: day(2026, 7, 10), in: all).isEmpty)
    }

    @Test func sessions_inWeek_countsWholeWeek() throws {
        let ctx = try makeContext()
        let proto = insertProtocol(ctx)
        // Semaine du lundi 6 au dimanche 12 juillet 2026.
        PlanActions.plan(proto, on: day(2026, 7, 6), in: ctx)   // lundi
        PlanActions.plan(proto, on: day(2026, 7, 12), in: ctx)  // dimanche
        PlanActions.plan(proto, on: day(2026, 7, 13), in: ctx)  // lundi suivant (hors semaine)

        let all = try ctx.fetch(FetchDescriptor<PlannedSession>())
        #expect(PlanActions.sessions(inWeekOf: day(2026, 7, 9), in: all).count == 2)
    }

    @Test func remove_deletesSession() throws {
        let ctx = try makeContext()
        let proto = insertProtocol(ctx)
        let s = PlanActions.plan(proto, on: day(2026, 7, 9), in: ctx)
        PlanActions.remove(s, in: ctx)
        #expect(try ctx.fetchCount(FetchDescriptor<PlannedSession>()) == 0)
    }

    @Test func reschedule_movesDayKeepsTimeResetsPlanned() throws {
        let ctx = try makeContext()
        let proto = insertProtocol(ctx)
        let s = PlanActions.plan(proto, on: day(2026, 7, 9), in: ctx)
        s.state = .scheduled   // simulate committed to watch
        try ctx.save()

        PlanActions.reschedule(s, to: day(2026, 7, 12), in: ctx)
        #expect(Calendar.current.isDate(s.date, inSameDayAs: day(2026, 7, 12)))
        #expect(Calendar.current.component(.hour, from: s.date) == PlanActions.defaultHour)
        // La montre ne connaît plus la nouvelle date → re-commit nécessaire.
        #expect(s.state == .planned)
    }

    @Test func deletingProtocol_cascadesToPlans() throws {
        let ctx = try makeContext()
        let proto = insertProtocol(ctx)
        PlanActions.plan(proto, on: day(2026, 7, 9), in: ctx)
        #expect(try ctx.fetchCount(FetchDescriptor<PlannedSession>()) == 1)

        ProtocolActions.delete(proto, in: ctx)
        // Cascade : le plan disparaît avec son protocole.
        #expect(try ctx.fetchCount(FetchDescriptor<PlannedSession>()) == 0)
    }

    @Test func weekDays_returnsSevenMondayFirst() {
        let days = PlanActions.weekDays(containing: day(2026, 7, 9)) // jeudi
        #expect(days.count == 7)
        // Premier jour = lundi.
        #expect(PlanActions.weekCalendar.component(.weekday, from: days[0]) == 2)
        #expect(Calendar.current.component(.day, from: days[0]) == 6)   // lundi 6
        #expect(Calendar.current.component(.day, from: days[6]) == 12)  // dimanche 12
    }
}
