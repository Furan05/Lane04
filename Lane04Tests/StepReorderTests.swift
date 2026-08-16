//
//  StepReorderTests.swift
//  Lane04Tests
//
//  Réordonnancement des pas d'un bloc (glisser-déposer). Couvre la mécanique d'ordre
//  et sa persistance ; l'invalidation de l'état injecté est testée séparément une fois
//  la sémantique tranchée.
//

import Testing
import Foundation
import SwiftData
import WorkoutKit   // CustomWorkout.blocks — import explicite requis en test
@testable import Lane04

@MainActor
struct StepReorderTests {

    private func makeContext(url: URL? = nil) throws -> ModelContext {
        let schema = Schema(LaneSchema.models)
        let config = url.map { ModelConfiguration(schema: schema, url: $0) }
            ?? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: config))
    }

    /// Bloc à 4 pas identifiables par leur objectif : 10 / 20 / 30 / 40 secondes.
    @discardableResult
    private func insertBlock(_ ctx: ModelContext, state: ProtocolState = .draft) -> (RunProtocol, ProtocolBlock) {
        let steps = (1...4).map { i in
            ProtocolStep(role: i.isMultiple(of: 2) ? .recovery : .work,
                         goalKind: .time, goalValue: Double(i * 10),
                         percentVMA: i.isMultiple(of: 2) ? 55 : 105,
                         targetsPace: !i.isMultiple(of: 2), order: i - 1)
        }
        let block = ProtocolBlock(title: "CORPS", iterations: 8, order: 0, steps: steps)
        let proto = RunProtocol(name: "Séance", discipline: .vma, isTemplate: false,
                                state: state, blocks: [block])
        ctx.insert(proto)
        try? ctx.save()
        return (proto, block)
    }

    /// La séquence lue dans l'ordre de `order` — la seule vérité d'affichage.
    private func sequence(_ block: ProtocolBlock) -> [Int] {
        block.steps.sorted { $0.order < $1.order }.map { Int($0.goalValue) }
    }

    private func orders(_ block: ProtocolBlock) -> [Int] {
        block.steps.sorted { $0.order < $1.order }.map(\.order)
    }

    // MARK: - Déplacement vers le haut

    @Test func moveUp_placesStepBeforeItsPredecessor() throws {
        let ctx = try makeContext()
        let (_, block) = insertBlock(ctx)
        let third = block.steps.first { $0.goalValue == 30 }!

        ProtocolActions.moveStep(third, to: 1, in: block, context: ctx)

        #expect(sequence(block) == [10, 30, 20, 40])
        #expect(orders(block) == [0, 1, 2, 3])   // contigus, jamais de trou
    }

    @Test func moveUp_toFirstPosition() throws {
        let ctx = try makeContext()
        let (_, block) = insertBlock(ctx)
        let last = block.steps.first { $0.goalValue == 40 }!

        ProtocolActions.moveStep(last, to: 0, in: block, context: ctx)

        #expect(sequence(block) == [40, 10, 20, 30])
        #expect(orders(block) == [0, 1, 2, 3])
    }

    // MARK: - Déplacement vers le bas

    @Test func moveDown_placesStepAfterItsSuccessor() throws {
        let ctx = try makeContext()
        let (_, block) = insertBlock(ctx)
        let second = block.steps.first { $0.goalValue == 20 }!

        ProtocolActions.moveStep(second, to: 2, in: block, context: ctx)

        #expect(sequence(block) == [10, 30, 20, 40])
        #expect(orders(block) == [0, 1, 2, 3])
    }

    @Test func moveDown_toLastPosition() throws {
        let ctx = try makeContext()
        let (_, block) = insertBlock(ctx)
        let first = block.steps.first { $0.goalValue == 10 }!

        ProtocolActions.moveStep(first, to: 3, in: block, context: ctx)

        #expect(sequence(block) == [20, 30, 40, 10])
    }

    // MARK: - Bornes : premier et dernier élément

    @Test func movingFirstStepUp_isANoOp() throws {
        let ctx = try makeContext()
        let (_, block) = insertBlock(ctx)
        let first = block.steps.first { $0.goalValue == 10 }!

        #expect(ProtocolActions.moveStep(first, to: 0, in: block, context: ctx) == false)
        #expect(sequence(block) == [10, 20, 30, 40])
    }

    @Test func movingLastStepDown_isANoOp() throws {
        let ctx = try makeContext()
        let (_, block) = insertBlock(ctx)
        let last = block.steps.first { $0.goalValue == 40 }!

        #expect(ProtocolActions.moveStep(last, to: 3, in: block, context: ctx) == false)
        #expect(sequence(block) == [10, 20, 30, 40])
    }

    /// Un dépôt hors bornes est ramené dans la séquence, jamais rejeté ni crashé.
    @Test func targetBeyondBounds_isClamped() throws {
        let ctx = try makeContext()
        let (_, block) = insertBlock(ctx)
        let first = block.steps.first { $0.goalValue == 10 }!

        ProtocolActions.moveStep(first, to: 99, in: block, context: ctx)
        #expect(sequence(block) == [20, 30, 40, 10])

        let last = block.steps.first { $0.goalValue == 10 }!
        ProtocolActions.moveStep(last, to: -5, in: block, context: ctx)
        #expect(sequence(block) == [10, 20, 30, 40])
    }

    @Test func singleStepBlock_cannotBeReordered() throws {
        let ctx = try makeContext()
        let step = ProtocolStep(role: .warmup, goalKind: .distance, goalValue: 2000,
                                percentVMA: 60, order: 0)
        let block = ProtocolBlock(title: "WARM-UP", iterations: 1, order: 0, steps: [step])
        let proto = RunProtocol(name: "S", discipline: .vma, blocks: [block])
        ctx.insert(proto); try ctx.save()

        #expect(ProtocolActions.moveStep(step, to: 0, in: block, context: ctx) == false)
        #expect(sequence(block) == [2000])
    }

    // MARK: - Sémantique onMove (IndexSet / toOffset)

    @Test func onMoveSemantics_matchesArrayMove() throws {
        let ctx = try makeContext()
        let (_, block) = insertBlock(ctx)

        // Déplacer l'index 0 « avant » l'index 3 → [20, 30, 10, 40] (sémantique Array).
        ProtocolActions.moveStep(in: block, from: IndexSet(integer: 0), to: 3, context: ctx)

        #expect(sequence(block) == [20, 30, 10, 40])
        #expect(orders(block) == [0, 1, 2, 3])
    }

    // MARK: - Persistance après relance

    /// Le nouvel ordre doit survivre à la fermeture du store : c'est `order` qui est
    /// persisté, pas l'ordre d'insertion de la relation.
    @Test func newOrderSurvivesAStoreReopen() throws {
        let url = URL.temporaryDirectory.appending(path: "lane04-reorder-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }

        let protoID: UUID
        do {
            let ctx = try makeContext(url: url)
            let (proto, block) = insertBlock(ctx)
            protoID = proto.id
            let last = block.steps.first { $0.goalValue == 40 }!
            ProtocolActions.moveStep(last, to: 0, in: block, context: ctx)
            #expect(sequence(block) == [40, 10, 20, 30])
            try ctx.save()
        }

        let reopened = try makeContext(url: url)
        let proto = try #require(try reopened.fetch(FetchDescriptor<RunProtocol>()).first { $0.id == protoID })
        let block = try #require(proto.blocks.first)

        #expect(sequence(block) == [40, 10, 20, 30])
        #expect(orders(block) == [0, 1, 2, 3])
    }

    // MARK: - Invalidation de l'état injecté

    /// Un protocole transmis puis réordonné devient `OUT OF SYNC` : la montre détient
    /// une séquence périmée. Jamais de réinjection automatique.
    @Test func reorderingASyncedProtocol_marksItOutOfSync() throws {
        let ctx = try makeContext()
        let (proto, block) = insertBlock(ctx, state: .synced)
        let first = block.steps.first { $0.goalValue == 10 }!

        ProtocolActions.moveStep(first, to: 2, in: block, context: ctx)

        #expect(proto.state == .desynced)
        #expect(proto.state.rawValue == "OUT OF SYNC")
    }

    /// L'occurrence reste `SCHEDULED` — la montre détient bien une séance, ce serait
    /// mentir de dire le contraire — mais elle est signalée périmée.
    @Test func reorderingFlagsScheduledOccurrencesAsStale() throws {
        let ctx = try makeContext()
        let (proto, block) = insertBlock(ctx, state: .synced)
        let session = PlanActions.plan(proto, on: Date().addingTimeInterval(86_400), in: ctx)
        PlanActions.markScheduled(session, planID: UUID(), at: session.date, in: ctx)
        #expect(session.watchCopyStale == false)

        ProtocolActions.moveStep(block.steps.first { $0.goalValue == 10 }!, to: 2, in: block, context: ctx)

        #expect(session.state == .scheduled)      // la montre détient toujours une séance
        #expect(session.watchCopyStale)           // …mais périmée
        #expect(session.scheduledPlanID != nil)   // la poignée de retrait est conservée
    }

    /// Une occurrence jamais transmise n'a rien de périmé à signaler.
    @Test func reorderingDoesNotFlagPlannedOccurrences() throws {
        let ctx = try makeContext()
        let (proto, block) = insertBlock(ctx, state: .draft)
        let session = PlanActions.plan(proto, on: Date().addingTimeInterval(86_400), in: ctx)

        ProtocolActions.moveStep(block.steps.first { $0.goalValue == 10 }!, to: 2, in: block, context: ctx)

        #expect(session.state == .planned)
        #expect(session.watchCopyStale == false)
        #expect(proto.state == .draft)            // un brouillon n'a jamais été transmis
    }

    /// Réinjecter remet la copie de la montre à jour.
    @Test func reschedulingClearsTheStaleFlag() throws {
        let ctx = try makeContext()
        let (proto, block) = insertBlock(ctx, state: .synced)
        let session = PlanActions.plan(proto, on: Date().addingTimeInterval(86_400), in: ctx)
        PlanActions.markScheduled(session, planID: UUID(), at: session.date, in: ctx)
        ProtocolActions.moveStep(block.steps.first { $0.goalValue == 10 }!, to: 2, in: block, context: ctx)
        #expect(session.watchCopyStale)

        PlanActions.markScheduled(session, planID: UUID(), at: session.date, in: ctx)

        #expect(session.watchCopyStale == false)
    }

    /// Un no-op ne périme rien : on ne dégrade pas un état sur un geste sans effet.
    @Test func aNoOpMoveLeavesTheInjectionIntact() throws {
        let ctx = try makeContext()
        let (proto, block) = insertBlock(ctx, state: .synced)
        let first = block.steps.first { $0.goalValue == 10 }!

        #expect(ProtocolActions.moveStep(first, to: 0, in: block, context: ctx) == false)
        #expect(proto.state == .synced)
    }

    @Test func outOfSyncSurvivesAStoreReopen() throws {
        let url = URL.temporaryDirectory.appending(path: "lane04-desync-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            let ctx = try makeContext(url: url)
            let (_, block) = insertBlock(ctx, state: .synced)
            ProtocolActions.moveStep(block.steps.first { $0.goalValue == 10 }!, to: 3, in: block, context: ctx)
            try ctx.save()
        }

        let reopened = try makeContext(url: url)
        let proto = try #require(try reopened.fetch(FetchDescriptor<RunProtocol>()).first)
        #expect(proto.state == .desynced)
        #expect(sequence(try #require(proto.blocks.first)) == [20, 30, 40, 10])
    }

    /// Le réordonnancement change la séquence RÉELLEMENT injectée, pas seulement
    /// l'affichage : c'est ce qui justifie d'invalider une injection (item 5).
    @Test func reorderChangesTheBuiltWorkoutSequence() throws {
        let ctx = try makeContext()
        let (proto, block) = insertBlock(ctx)
        let warmup = ProtocolBlock(title: "WARM-UP", iterations: 1, order: -1, steps: [
            ProtocolStep(role: .warmup, goalKind: .distance, goalValue: 2000, percentVMA: 60, order: 0)
        ])
        warmup.owner = proto
        proto.blocks.append(warmup)
        try ctx.save()

        let before = try WorkoutBuilder.validatedCustomWorkout(for: proto, vma: 16)
        let first = block.steps.first { $0.goalValue == 10 }!
        ProtocolActions.moveStep(first, to: 3, in: block, context: ctx)
        let after = try WorkoutBuilder.validatedCustomWorkout(for: proto, vma: 16)

        #expect(before.blocks.count == after.blocks.count)
        #expect(sequence(block) == [20, 30, 40, 10])
    }
}
