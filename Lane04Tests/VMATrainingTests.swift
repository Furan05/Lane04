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

    @Test func catalogHas31Templates() {
        let templates = TemplateCatalog.templates()
        #expect(templates.count == 31)
        #expect(templates.allSatisfy { $0.isTemplate })
        #expect(templates.allSatisfy { $0.state == .ready })
        #expect(templates.allSatisfy { !$0.blocks.isEmpty })
    }

    @Test func nomenclatureCoversAllFiveTags() {
        let used = Set(TemplateCatalog.templates().map(\.discipline))
        // Les 5 tags — et seulement eux — sont peuplés.
        #expect(used == Set(Discipline.allCases))
    }

    @Test func eachDisciplineHasAtLeastOneTemplate() {
        let byTag = Dictionary(grouping: TemplateCatalog.templates(), by: \.discipline)
        for tag in Discipline.allCases {
            #expect((byTag[tag]?.count ?? 0) >= 1, "\(tag.rawValue) vide")
        }
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
        #expect(after1 == 31)
        #expect(after2 == 31)
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

    // MARK: - TEST_VMA : effort maximal SANS cible d'allure

    @Test func testVMATemplate_isMarkedTestAndTaggedVMA() throws {
        let test = try template(named: "TEST_VMA")
        #expect(test.isTest)
        #expect(test.discipline == .vma)
    }

    @Test func testVMA_effortHasNoSpeedRangeAlert() throws {
        let workout = WorkoutBuilder.customWorkout(for: try template(named: "TEST_VMA"), vma: 16)
        // Warmup + cooldown présents ; un seul bloc de corps : l'effort maximal.
        #expect(workout.warmup != nil)
        #expect(workout.cooldown != nil)
        #expect(workout.blocks.count == 1)
        #expect(workout.blocks[0].iterations == 1)
        #expect(workout.blocks[0].steps.count == 1)
        // Le cœur du test : la montre ne pose AUCUNE cible d'allure sur l'effort.
        #expect(workout.blocks[0].steps[0].step.alert == nil)
    }

    @Test func testVMA_isTheOnlyTestTemplate() {
        let tests = TemplateCatalog.templates().filter(\.isTest)
        #expect(tests.count == 1)
        #expect(tests.first?.name == "TEST_VMA")
    }

    // MARK: - Mesure : demi-Cooper (VMA = distance 6 min / 100)

    @Test func halfCooper_convertsMetersToVMA() {
        #expect(abs(VMACalculator.vmaFromHalfCooper(meters: 1400) - 14.0) < Self.epsilon)
        #expect(abs(VMACalculator.vmaFromHalfCooper(meters: 1720) - 17.2) < Self.epsilon)
        #expect(abs(VMACalculator.vmaFromHalfCooper(meters: 900) - 9.0) < Self.epsilon)
    }

    // MARK: - Estimation : coefficient par palier de durée + VMA dérivée

    @Test func estimator_coefficientPaliers_tenK() {
        // Paliers 10K : < 42:00 rapide 0.90 ; ≤ 52:00 médian 0.87 ; au-delà lent 0.85.
        #expect(VMAEstimator.coefficient(.tenK, seconds: 2400) == 0.90) // 40:00
        #expect(VMAEstimator.coefficient(.tenK, seconds: 2520) == 0.87) // 42:00 pile → médian
        #expect(VMAEstimator.coefficient(.tenK, seconds: 3120) == 0.87) // 52:00 pile → médian
        #expect(VMAEstimator.coefficient(.tenK, seconds: 3121) == 0.85) // > 52:00 → lent
    }

    @Test func estimator_coefficientPaliers_fiveKAndSemi() {
        #expect(VMAEstimator.coefficient(.fiveK, seconds: 1199) == 0.95)
        #expect(VMAEstimator.coefficient(.fiveK, seconds: 1620) == 0.93)
        #expect(VMAEstimator.coefficient(.fiveK, seconds: 1621) == 0.91)
        #expect(VMAEstimator.coefficient(.semi, seconds: 5699) == 0.85)
        #expect(VMAEstimator.coefficient(.semi, seconds: 6900) == 0.83)
        #expect(VMAEstimator.coefficient(.semi, seconds: 6901) == 0.81)
    }

    @Test func estimator_derivesVMA_fastMedianSlow() {
        // 10K rapide (40:00) : 15 km/h ÷ 0.90 → 16.67 ; plus lent → VMA plus basse.
        let fast = VMAEstimator.estimate(.tenK, seconds: 2400)
        let median = VMAEstimator.estimate(.tenK, seconds: 3000) // 50:00 → 12 km/h ÷ 0.87
        let slow = VMAEstimator.estimate(.tenK, seconds: 3600)   // 60:00 → 10 km/h ÷ 0.85
        #expect(abs(fast.coefficient - 0.90) < Self.epsilon)
        #expect(abs(fast.vma - 15.0 / 0.90) < 1e-6)
        #expect(abs(median.vma - 12.0 / 0.87) < 1e-6)
        #expect(abs(slow.vma - 10.0 / 0.85) < 1e-6)
        #expect(fast.vma > median.vma && median.vma > slow.vma)
    }

    @Test func estimator_zeroTimeIsSafe() {
        let r = VMAEstimator.estimate(.tenK, seconds: 0)
        #expect(r.vma == 0) // pas de division par zéro
    }

    // MARK: - Provenance : défaut non calibré, à 14.0

    @Test func defaultProfile_isUncalibratedAt14() {
        let profile = OperatorProfile()
        #expect(profile.vma == 14.0)
        #expect(profile.provenance == .uncalibrated)
    }
}
