//
//  Typography.swift
//  Lane04
//
//  Échelle typographique (§05). Archivo Expanded = voix, JetBrains Mono = donnée.
//  Les Font.* sont relatifs à un TextStyle → suivent UIFontMetrics / Dynamic Type.
//
//  ⚠️ POLICES : déposer les fichiers OFL dans Lane04/Resources/Fonts/
//     (Archivo variable + JetBrains Mono). Tant qu'ils sont absents, `Font.custom`
//     retombe automatiquement sur la police système — l'app reste fonctionnelle.
//     À confirmer une fois les fichiers présents : les noms PostScript exacts
//     (FontRegistrar loggue les familles disponibles en DEBUG).
//

import SwiftUI
import UIKit

/// Noms PostScript attendus des polices de marque (à valider au dépôt des fichiers).
enum BrandFont {
    static let voiceBlack = "ArchivoExpanded-Black"      // DISPLAY 900
    static let voiceExtraBold = "ArchivoExpanded-ExtraBold" // TITLE 800
    static let voiceRegular = "Archivo-Regular"          // BODY 400
    static let dataMedium = "JetBrainsMono-Medium"       // DATA-XL 500
    static let dataRegular = "JetBrainsMono-Regular"     // DATA / LABEL 400
}

extension Font {
    /// DISPLAY / 64 — Archivo Exp 900. Titres héroïques.
    static var display: Font { .custom(BrandFont.voiceBlack, size: 64, relativeTo: .largeTitle) }
    /// TITLE / 28 — Archivo Exp 800. Titres d'écran, navigation.
    static var titleBrand: Font { .custom(BrandFont.voiceExtraBold, size: 28, relativeTo: .title) }
    /// BODY / 16 — Archivo 400. Texte de lecture (français).
    static var bodyBrand: Font { .custom(BrandFont.voiceRegular, size: 16, relativeTo: .body) }
    /// DATA-XL / 56 — JB Mono 500 tabular. Readout d'allure.
    static var dataXL: Font { .custom(BrandFont.dataMedium, size: 56, relativeTo: .largeTitle) }
    /// DATA / 20 — JB Mono 400 tabular. Valeurs métriques.
    static var data: Font { .custom(BrandFont.dataRegular, size: 20, relativeTo: .body) }
    /// LABEL / 11 — JB Mono 400, CAPS, +14 %. Statuts, labels système.
    static var label: Font { .custom(BrandFont.dataRegular, size: 11, relativeTo: .caption2) }
}

extension View {
    /// Style label système : mono, MAJUSCULES, interlettrage +14 % (§05).
    func systemLabelStyle() -> some View {
        self.font(.label).textCase(.uppercase).tracking(1.5)
    }
}

/// Enregistre au lancement toutes les polices présentes dans le bundle.
enum FontRegistrar {
    @MainActor static func registerAll() {
        let exts = ["ttf", "otf"]
        var registered = 0
        for ext in exts {
            for url in Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? [] {
                var error: Unmanaged<CFError>?
                if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                    registered += 1
                }
            }
        }
        #if DEBUG
        if registered == 0 {
            print("[LANE04] ⚠️ Aucune police de marque enregistrée — repli SF Pro/SF Mono. Déposer les fichiers dans Resources/Fonts/.")
        } else {
            print("[LANE04] \(registered) police(s) enregistrée(s). Familles Archivo/JetBrains dispo :")
            for family in UIFont.familyNames where family.contains("Archivo") || family.contains("JetBrains") {
                print("  • \(family) → \(UIFont.fontNames(forFamilyName: family))")
            }
        }
        #endif
    }
}
