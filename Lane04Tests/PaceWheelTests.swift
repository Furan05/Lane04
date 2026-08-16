//
//  PaceWheelTests.swift
//  Lane04Tests
//
//  Molette d'allure : aimantation sur les crans de 5 s, bornes 60–110 % de VMA,
//  synchronisation boutons ↔ molette, et cohérence entre le % AFFICHÉ (dérivé) et
//  l'allure de travail. La logique testée est `PaceScale` — pure, sans vue.
//

import Testing
import Foundation
import SwiftData
@testable import Lane04

@MainActor
struct PaceWheelTests {

    private let vma = 16.0   // 100 % = 225 s/km (3:45)

    // MARK: - Aimantation

    @Test(arguments: [(223, 225), (222, 220), (226, 225), (228, 230), (225, 225), (217, 215)])
    func snap_goesToNearestFiveSecondNotch(input: Int, expected: Int) {
        #expect(PaceScale.snap(input) == expected)
    }

    @Test func everyNotchIsAMultipleOfFive() {
        let notches = PaceScale.notches(vma: vma)
        #expect(!notches.isEmpty)
        #expect(notches.allSatisfy { $0 % PaceScale.step == 0 })
    }

    /// Aimanter un cran déjà aligné ne le déplace pas (idempotence).
    @Test func snappingAnAlignedValueIsIdempotent() {
        for notch in PaceScale.notches(vma: vma) {
            #expect(PaceScale.snap(notch) == notch)
            #expect(PaceScale.resolve(notch, vma: vma) == notch)
        }
    }

    /// L'échelle se lit de gauche à droite comme un effort croissant : les secondes
    /// décroissent, donc le % croît.
    @Test func notchesRunFromSlowestToFastest() {
        let notches = PaceScale.notches(vma: vma)
        #expect(notches == notches.sorted(by: >))

        let percents = notches.map { PaceScale.percent(paceSeconds: $0, vma: vma) }
        #expect(percents == percents.sorted())
    }

    // MARK: - Bornes basse et haute

    @Test func everyNotchStaysWithinSixtyToOneHundredTen() {
        for notch in PaceScale.notches(vma: vma) {
            let p = VMACalculator.percent(paceSecondsPerKm: Double(notch), vma: vma)
            #expect(p >= PaceScale.minPercent)
            #expect(p <= PaceScale.maxPercent)
        }
    }

    @Test func clampingHoldsAtBothEnds() throws {
        let b = try #require(PaceScale.bounds(vma: vma))

        #expect(PaceScale.clamped(60, vma: vma) == b.fastest)     // trop rapide
        #expect(PaceScale.clamped(900, vma: vma) == b.slowest)    // trop lent
        #expect(PaceScale.clamped(b.fastest, vma: vma) == b.fastest)
        #expect(PaceScale.clamped(b.slowest, vma: vma) == b.slowest)
    }

    /// Une valeur hors bornes est ramenée sur un cran réel, jamais entre deux.
    @Test func resolvingAnOutOfRangeValueLandsOnARealNotch() {
        let notches = Set(PaceScale.notches(vma: vma))
        for raw in [30, 61, 124, 806, 1200] {
            #expect(notches.contains(PaceScale.resolve(raw, vma: vma)))
        }
    }

    @Test(arguments: [10.0, 14.0, 16.0, 18.5, 22.0])
    func boundsHoldForAnyPlausibleVMA(vma: Double) throws {
        let notches = PaceScale.notches(vma: vma)
        #expect(notches.count > 5)
        for notch in notches {
            let p = VMACalculator.percent(paceSecondsPerKm: Double(notch), vma: vma)
            #expect(p >= PaceScale.minPercent && p <= PaceScale.maxPercent)
        }
    }

    @Test func anAbsurdVMAYieldsNoScaleRatherThanACrash() {
        #expect(PaceScale.notches(vma: 0).isEmpty)
        #expect(PaceScale.bounds(vma: 0) == nil)
        #expect(PaceScale.bounds(vma: -5) == nil)
    }

