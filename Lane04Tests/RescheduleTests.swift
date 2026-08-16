//
//  RescheduleTests.swift
//  Lane04Tests
//
//  Replanification d'une séance DÉJÀ transmise. L'invariant testé ici est le seul
//  qui compte : le retrait de l'occurrence sur la montre précède TOUJOURS la
//  reprogrammation, et un retrait en échec n'injecte jamais. Deux occurrences de la
//  même séance sur la montre = faute produit, pas simple bug.
//

import Testing
import Foundation
import SwiftData
import WorkoutKit
@testable import Lane04

/// Double de la montre : enregistre l'ORDRE des appels et simule ce que la montre
/// détient réellement. `removalSucceeds = false` = l'occurrence survit au retrait.
@MainActor
final class FakeWatchScheduler: WatchScheduling {
    enum Call: Equatable {
        case authorize
        case isScheduled(UUID)
        case schedule(UUID)
        case remove(UUID)
    }

    private(set) var calls: [Call] = []
    var live: Set<UUID> = []
    var authorized = true
    var removalSucceeds = true
    private(set) var lastScheduledAt: DateComponents?

    /// Les appels qui MUTENT la montre, dans l'ordre (les lectures ne comptent pas).
    var mutations: [Call] {
        calls.filter { if case .schedule = $0 { return true }; if case .remove = $0 { return true }; return false }
    }

    func requestAuthorization() async -> Bool {
        calls.append(.authorize)
        return authorized
    }

    func isScheduled(_ planID: UUID) async -> Bool {
        calls.append(.isScheduled(planID))
        return live.contains(planID)
    }

    func schedule(_ workout: CustomWorkout, id: UUID, at date: DateComponents) async {
        calls.append(.schedule(id))
        live.insert(id)
        lastScheduledAt = date
    }

    func remove(_ planID: UUID) async {
        calls.append(.remove(planID))
        if removalSucceeds { live.remove(planID) }
    }
}

/// ⚠️ `.serialized` est OBLIGATOIRE : `InjectionService.backend` est un `static var`
/// partagé. En parallèle, deux tests s'échangent leur double et pilotent la mauvaise
/// « montre » (symptôme observé : la poignée persistée ne correspond pas à celle du
/// fake). La sérialisation est le prix du seam statique.
@MainActor
@Suite(.serialized)
struct RescheduleTests {

    // MARK: - Fixtures

