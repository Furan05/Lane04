//
//  VMATrainingTests.swift
//  Lane04Tests
//
//  Couvre : VMACalculator, catalogue de templates, builder WorkoutKit porté,
//  seed idempotent + clone (Phase 1).
//

import Testing
import Foundation
import WorkoutKit
import SwiftData
@testable import Lane04

struct VMATrainingTests {

    private static let epsilon = 1e-9

    private func template(named name: String) throws -> RunProtocol {
        try #require(TemplateCatalog.templates().first { $0.name == name })
    }

    // MARK: - VMACalculator (inchangé)

    @Test func speedAtFullVMA() {
        #expect(abs(VMACalculator.speed(vma: 16, percent: 100) - 16.0 / 3.6) < Self.epsilon)
    }

    @Test func speedScalesWithPercent() {
        let full = VMACalculator.speed(vma: 16, percent: 100)
        let half = VMACalculator.speed(vma: 16, percent: 50)
        #expect(abs(half - full / 2) < Self.epsilon)
    }

    @Test func paceStrings_matchKnownValues() {
        #expect(VMACalculator.paceString(vma: 16, percent: 65) == "5:46")
        #expect(VMACalculator.paceString(vma: 16, percent: 85) == "4:25")
        #expect(VMACalculator.paceString(vma: 16, percent: 100) == "3:45")
    }

    @Test func targetSpeedRange_isOrderedAndCentered() {
        let range = VMACalculator.targetSpeedRange(vma: 16, percent: 100)
        let center = VMACalculator.speed(vma: 16, percent: 100)
        #expect(range.lowerBound.converted(to: .metersPerSecond).value < center)
        #expect(range.upperBound.converted(to: .metersPerSecond).value > center)
    }

    // MARK: - Catalogue de templates

    @Test func catalogHas24Templates() {
        let templates = TemplateCatalog.templates()
        #expect(templates.count == 24)
        #expect(templates.allSatisfy { $0.isTemplate })
        #expect(templates.allSatisfy { $0.state == .ready })
        #expect(templates.allSatisfy { !$0.blocks.isEmpty })
    }

    @Test func nomenclatureIsStrict() {
        // Aucune filière hors des 5 tags autorisés.
        let allowed = Set(Discipline.allCases)
        let used = Set(TemplateCatalog.templates().map(\.discipline))
        #expect(used.isSubset(of: allowed))
        // Le remap ne produit que VMA / SEUIL / RECUP (TEMPO & FARTLEK restent vides).
        #expect(used == [.vma, .seuil, .recup])
    }

    // MARK: - Builder WorkoutKit (comportement porté à l'identique)

    @Test func thresholdBuildsWarmupBlocksCooldown() throws {
        let workout = WorkoutBuilder.customWorkout(for: try template(named: "Seuil 2 × 10 min"), vma: 16)
        #expect(workout.displayName == "Seuil 2 × 10 min")
        #expect(workout.warmup != nil)
        #expect(workout.cooldown != nil)
        #expect(workout.blocks.count == 1)
        #expect(workout.blocks[0].iterations == 2)
        #expect(workout.blocks[0].steps.count == 2)
    }

    @Test func shortVMAHasThreeBodyBlocks() throws {
        let workout = WorkoutBuilder.customWorkout(for: try template(named: "VMA courte 2 × 8 × 30/30"), vma: 16)
        #expect(workout.blocks.count == 3)
        #expect(workout.blocks[0].iterations == 8)
        #expect(workout.blocks[1].iterations == 1)
        #expect(workout.blocks[2].iterations == 8)
        #expect(workout.warmup != nil)
        #expect(workout.cooldown != nil)
    }

    @Test func enduranceIsContinuousNoWarmup() throws {
        let workout = WorkoutBuilder.customWorkout(for: try template(named: "Endurance fondamentale"), vma: 16)
        #expect(workout.warmup == nil)
        #expect(workout.cooldown == nil)
        #expect(workout.blocks.count == 1)
        #expect(workout.blocks[0].iterations == 1)
    }

    @Test func everyTemplateHasPositiveTotals() {
        for proto in TemplateCatalog.templates() {
            let totals = WorkoutBuilder.totals(for: proto, vma: 15)
            #expect(totals.distance > 0, "\(proto.name) distance")
            #expect(totals.duration > 0, "\(proto.name) durée")
        }
    }

    @Test func totalsScaleWithVMA() throws {
        let proto = try template(named: "VMA moyenne 8 × 400 m")
        let slow = WorkoutBuilder.totals(for: proto, vma: 14).duration
        let fast = WorkoutBuilder.totals(for: proto, vma: 18).duration
        #expect(fast < slow) // à dominante distance : plus la VMA est haute, plus c'est court
    }

    // MARK: - Persistance : seed idempotent + clone

    @MainActor
    private func inMemoryContext() throws -> ModelContext {
        let schema = Schema([RunProtocol.self, ProtocolBlock.self, ProtocolStep.self,
                             OperatorProfile.self, RunLog.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @MainActor
    @Test func seedIsIdempotent() throws {
        let ctx = try inMemoryContext()
        Seeder.seedIfNeeded(ctx)
        let after1 = try ctx.fetchCount(FetchDescriptor<RunProtocol>())
        Seeder.seedIfNeeded(ctx)
        let after2 = try ctx.fetchCount(FetchDescriptor<RunProtocol>())
        #expect(after1 == 24)
        #expect(after2 == 24)
    }

    @Test func cloneProducesEditableDraftWithoutTouchingTemplate() throws {
        let source = try template(named: "Seuil 2 × 10 min")
        let sourceBlockCount = source.blocks.count
        let draft = Seeder.clone(source)

        #expect(draft.isTemplate == false)
        #expect(draft.state == .draft)
        #expect(draft.blocks.count == sourceBlockCount)

        // Copie profonde : muter le clone ne touche jamais le template.
        draft.blocks.forEach { $0.iterations = 99 }
        #expect(source.blocks.allSatisfy { $0.iterations != 99 })
        #expect(source.isTemplate == true)
    }
}
