//
//  TrainingZone.swift
//  Lane04
//
//  Zones physiologiques Z1–Z5 dérivées de la VMA (écran OPERATOR, §08).
//  Calage sur les bornes du case study (VMA 17.2 : Z5 ≤3:29 … Z1 ≥5:01).
//

import Foundation

enum TrainingZone: String, CaseIterable, Identifiable {
    case z1 = "Z1"
    case z2 = "Z2"
    case z3 = "Z3"
    case z4 = "Z4"
    case z5 = "Z5"

    var id: String { rawValue }

    /// % VMA représentatif (centre de zone) — cible pour les templates.
    var percentVMA: Double {
        switch self {
        case .z1: return 62
        case .z2: return 75
        case .z3: return 84
        case .z4: return 95
        case .z5: return 105
        }
    }

    /// Bornes basse/haute de la zone en % VMA (pour l'affichage OPERATOR).
    var band: ClosedRange<Double> {
        switch self {
        case .z1: return 50...70
        case .z2: return 70...80
        case .z3: return 80...90
        case .z4: return 90...100
        case .z5: return 100...115
        }
    }

    /// Effet dominant de la zone (français, langue de lecture).
    var effect: String {
        switch self {
        case .z1: return "Récupération"
        case .z2: return "Endurance"
        case .z3: return "Tempo / seuil bas"
        case .z4: return "Seuil / VO2max"
        case .z5: return "VMA"
        }
    }

    /// Bornes d'allure formatées pour une VMA donnée (ex. « ≤ 3:29 », « 3:53–4:20 »).
    func paceRangeString(vma: Double) -> String {
        let fast = VMACalculator.paceString(vma: vma, percent: band.upperBound)
        let slow = VMACalculator.paceString(vma: vma, percent: band.lowerBound)
        switch self {
        case .z5: return "≤ \(VMACalculator.paceString(vma: vma, percent: 100))"
        case .z1: return "≥ \(VMACalculator.paceString(vma: vma, percent: 70))"
        default:  return "\(fast)–\(slow)"
        }
    }
}
