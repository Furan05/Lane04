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
}
