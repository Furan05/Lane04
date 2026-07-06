//
//  VMACalculator.swift
//  Lane04
//
//  Created by François.Dubois on 03/07/2026.
//

import Foundation

/// Service de conversion basé sur la VMA (Vitesse Maximale Aérobie, en km/h).
///
/// Toutes les allures d'entraînement se déduisent d'un pourcentage de la VMA :
/// endurance fondamentale ~65 %, seuil ~85 %, VMA longue ~92 %, VMA courte ~105 %.
enum VMACalculator {

    /// Tolérance par défaut appliquée autour d'une cible, en points de % VMA.
    static let tolerancePercent: Double = 2.5

    /// Vitesse (m/s) à un pourcentage donné de la VMA.
    ///
    /// - Parameters:
    ///   - vma: VMA en km/h.
    ///   - percent: Intensité visée, en pourcentage de la VMA (ex. 105).
    static func speed(vma: Double, percent: Double) -> Double {
        // km/h -> m/s : diviser par 3.6.
        vma * (percent / 100) / 3.6
    }

    /// Allure en secondes par kilomètre à un pourcentage donné de la VMA.
    static func paceSecondsPerKm(vma: Double, percent: Double) -> Double? {
        let v = speed(vma: vma, percent: percent)
        guard v > 0 else { return nil }
        return 1000 / v
    }

    /// Allure formatée `"m:ss"` à un pourcentage donné de la VMA.
    static func paceString(vma: Double, percent: Double) -> String {
        guard let seconds = paceSecondsPerKm(vma: vma, percent: percent) else { return "--:--" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// % VMA correspondant à une allure (secondes/km) donnée — réciproque de
    /// `paceSecondsPerKm`. Utilisé par le sélecteur d'allure (§12).
    static func percent(paceSecondsPerKm pace: Double, vma: Double) -> Double {
        guard pace > 0, vma > 0 else { return 0 }
        let speed = 1000 / pace          // m/s
        return speed * 3.6 / vma * 100   // km/h -> % VMA
    }

    /// Plage de vitesse cible (`Measurement<UnitSpeed>`, m/s) autour d'un % VMA,
    /// directement exploitable par `SpeedRangeAlert` de WorkoutKit.
    ///
    /// - Parameter tolerance: Demi-largeur de la plage, en points de % VMA.
    static func targetSpeedRange(
        vma: Double,
        percent: Double,
        tolerance: Double = tolerancePercent
    ) -> ClosedRange<Measurement<UnitSpeed>> {
        let low = speed(vma: vma, percent: max(0, percent - tolerance))
        let high = speed(vma: vma, percent: percent + tolerance)
        return Measurement(value: low, unit: .metersPerSecond)
            ... Measurement(value: high, unit: .metersPerSecond)
    }
}