    private func makeContext(url: URL? = nil) throws -> ModelContext {
        let schema = Schema(LaneSchema.models)
        let config = url.map { ModelConfiguration(schema: schema, url: $0) }
            ?? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: config))
    }

    /// Protocole valide au sens de `ProtocolValidator` (échauffement + corps répété).
    private func insertProtocol(_ ctx: ModelContext) -> RunProtocol {
        let body = ProtocolBlock(title: "CORPS", iterations: 8, order: 1, steps: [
            ProtocolStep(role: .work, goalKind: .time, goalValue: 30,
                         percentVMA: 105, targetsPace: true, order: 0),
            ProtocolStep(role: .recovery, goalKind: .time, goalValue: 30, percentVMA: 55, order: 1)
        ])
        let warmup = ProtocolBlock(title: "WARM-UP", iterations: 1, order: 0, steps: [
            ProtocolStep(role: .warmup, goalKind: .distance, goalValue: 2000, percentVMA: 60, order: 0)
        ])
        let proto = RunProtocol(name: "8 × 30/30", discipline: .vma, state: .synced,
                                blocks: [warmup, body])
        ctx.insert(proto)
        try? ctx.save()
        return proto
    }

    private func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 7) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    private func withFake(_ fake: FakeWatchScheduler, _ body: () async -> Void) async {
        let previous = InjectionService.backend
        InjectionService.backend = fake
        await body()
        InjectionService.backend = previous
    }

    // MARK: - 1. Migration d'un store existant

    /// Le store se rouvre après l'ajout des deux optionnels et les lignes déjà
    /// présentes n'ont aucune poignée de retrait (nil), sans plan de migration.
    /// ⚠️ Portée : vérifie l'exigence observable (rouverture + nil), sur un store
    /// écrit par le schéma courant. Ne fabrique pas un binaire d'avant le changement.
    @Test func existingStore_reopensWithNilScheduleHandles() throws {
        let url = URL.temporaryDirectory.appending(path: "lane04-migration-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }

        let planID: UUID
        do {
            let ctx = try makeContext(url: url)
            let proto = insertProtocol(ctx)
            let session = PlanActions.plan(proto, on: day(2026, 8, 20), in: ctx)
            planID = session.id
            try ctx.save()
        }

        let reopened = try makeContext(url: url)
        let sessions = try reopened.fetch(FetchDescriptor<PlannedSession>())
        let session = try #require(sessions.first { $0.id == planID })

        #expect(sessions.count == 1)
        #expect(session.scheduledPlanID == nil)   // jamais transmise
        #expect(session.scheduledAt == nil)
        #expect(session.state == .planned)
        #expect(session.proto != nil)             // la relation survit
    }

    @Test func freshPlannedSession_hasNoWatchHandle() throws {
        let ctx = try makeContext()
        let session = PlanActions.plan(insertProtocol(ctx), on: day(2026, 8, 20), in: ctx)

        #expect(session.scheduledPlanID == nil)
        #expect(PlanActions.canReschedule(session))   // PLANNED : déplaçable localement
    }

    // MARK: - 2. Injection avec date

    @Test func schedule_transmitsAtTheGivenDate_andReturnsHandle() async throws {
        let ctx = try makeContext()
        let proto = insertProtocol(ctx)
        let workout = try WorkoutBuilder.validatedCustomWorkout(for: proto, vma: 16)
        let when = day(2026, 8, 20, hour: 7)
        let fake = FakeWatchScheduler()

        await withFake(fake) {
            let id = try? await InjectionService.schedule(workout, at: when)
            #expect(id != nil)
            #expect(fake.live.contains(id!))          // la montre détient la séance
        }

        let sent = try #require(fake.lastScheduledAt)
        #expect(sent.year == 2026 && sent.month == 8 && sent.day == 20 && sent.hour == 7)
    }

    @Test func schedule_withoutAuthorization_transmitsNothing() async throws {
        let ctx = try makeContext()
        let workout = try WorkoutBuilder.validatedCustomWorkout(for: insertProtocol(ctx), vma: 16)
        let fake = FakeWatchScheduler()
        fake.authorized = false

        await withFake(fake) {
            await #expect(throws: InjectionError.self) {
                try await InjectionService.schedule(workout, at: day(2026, 8, 20))
            }
        }
        #expect(fake.mutations.isEmpty)
    }

    // MARK: - 3. Changement de date sur séance injectée — le RETRAIT D'ABORD

    @Test func reschedule_removesFromWatchBeforeScheduling() async throws {
        let ctx = try makeContext()
        let proto = insertProtocol(ctx)
        let session = PlanActions.plan(proto, on: day(2026, 8, 20), in: ctx)
        let oldPlanID = UUID()
        PlanActions.markScheduled(session, planID: oldPlanID, at: session.date, in: ctx)

        let fake = FakeWatchScheduler()
        fake.live = [oldPlanID]                       // la montre détient l'ancienne
        let controller = InjectionController()

        await withFake(fake) {
            await controller.reschedule(session: session, to: day(2026, 8, 27), vma: 16,
                                        mode: .fast, reduceMotion: true, context: ctx)
        }

        // L'ORDRE est l'invariant : retrait, PUIS programmation. Jamais l'inverse.
        #expect(fake.mutations.count == 2)
        #expect(fake.mutations.first == .remove(oldPlanID))
        if case .schedule(let newID)? = fake.mutations.last {
            #expect(newID != oldPlanID)               // nouvelle poignée
            #expect(fake.live == [newID])             // UNE seule occurrence sur la montre
            #expect(session.scheduledPlanID == newID) // poignée persistée
        } else {
            Issue.record("la reprogrammation n'a pas eu lieu")
        }

        #expect(session.state == .scheduled)
        #expect(Calendar.current.component(.day, from: session.date) == 27)
    }

    @Test func reschedule_keepsExactlyOneOccurrenceOnTheWatch() async throws {
        let ctx = try makeContext()
        let session = PlanActions.plan(insertProtocol(ctx), on: day(2026, 8, 20), in: ctx)
        let oldPlanID = UUID()
        PlanActions.markScheduled(session, planID: oldPlanID, at: session.date, in: ctx)

        let fake = FakeWatchScheduler()
        fake.live = [oldPlanID]
        let controller = InjectionController()

        await withFake(fake) {
            await controller.reschedule(session: session, to: day(2026, 8, 27), vma: 16,
                                        mode: .fast, reduceMotion: true, context: ctx)
        }

        #expect(fake.live.count == 1)                 // jamais deux séances sur la montre
        #expect(!fake.live.contains(oldPlanID))       // l'ancienne a bien disparu
    }

    // MARK: - 4. Échec du retrait — on n'injecte PAS

    @Test func reschedule_whenRemovalFails_neverSchedules() async throws {
        let ctx = try makeContext()
        let session = PlanActions.plan(insertProtocol(ctx), on: day(2026, 8, 20), in: ctx)
        let oldPlanID = UUID()
        PlanActions.markScheduled(session, planID: oldPlanID, at: session.date, in: ctx)

        let fake = FakeWatchScheduler()
        fake.live = [oldPlanID]
        fake.removalSucceeds = false                  // l'occurrence SURVIT au retrait
        let controller = InjectionController()

        await withFake(fake) {
            await controller.reschedule(session: session, to: day(2026, 8, 27), vma: 16,
                                        mode: .fast, reduceMotion: true, context: ctx)
        }

        // Aucune programmation : réinjecter aurait créé le doublon.
        #expect(!fake.mutations.contains { if case .schedule = $0 { return true }; return false })
        #expect(fake.live == [oldPlanID])             // la montre est inchangée
    }

    @Test func reschedule_whenRemovalFails_doesNotLieAboutTheWatch() async throws {
        let ctx = try makeContext()
        let session = PlanActions.plan(insertProtocol(ctx), on: day(2026, 8, 20), in: ctx)
        let oldPlanID = UUID()
        PlanActions.markScheduled(session, planID: oldPlanID, at: session.date, in: ctx)

        let fake = FakeWatchScheduler()
        fake.live = [oldPlanID]
        fake.removalSucceeds = false
        let controller = InjectionController()

        await withFake(fake) {
            await controller.reschedule(session: session, to: day(2026, 8, 27), vma: 16,
                                        mode: .fast, reduceMotion: true, context: ctx)
        }

        // L'état local reflète ce que la montre détient VRAIMENT : l'ancienne date.
        #expect(session.state == .scheduled)
        #expect(session.scheduledPlanID == oldPlanID)
        #expect(Calendar.current.component(.day, from: session.date) == 20)

        // La faute nomme sa cause (règle n°10).
        if case .fault(let message) = controller.phase {
            #expect(message.contains("RESCHEDULE ABORTED"))
        } else {
            Issue.record("une faute nommée était attendue, phase = \(controller.phase)")
        }
    }

    /// Séance transmise par un build antérieur à la poignée de retrait : on refuse
    /// plutôt que de déplacer à l'aveugle (le doublon serait invisible jusqu'au jour J).
    @Test func reschedule_withoutWatchHandle_refusesAndTransmitsNothing() async throws {
        let ctx = try makeContext()
        let session = PlanActions.plan(insertProtocol(ctx), on: day(2026, 8, 20), in: ctx)
        session.state = .scheduled                    // SCHEDULED sans scheduledPlanID
        try ctx.save()

        let fake = FakeWatchScheduler()
        let controller = InjectionController()

        await withFake(fake) {
            await controller.reschedule(session: session, to: day(2026, 8, 27), vma: 16,
                                        mode: .fast, reduceMotion: true, context: ctx)
        }

        #expect(fake.mutations.isEmpty)
        #expect(!PlanActions.canReschedule(session))
        #expect(Calendar.current.component(.day, from: session.date) == 20)
    }

    // MARK: - Séance non transmise : déplacement local, sans toucher à la montre

    @Test func reschedule_plannedSession_movesLocallyWithoutTouchingTheWatch() async throws {
        let ctx = try makeContext()
        let session = PlanActions.plan(insertProtocol(ctx), on: day(2026, 8, 20), in: ctx)

        let fake = FakeWatchScheduler()
        await withFake(fake) {
            _ = PlanActions.reschedule(session, to: day(2026, 8, 27), in: ctx)
        }

        #expect(fake.mutations.isEmpty)
        #expect(session.state == .planned)
        #expect(Calendar.current.component(.day, from: session.date) == 27)
    }
}
