//
//  VMATrainingTests.swift
//  Lane04Tests
//
//  Created by François.Dubois on 03/07/2026.
//

import Testing
import Foundation
import WorkoutKit
@testable import Lane04

struct VMATrainingTests {

    private static let epsilon = 1e-9

    // MARK: - VMACalculator

    @Test func speedAtFullVMA() {
        // 16 km/h à 100 % = 16 / 3.6 ≈ 4.4444 m/s
        #expect(abs(VMACalculator.speed(vma: 16, percent: 100) - 16.0 / 3.6) < Self.epsilon)
    }

    @Test func speedScalesWithPercent() {
        // 50 % doit valoir la moitié de 100 %.
        let full = VMACalculator.speed(vma: 16, percent: 100)
        let half = VMACalculator.speed(vma: 16, percent: 50)
        #expect(abs(half - full / 2) < Self.epsilon)
    }

    @Test func paceStrings_matchKnownValues() {
        // VMA 16 km/h : EF 65 % -> 5:46, seuil 85 % -> 4:25, VMA 100 % -> 3:45.
        #expect(VMACalculator.paceString(vma: 16, percent: 65) == "5:46")
        #expect(VMACalculator.paceString(vma: 16, percent: 85) == "4:25")
        #expect(VMACalculator.paceString(vma: 16, percent: 100) == "3:45")
    }

    @Test func targetSpeedRange_isOrderedAndCentered() {
        let range = VMACalculator.targetSpeedRange(vma: 16, percent: 100)
        let center = VMACalculator.speed(vma: 16, percent: 100)
        let low = range.lowerBound.converted(to: .metersPerSecond).value
        let high = range.upperBound.converted(to: .metersPerSecond).value
        #expect(low < center)
        #expect(high > center)
    }

    // MARK: - Catalogue

    @Test func catalogIsWellFormed() {
        // Identifiants uniques.
        let ids = RunSession.catalog.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(RunSession.catalog.count >= 20)
    }

    @Test func everyCategoryHasSessions() {
        for category in SessionCategory.allCases {
            #expect(!RunSession.sessions(in: category).isEmpty, "\(category.label) vide")
        }
    }

    @Test func sessionsInCategoryAreFiltered() {
        for category in SessionCategory.allCases {
            for session in RunSession.sessions(in: category) {
                #expect(session.category == category)
            }
        }
    }

    @Test func everySessionHasPositiveTotals() {
        for session in RunSession.catalog {
            let totals = session.totals(vma: 15)
            #expect(totals.distance > 0, "\(session.id) distance")
            #expect(totals.duration > 0, "\(session.id) durée")
        }
    }

    // MARK: - Génération WorkoutKit

    @Test func thresholdSessionBuildsWarmupBlocksCooldown() throws {
        let seuil = try #require(RunSession.catalog.first { $0.id == "seuil" })
        let workout = seuil.customWorkout(vma: 16)
        #expect(workout.displayName == "Seuil 2 × 10 min")
        #expect(workout.warmup != nil)
        #expect(workout.cooldown != nil)
        #expect(workout.blocks.count == 1)
        #expect(workout.blocks[0].iterations == 2)
        // 1 pas d'effort + 1 pas de récup par itération.
        #expect(workout.blocks[0].steps.count == 2)
    }

    @Test func shortVMASessionHasThreeBlocks() throws {
        // 2 séries + 1 bloc de récupération inter-série.
        let courte = try #require(RunSession.catalog.first { $0.id == "vma-courte" })
        let workout = courte.customWorkout(vma: 16)
        #expect(workout.blocks.count == 3)
        #expect(workout.blocks[0].iterations == 8)
        #expect(workout.blocks[1].iterations == 1)
        #expect(workout.blocks[2].iterations == 8)
    }

    @Test func enduranceSessionIsContinuous() throws {
        let endurance = try #require(RunSession.catalog.first { $0.id == "endurance" })
        let workout = endurance.customWorkout(vma: 16)
        #expect(workout.warmup == nil)
        #expect(workout.cooldown == nil)
        #expect(workout.blocks.count == 1)
        #expect(workout.blocks[0].iterations == 1)
    }

    @Test func adaptationScalesWithVMA() throws {
        // Une VMA plus élevée => séance plus rapide => distance parcourue plus
        // grande pour les blocs en temps, et durée plus courte pour les blocs
        // en distance. On vérifie que la vitesse d'un pas d'effort augmente.
        let moyenne = try #require(RunSession.catalog.first { $0.id == "vma-moyenne" })
        let slow = moyenne.totals(vma: 14).duration
        let fast = moyenne.totals(vma: 18).duration
        // Séance à dominante distance (400 m) : plus la VMA est haute, plus c'est court.
        #expect(fast < slow)
    }
}
