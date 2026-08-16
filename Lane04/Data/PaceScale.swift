//
//  PaceScale.swift
//  Lane04
//
//  L'échelle de la molette d'allure : crans discrets de 5 s/km entre 60 % et 110 %
//  de VMA. Logique PURE (aucune vue) — c'est elle qui porte l'aimantation, les bornes
//  et la dérivation du % affiché, donc c'est elle que les tests interrogent.
//
//  Sens de dérivation : la molette travaille en **allure (s/km)**, le **% VMA est
//  dérivé** pour l'affichage — des crans de 5 s ne tombent pas sur des % ronds.
//  ⚠️ Ce que le modèle PERSISTE reste `ProtocolStep.percentVMA` (relatif), pour qu'une
//  recalibration de VMA continue de remettre toutes les séances à l'échelle. La
//  conversion est sans perte : `percent(pace) → paceSeconds(percent)` rend le cran.
//

import Foundation

enum PaceScale {

    /// Pas de la molette, en secondes par kilomètre.
    static let step = 5
    /// Bornes de la molette, en % de VMA (l'éditeur autorise plus large via les boutons).
    static let minPercent: Double = 60
    static let maxPercent: Double = 110

    /// Bornes d'allure alignées sur la grille de 5 s, arrondies **vers l'intérieur**
    /// pour ne jamais proposer un cran hors de 60…110 %.
    /// - Returns: `fastest` = le moins de secondes (110 %), `slowest` = le plus (60 %).
    static func bounds(vma: Double) -> (fastest: Int, slowest: Int)? {
        guard vma > 0,
              let fast = VMACalculator.paceSecondsPerKm(vma: vma, percent: maxPercent),
              let slow = VMACalculator.paceSecondsPerKm(vma: vma, percent: minPercent),
              fast.isFinite, slow.isFinite
        else { return nil }

        let fastest = Int((fast / Double(step)).rounded(.up)) * step
        let slowest = Int((slow / Double(step)).rounded(.down)) * step
        guard fastest <= slowest else { return nil }
        return (fastest, slowest)
    }

    /// Les crans, **du plus lent au plus rapide** — la molette se lit de gauche à
    /// droite comme un effort croissant.
    static func notches(vma: Double) -> [Int] {
        guard let b = bounds(vma: vma) else { return [] }
        return Array(stride(from: b.slowest, through: b.fastest, by: -step))
    }

    /// Aimantation : le cran de 5 s le plus proche. À égalité (2.5 s), on va au plus
    /// grand — un choix, mais un choix constant.
    static func snap(_ seconds: Int) -> Int {
        Int((Double(seconds) / Double(step)).rounded()) * step
    }

    /// Ramène dans les bornes de la molette. Les bornes étant déjà sur la grille,
    /// le résultat reste sur un cran.
    static func clamped(_ seconds: Int, vma: Double) -> Int {
        guard let b = bounds(vma: vma) else { return seconds }
        return min(max(seconds, b.fastest), b.slowest)
    }

    /// Aimantation **puis** bornage : la valeur que la molette peut réellement afficher.
    static func resolve(_ seconds: Int, vma: Double) -> Int {
        clamped(snap(seconds), vma: vma)
    }

    // MARK: - Dérivations d'affichage

    /// Le % de VMA **dérivé** d'une allure, arrondi à l'entier (valeur d'affichage).
    static func percent(paceSeconds: Int, vma: Double) -> Int {
        Int(VMACalculator.percent(paceSecondsPerKm: Double(paceSeconds), vma: vma).rounded())
    }

    /// L'allure exacte (non arrondie) correspondant à un % — réciproque utilisée pour
    /// ouvrir la molette sur la valeur persistée.
    static func paceSeconds(percent: Double, vma: Double) -> Int? {
        guard let s = VMACalculator.paceSecondsPerKm(vma: vma, percent: percent), s.isFinite else { return nil }
        return Int(s.rounded())
    }

    static func label(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - Repères de zones

    /// Les crans où l'échelle change de zone (repères hauts sous la graduation).
    /// Un cran est une frontière si la zone de son voisin **plus lent** diffère.
    static func zoneBoundaries(vma: Double) -> Set<Int> {
        let all = notches(vma: vma)
        var boundaries: Set<Int> = []
        for (i, seconds) in all.enumerated() where i > 0 {
            let here = zone(paceSeconds: seconds, vma: vma)
            let slower = zone(paceSeconds: all[i - 1], vma: vma)
            if here != slower { boundaries.insert(seconds) }
        }
        return boundaries
    }

    /// Zone physiologique d'un cran (rampe thermique existante Z1–Z5).
    static func zone(paceSeconds: Int, vma: Double) -> TrainingZone? {
        TrainingZone.zone(forPercent: VMACalculator.percent(paceSecondsPerKm: Double(paceSeconds), vma: vma))
    }
}
