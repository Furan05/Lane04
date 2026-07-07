//
//  Theme.swift
//  Lane04
//
//  Design tokens — référence : docs/design-tokens.md (case study §04–05).
//  Aucune valeur en dur ne doit exister hors de ce fichier (et Typography.swift).
//

import SwiftUI
import UIKit

// MARK: - Couleurs (§04)

extension Color {
    /// `color.void` — canvas racine, OLED éteint.
    static let void = Color(hex: 0x000000)
    /// `color.carbon1` — surface posée : cartes au repos, listes.
    static let carbon1 = Color(hex: 0x0B0D10)
    /// `color.carbon2` — surface levée : sheets, éléments actifs.
    static let carbon2 = Color(hex: 0x14171C)

    /// `color.ember` — effort, action primaire, allure dépassée, alerte.
    static let ember = Color(hex: 0xFF4D00)
    /// `color.cryo` — récupération, allure conforme, sync OK, confirmation.
    static let cryo = Color(hex: 0x00E5FF)

    /// `color.white` (#F2F4F5) — data neutre, texte primaire. Nommé `laneWhite`
    /// pour ne pas masquer `Color.white` du système (#FFFFFF).
    static let laneWhite = Color(hex: 0xF2F4F5)
    /// `color.steel` — texte secondaire.
    static let steel = Color(hex: 0x99A1AB)
    /// `color.steelHi` — labels porteurs d'info (STEEL-DIM échoue AA).
    static let steelHi = Color(hex: 0x7A828C)
    /// `color.steelDim` — décoratif uniquement (échoue AA).
    static let steelDim = Color(hex: 0x565E68)

    // Rampe thermique — 5 crans EMBER→CRYO via le NEUTRE, jamais par le vert.
    // Source unique du spectre : zones OPERATOR, tags de séance, futurs anneaux.
    /// Z5 — VMA / effort maximal. EMBER pur.
    static let zoneZ5 = Color(hex: 0xFF4D00)
    /// Z4 — seuil / VO2max. Ambre désaturé.
    static let zoneZ4 = Color(hex: 0xC17A45)
    /// Z3 — tempo / seuil bas. Acier chaud (point médian).
    static let zoneZ3 = Color(hex: 0x8C8279)
    /// Z2 — endurance. Cyan désaturé.
    static let zoneZ2 = Color(hex: 0x5A97A6)
    /// Z1 — récupération. CRYO pur.
    static let zoneZ1 = Color(hex: 0x00E5FF)

    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

// MARK: - Espacement — base 4 pt (§05)

enum Spacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

// MARK: - Rayons (§05)

enum Radius {
    static let badge: CGFloat = 0    // tags et statuts : jamais arrondis
    static let control: CGFloat = 8
    static let card: CGFloat = 14
    static let button: CGFloat = 16
    static let sheet: CGFloat = 24
}

// MARK: - Grille iPhone (§05)

enum Grid {
    static let margin: CGFloat = 16
    static let gutter: CGFloat = 8
    static let safeTop: CGFloat = 76
    static let safeBottom: CGFloat = 42
}

enum Touch {
    static let min: CGFloat = 44
}

// MARK: - Matériaux — Liquid Glass (§05)

enum Surface {
    static let scrimBlur: CGFloat = 4
    static let glassBlur: CGFloat = 14
    static let navBlur: CGFloat = 20
    /// `fill.glass` — white 4 %.
    static let glassFill = Color.white.opacity(0.04)
    /// `hairline` — white 8 %, 1 px. La seule séparation autorisée.
    static let hairline = Color.white.opacity(0.08)
}

// MARK: - Motion (§07)

enum Duration {
    static let micro: TimeInterval = 0.090     // press, toggle
    static let standard: TimeInterval = 0.180  // cartes, sheets
    static let scene: TimeInterval = 0.320     // navigation
    static let reduceMotion: TimeInterval = 0.120
    /// Chorégraphie INJECT TRAINING.
    static let ritual: TimeInterval = 2.400
    static let fast: TimeInterval = 0.900
}

extension Animation {
    /// `motion.master` — l'unique courbe : cubic-bezier(0.16, 1, 0.3, 1).
    static var master: Animation { .timingCurve(0.16, 1, 0.3, 1, duration: Duration.standard) }
    static func master(_ duration: TimeInterval) -> Animation {
        .timingCurve(0.16, 1, 0.3, 1, duration: duration)
    }
}

// MARK: - Haptique (§05)

enum Haptic {
    @MainActor static func arm() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    @MainActor static func tick() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    @MainActor static func done() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    @MainActor static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
}

// MARK: - Helpers de surface

extension View {
    /// Carte Liquid Glass conforme : remplissage verre + hairline, radius token,
    /// zéro ombre portée (interdite par le case study).
    func glassCard(radius: CGFloat = Radius.card) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Surface.hairline, lineWidth: 1)
            }
    }

    /// Chiffres tabulaires — à appliquer sur TOUTE valeur métrique (règle absolue §05).
    func metricDigits() -> some View { self.monospacedDigit() }
}