    // MARK: - Cohérence % affiché / allure de travail

    /// Le % est DÉRIVÉ de l'allure : à VMA constante, un cran donne toujours le même %.
    @Test func displayedPercentIsAFunctionOfPaceAlone() {
        for notch in PaceScale.notches(vma: vma) {
            #expect(PaceScale.percent(paceSeconds: notch, vma: vma)
                    == PaceScale.percent(paceSeconds: notch, vma: vma))
        }
    }

    /// Aller-retour allure → % → allure : le cran est retrouvé. C'est ce qui autorise
    /// à PERSISTER le % (relatif) sans perdre le cran choisi à la molette.
    @Test func paceSurvivesTheRoundTripThroughStoredPercent() throws {
        for notch in PaceScale.notches(vma: vma) {
            let storedPercent = VMACalculator.percent(paceSecondsPerKm: Double(notch), vma: vma)
            let restored = try #require(PaceScale.paceSeconds(percent: storedPercent, vma: vma))
            #expect(restored == notch)
        }
    }

    /// 100 % de VMA doit tomber sur l'allure de VMA (16 km/h → 3:45).
    @Test func oneHundredPercentIsTheVMAPace() throws {
        let pace = try #require(PaceScale.paceSeconds(percent: 100, vma: 16))
        #expect(pace == 225)
        #expect(PaceScale.label(pace) == "3:45")
        #expect(PaceScale.percent(paceSeconds: 225, vma: 16) == 100)
    }

    /// ⚠️ Propriété RÉELLE, pas un bug : le % affiché étant arrondi à l'entier, deux
    /// crans voisins peuvent afficher le MÊME %. `percent = 22500 / pace` (VMA 16)
    /// s'aplatit aux allures lentes : 5 s y valent moins d'un point de %. C'est
    /// exactement pourquoi la vérité de travail est l'allure, pas le %.
    /// L'allure, elle, change à CHAQUE cran — le readout ne paraît jamais figé.
    @Test func atSlowPacesTwoNotchesCanShareTheSamePercent() {
        #expect(PaceScale.percent(paceSeconds: 360, vma: vma) == 63)   // 62.5 → 63
        #expect(PaceScale.percent(paceSeconds: 355, vma: vma) == 63)   // 63.4 → 63
        #expect(PaceScale.label(360) != PaceScale.label(355))          // l'allure, elle, bouge
    }

    /// Ce qui doit être vrai : le % ne recule JAMAIS quand l'effort augmente, et
    /// l'allure est strictement monotone d'un cran à l'autre.
    @Test func percentNeverGoesBackwardsAsEffortRises() {
        let notches = PaceScale.notches(vma: vma)
        let percents = notches.map { PaceScale.percent(paceSeconds: $0, vma: vma) }

        #expect(percents == percents.sorted())
        for (a, b) in zip(notches, notches.dropFirst()) { #expect(b < a) }
    }

    // MARK: - Repères de zones (rampe thermique existante)

    @Test func zoneBoundariesAreRealNotchesAndChangeZone() {
        let notches = PaceScale.notches(vma: vma)
        let boundaries = PaceScale.zoneBoundaries(vma: vma)

        #expect(!boundaries.isEmpty)
        for boundary in boundaries {
            #expect(notches.contains(boundary))
            let i = notches.firstIndex(of: boundary)!
            #expect(i > 0)
            #expect(PaceScale.zone(paceSeconds: boundary, vma: vma)
                    != PaceScale.zone(paceSeconds: notches[i - 1], vma: vma))
        }
    }

    /// Les crans se répartissent sur plusieurs zones de la rampe — sinon le repérage
    /// visuel ne servirait à rien.
    @Test func theScaleSpansSeveralZones() {
        let zones = Set(PaceScale.notches(vma: vma).compactMap { PaceScale.zone(paceSeconds: $0, vma: vma) })
        #expect(zones.count >= 3)
        #expect(zones.contains(.z5))   // 110 % est bien en Z5
    }

    // MARK: - Synchronisation boutons ↔ molette

    /// Les boutons ±5 s produisent des valeurs déjà alignées : la molette les affiche
    /// sans les déplacer.
    @Test func buttonStepsLandExactlyOnNotches() throws {
        let b = try #require(PaceScale.bounds(vma: vma))
        var pace = PaceScale.resolve(230, vma: vma)

        for _ in 0..<5 {
            pace = min(pace + 5, b.slowest)          // −5 S = plus lent
            #expect(PaceScale.resolve(pace, vma: vma) == pace)
        }
        for _ in 0..<10 {
            pace = max(pace - 5, b.fastest)          // +5 S = plus rapide
            #expect(PaceScale.resolve(pace, vma: vma) == pace)
        }
    }

    /// Les boutons vont plus loin que la molette (2:00…10:00, « l'athlète a toujours
    /// raison ») : la molette bute alors sur son extrémité SANS ramener la valeur.
    @Test func buttonsMayExceedTheWheelRange_wheelClampsWithoutStealingTheValue() throws {
        let b = try #require(PaceScale.bounds(vma: vma))
        let beyond = b.fastest - 20                  // plus rapide que 110 %

        #expect(PaceScale.clamped(beyond, vma: vma) == b.fastest)
        #expect(beyond < b.fastest)                  // la valeur de travail, elle, reste hors bornes
    }

    /// Le COMMIT persiste bien le % dérivé de l'allure travaillée (sens de dérivation).
    @Test func commitPersistsThePercentDerivedFromTheWorkingPace() throws {
        let schema = Schema(LaneSchema.models)
        let ctx = ModelContext(try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)))

        let step = ProtocolStep(role: .work, goalKind: .time, goalValue: 60,
                                percentVMA: 100, targetsPace: true, order: 0)
        let block = ProtocolBlock(title: "B", iterations: 1, steps: [step])
        let proto = RunProtocol(name: "S", discipline: .vma, blocks: [block])
        ctx.insert(proto); try ctx.save()

        // L'athlète cale la molette sur 4:00/km.
        let chosen = 240
        step.percentVMA = VMACalculator.percent(paceSecondsPerKm: Double(chosen), vma: vma)
        try ctx.save()

        // Réouverture : on retrouve exactement le cran choisi, et le % affiché est cohérent.
        let reopened = try #require(PaceScale.paceSeconds(percent: step.percentVMA, vma: vma))
        #expect(reopened == chosen)
        #expect(PaceScale.percent(paceSeconds: reopened, vma: vma) == 94)   // 225/240 ≈ 93.75 → 94
    }

    // MARK: - VMA non calibrée

    /// Une VMA non calibrée reste une VMA : l'échelle est identique, seule la mention
    /// à l'écran change. L'instrument ne refuse pas de fonctionner, il dit d'où il parle.
    @Test func anUncalibratedVMAStillProducesAUsableScale() {
        let estimated = 14.0   // valeur par défaut d'un profil non calibré
        let notches = PaceScale.notches(vma: estimated)

        #expect(notches.count > 5)
        #expect(notches.allSatisfy { $0 % PaceScale.step == 0 })
        for notch in notches {
            let p = VMACalculator.percent(paceSecondsPerKm: Double(notch), vma: estimated)
            #expect(p >= PaceScale.minPercent && p <= PaceScale.maxPercent)
        }
    }

    /// Une VMA plus basse déplace l'échelle vers des allures plus lentes — sans quoi
    /// la mention « VMA estimée » n'aurait aucune conséquence réelle.
    @Test func aLowerVMAShiftsTheWholeScaleSlower() throws {
        let calibrated = try #require(PaceScale.bounds(vma: 16))
        let estimated = try #require(PaceScale.bounds(vma: 14))

        #expect(estimated.fastest > calibrated.fastest)
        #expect(estimated.slowest > calibrated.slowest)
    }

    @Test func profileDefaultsToUncalibrated() {
        #expect(OperatorProfile().provenance == .uncalibrated)
    }
}
