//
//  Typography.swift
//  Lane04
//
//  Échelle typographique (§05). Archivo Expanded = voix, JetBrains Mono = donnée.
//  Polices variables pilotées par axes (wght + wdth) via UIFontDescriptor, puis
//  mises à l'échelle par UIFontMetrics → Dynamic Type respecté.
//
//  Fichiers (OFL) dans Lane04/Resources/Fonts/, enregistrés au lancement par
//  FontRegistrar. Familles confirmées via le log DEBUG : "Archivo", "JetBrains Mono".
//

import SwiftUI
import UIKit

/// Familles des polices de marque (confirmées au dépôt des fichiers).
enum BrandFont {
    static let archivo = "Archivo"          // variable wght + wdth (Expanded = wdth 125)
    static let jetBrainsMono = "JetBrains Mono" // variable wght, mono tabulaire natif
}

/// Identifiants d'axes de variation OpenType (4-char codes).
private enum Axis {
    static let wght = 0x77676874 // 'wght'
    static let wdth = 0x77647468 // 'wdth'
}

/// Construit une police de marque à un poids/chasse donnés.
private func brandUIFont(_ family: String, size: CGFloat, wght: Double, wdth: Double? = nil) -> UIFont {
    var variations: [Int: Double] = [Axis.wght: wght]
    if let wdth { variations[Axis.wdth] = wdth }
    let descriptor = UIFontDescriptor(fontAttributes: [
        .family: family,
        UIFontDescriptor.AttributeName(rawValue: "NSCTFontVariationAttribute"): variations
    ])
    return UIFont(descriptor: descriptor, size: size)
}

/// Enveloppe une UIFont dans une Font SwiftUI qui suit Dynamic Type.
private func metricsFont(_ base: UIFont, _ style: UIFont.TextStyle) -> Font {
    Font(UIFontMetrics(forTextStyle: style).scaledFont(for: base))
}

extension Font {
    /// DISPLAY / 64 — Archivo Expanded 900. Titres héroïques.
    static var display: Font { metricsFont(brandUIFont(BrandFont.archivo, size: 64, wght: 900, wdth: 125), .largeTitle) }
    /// TITLE / 28 — Archivo Expanded 800. Titres d'écran, navigation.
    static var titleBrand: Font { metricsFont(brandUIFont(BrandFont.archivo, size: 28, wght: 800, wdth: 125), .title1) }
    /// BODY / 16 — Archivo 400 (chasse normale). Texte de lecture.
    static var bodyBrand: Font { metricsFont(brandUIFont(BrandFont.archivo, size: 16, wght: 400), .body) }
    /// BUTTON / 18 — Archivo Expanded 800. La voix appliquée aux boutons.
    static var button: Font { metricsFont(brandUIFont(BrandFont.archivo, size: 18, wght: 800, wdth: 125), .headline) }
    /// DATA-XL / 56 — JB Mono 500 tabular. Readout d'allure.
    static var dataXL: Font { metricsFont(brandUIFont(BrandFont.jetBrainsMono, size: 56, wght: 500), .largeTitle) }
    /// DATA / 20 — JB Mono 400 tabular. Valeurs métriques.
    static var data: Font { metricsFont(brandUIFont(BrandFont.jetBrainsMono, size: 20, wght: 400), .body) }
    /// LABEL / 11 — JB Mono 400, CAPS, +14 %. Statuts, labels système.
    static var label: Font { metricsFont(brandUIFont(BrandFont.jetBrainsMono, size: 11, wght: 400), .caption2) }
}

extension View {
    /// Style label système : MAJUSCULES, interlettrage +14 % (§05).
    func systemLabelStyle() -> some View {
        self.font(.label).textCase(.uppercase).tracking(1.5)
    }
}

/// Enregistre au lancement toutes les polices présentes dans le bundle.
enum FontRegistrar {
    @MainActor static func registerAll() {
        var registered = 0
        for ext in ["ttf", "otf"] {
            for url in Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? [] {
                if CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) {
                    registered += 1
                }
            }
        }
        #if DEBUG
        if registered == 0 {
            print("[LANE04] ⚠️ Aucune police de marque enregistrée — repli SF Pro/SF Mono.")
        } else {
            print("[LANE04] \(registered) police(s) enregistrée(s). Familles Archivo/JetBrains dispo :")
            for family in UIFont.familyNames where family.contains("Archivo") || family.contains("JetBrains") {
                print("  • \(family) → \(UIFont.fontNames(forFamilyName: family))")
            }
        }
        #endif
    }
}
