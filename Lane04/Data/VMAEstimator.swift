//
//  VMAEstimator.swift
//  Lane04
//
//  Voie d'ESTIMATION (statut [ESTIMATED]) : VMA dérivée d'une course récente.
//  Le % VMA tenable dépend de la DURÉE d'effort — barème par PALIERS SECS sur le
//  chrono (pas d'interpolation : l'UI affiche le coefficient discret réellement
//  utilisé, ex. « 10K 48:30 → coeff 0.87 »). Source : consensus coaching français
//  (RunMotion, wanarun) — un 10K se court à ~85–90 % VMA selon la durée.
//

import Foundation

enum RaceDistance: String, CaseIterable, Identifiable {
    case fiveK = "5K"
    case tenK = "10K"
    case semi = "SEMI"

    var id: String { rawValue }
    var meters: Double {
        switch self {
        case .fiveK: return 5000
        case .tenK:  return 10000
        case .semi:  return 21097.5
        }
    }
}

enum VMAEstimator {

    /// Coefficient (% VMA tenu) par paliers sur le chrono. Bornes : le seuil bas
    /// est strict (`<`), la borne haute du palier médian est inclusive (`<=`).
    static func coefficient(_ distance: RaceDistance, seconds: Double) -> Double {
        switch distance {
        case .fiveK: return seconds < 1200 ? 0.95 : (seconds <= 1620 ? 0.93 : 0.91) // 20 / 27 min
        case .tenK:  return seconds < 2520 ? 0.90 : (seconds <= 3120 ? 0.87 : 0.85) // 42 / 52 min
        case .semi:  return seconds < 5700 ? 0.85 : (seconds <= 6900 ? 0.83 : 0.81) // 95 / 115 min
        }
    }

    /// VMA estimée (km/h) et coefficient utilisé.
    /// `vitesse = distance / temps` ; `VMA = vitesse / coefficient`.
    static func estimate(_ distance: RaceDistance, seconds: Double) -> (vma: Double, coefficient: Double) {
        let coeff = coefficient(distance, seconds: seconds)
        guard seconds > 0 else { return (0, coeff) }
        let speedKmh = distance.meters / 1000 / (seconds / 3600)
        return (speedKmh / coeff, coeff)
    }
}
