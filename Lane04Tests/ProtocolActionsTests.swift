//
//  ProtocolActionsTests.swift
//  Lane04Tests
//
//  Suppression (DRAFT/SYNCED), templates protégés, logs préservés,
//  duplication non destructive.
//

import Testing
import Foundation
import SwiftData
@testable import Lane04

@MainActor
struct ProtocolActionsTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([RunProtocol.self, ProtocolBlock.self, ProtocolStep.self,
                             OperatorProfile.self, RunLog.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @discardableResult
    private func insertProtocol(_ ctx: ModelContext, name: String = "Séance",
                                state: ProtocolState = .draft) -> RunProtocol {
        let proto = RunProtocol(
            name: name, discipline: .vma, isTemplate: false, state: state,
            blocks: [ProtocolBlock(title: "B", iterations: 1, steps: [
                ProtocolStep(role: .work, goalKind: .time, goalValue: 60, percentVMA: 100, targetsPace: true)
            ])]
        )
        ctx.insert(proto)
        try? ctx.save()
        return proto
    }

    @Test func deleteDraftRemovesIt() throws {
        let ctx = try makeContext()
        insertProtocol(ctx, state: .draft)
        let proto = try #require(try ctx.fetch(FetchDescriptor<RunProtocol>()).first)
        ProtocolActions.delete(proto, in: ctx)
        #expect(try ctx.fetchCount(FetchDescriptor<RunProtocol>()) == 0)
    }

    @Test func deleteSyncedRemovesIt() throws {
        let ctx = try makeContext()
        let proto = insertProtocol(ctx, state: .synced)
        ProtocolActions.delete(proto, in: ctx)
        #expect(try ctx.fetchCount(FetchDescriptor<RunProtocol>()) == 0)
    }

    @Test func deletePreservesRunLogs() throws {
        let ctx = try makeContext()
        let proto = insertProtocol(ctx, name: "VMA courte")
        ctx.insert(RunLog(discipline: .vma, protocolName: "VMA courte",
                          distanceMeters: 8100, durationSeconds: 2640))
        try? ctx.save()

        ProtocolActions.delete(proto, in: ctx)

        #expect(try ctx.fetchCount(FetchDescriptor<RunProtocol>()) == 0)
        // La trace de transmission survit à la séance.
        #expect(try ctx.fetchCount(FetchDescriptor<RunLog>()) == 1)
    }

    @Test func templatesSurviveUserDeletion() throws {
        let ctx = try makeContext()
        Seeder.seedIfNeeded(ctx)              // 31 templates (socle)
        let proto = insertProtocol(ctx)       // + 1 protocole utilisateur
        ProtocolActions.delete(proto, in: ctx)

        let templates = try ctx.fetch(FetchDescriptor<RunProtocol>(
            predicate: #Predicate { $0.isTemplate }))
        #expect(templates.count == 31)        // le catalogue reste intact
    }

    @Test func duplicateIsNonDestructive() throws {
        let ctx = try makeContext()
        let source = insertProtocol(ctx, name: "Seuil 2 × 10 min", state: .synced)

        let copy = ProtocolActions.duplicate(source, in: ctx)

        #expect(copy.name == "Seuil 2 × 10 min_COPY")
        #expect(copy.isTemplate == false)
        #expect(copy.state == .draft)
        #expect(copy.blocks.count == source.blocks.count)
        // Original intact.
        #expect(source.name == "Seuil 2 × 10 min")
        #expect(source.state == .synced)
        #expect(try ctx.fetchCount(FetchDescriptor<RunProtocol>()) == 2)
        // Copie profonde : muter la copie ne touche jamais l'original.
        copy.blocks.forEach { $0.iterations = 99 }
        #expect(source.blocks.allSatisfy { $0.iterations != 99 })
    }

    // MARK: - Raccourci CALIBRATION → TEST_VMA (pont vers le test)

    /// Insère le template TEST_VMA seul (comme après un seed), sans les autres.
    @discardableResult
    private func insertTestTemplate(_ ctx: ModelContext) -> RunProtocol {
        let template = try! #require(TemplateCatalog.templates().first { $0.isTest })
        ctx.insert(template)
        try? ctx.save()
        return template
    }

    @Test func prepareTestVMA_clonesTemplateAsEditableDraft() throws {
        let ctx = try makeContext()
        insertTestTemplate(ctx)

        let draft = try #require(ProtocolActions.prepareTestVMA(in: ctx))

        #expect(draft.isTemplate == false)   // éditable, pas le socle
        #expect(draft.isTest)                 // reste un test → badge [TEST]
        #expect(draft.state == .draft)
        #expect(draft.discipline == .vma)
        // Deux protocoles : le template socle + le [DRAFT] cloné.
        #expect(try ctx.fetchCount(FetchDescriptor<RunProtocol>()) == 2)
    }

    @Test func prepareTestVMA_isIdempotent_noPhantomDuplicates() throws {
        let ctx = try makeContext()
        insertTestTemplate(ctx)

        let first = try #require(ProtocolActions.prepareTestVMA(in: ctx))
        let second = try #require(ProtocolActions.prepareTestVMA(in: ctx))

        // Même instance réutilisée — pas d'accumulation de tests fantômes.
        #expect(first.id == second.id)
        let userTests = try ctx.fetch(FetchDescriptor<RunProtocol>(
            predicate: #Predicate { !$0.isTemplate && $0.isTest }))
        #expect(userTests.count == 1)
    }

    @Test func prepareTestVMA_reusesSyncedTestNotYetRun() throws {
        let ctx = try makeContext()
        insertTestTemplate(ctx)

        // Un test déjà cloné puis injecté ([SYNCED]) : on le réutilise, pas de re-clone.
        let existing = ProtocolActions.prepareTestVMA(in: ctx)!
        existing.state = .synced
        try ctx.save()

        let again = try #require(ProtocolActions.prepareTestVMA(in: ctx))
        #expect(again.id == existing.id)
        let userTests = try ctx.fetch(FetchDescriptor<RunProtocol>(
            predicate: #Predicate { !$0.isTemplate && $0.isTest }))
        #expect(userTests.count == 1)
    }

    // MARK: - Builder manuel (création vierge « from scratch »)

    private func orderedBlocks(_ p: RunProtocol) -> [ProtocolBlock] {
        p.blocks.sorted { $0.order < $1.order }
    }

    @Test func createBlank_producesEditableDraftScaffold() throws {
        let ctx = try makeContext()
        let proto = ProtocolActions.createBlank(in: ctx)

        #expect(proto.isTemplate == false)
        #expect(proto.isTest == false)
        #expect(proto.state == .draft)
        // Échafaudage : WARM-UP + 1 bloc d'effort + COOL-DOWN, ordres contigus 0..2.
        let blocks = orderedBlocks(proto)
        #expect(blocks.count == 3)
        #expect(blocks.map(\.order) == [0, 1, 2])
        #expect(blocks.first?.steps.first?.role == .warmup)
        #expect(blocks.last?.steps.first?.role == .cooldown)
        #expect(blocks[1].steps.first?.role == .work)
        #expect(blocks[1].steps.first?.targetsPace == true)
    }

    @Test func addWorkBlock_insertsBeforeCooldown_andRenumbers() throws {
        let ctx = try makeContext()
        let proto = ProtocolActions.createBlank(in: ctx)

        let added = ProtocolActions.addWorkBlock(to: proto, in: ctx)
        let blocks = orderedBlocks(proto)
        #expect(blocks.count == 4)
        #expect(blocks.map(\.order) == [0, 1, 2, 3])           // toujours contigus
        // Le nouveau bloc est juste avant le COOL-DOWN (dernier).
        #expect(blocks[2].id == added.id)
        #expect(ProtocolActions.isCooldownWrapper(blocks[3]))
    }

    @Test func deleteBlock_removesAndRenumbers() throws {
        let ctx = try makeContext()
        let proto = ProtocolActions.createBlank(in: ctx)
        let work = orderedBlocks(proto)[1]

        ProtocolActions.deleteBlock(work, from: proto, in: ctx)
        let blocks = orderedBlocks(proto)
        #expect(blocks.count == 2)
        #expect(blocks.map(\.order) == [0, 1])
        #expect(blocks.allSatisfy { $0.id != work.id })
    }

    @Test func moveBlock_swapsOrderWithNeighbor() throws {
        let ctx = try makeContext()
        let proto = ProtocolActions.createBlank(in: ctx)
        _ = ProtocolActions.addWorkBlock(to: proto, in: ctx)   // 2 blocs d'effort
        let before = orderedBlocks(proto)
        let firstWork = before[1], secondWork = before[2]

        ProtocolActions.moveBlock(secondWork, by: -1, in: proto, context: ctx)
        let after = orderedBlocks(proto)
        #expect(after[1].id == secondWork.id)
        #expect(after[2].id == firstWork.id)
        #expect(after.map(\.order) == [0, 1, 2, 3])
    }

    @Test func moveBlock_atEdgeIsNoOp() throws {
        let ctx = try makeContext()
        let proto = ProtocolActions.createBlank(in: ctx)
        let warmup = orderedBlocks(proto)[0]
        ProtocolActions.moveBlock(warmup, by: -1, in: proto, context: ctx) // déjà en tête
        #expect(orderedBlocks(proto).first?.id == warmup.id)
    }

    @Test func addStep_appendsWithContiguousOrder() throws {
        let ctx = try makeContext()
        let proto = ProtocolActions.createBlank(in: ctx)
        let work = orderedBlocks(proto)[1]

        let rec = ProtocolActions.addStep(to: work, role: .recovery, in: ctx)
        #expect(work.steps.count == 2)
        #expect(rec.role == .recovery)
        #expect(rec.targetsPace == false)
        #expect(work.steps.sorted { $0.order < $1.order }.map(\.order) == [0, 1])
    }

    @Test func deleteStep_keepsAtLeastOne() throws {
        let ctx = try makeContext()
        let proto = ProtocolActions.createBlank(in: ctx)
        let work = orderedBlocks(proto)[1]
        _ = ProtocolActions.addStep(to: work, role: .recovery, in: ctx)

        let first = work.steps.sorted { $0.order < $1.order }[0]
        ProtocolActions.deleteStep(first, from: work, in: ctx)
        #expect(work.steps.count == 1)

        // Le dernier pas ne se supprime pas (un bloc vide n'a pas de sens).
        let last = work.steps[0]
        ProtocolActions.deleteStep(last, from: work, in: ctx)
        #expect(work.steps.count == 1)
    }
}
