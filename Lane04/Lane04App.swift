//
//  Lane04App.swift
//  Lane04
//
//  Created by François.Dubois on 03/07/2026.
//

import SwiftUI
import SwiftData

@main
struct Lane04App: App {
    init() {
        FontRegistrar.registerAll()
        #if DEBUG
        // Seam de test UI (DEBUG uniquement — jamais dans le binaire de prod, même
        // inerte) : pilote `hasOnboarded` via arguments de lancement.
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-uitest-skip-onboarding") {
            UserDefaults.standard.set(true, forKey: "hasOnboarded")
        }
        if args.contains("-uitest-force-onboarding") {
            UserDefaults.standard.set(false, forKey: "hasOnboarded")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-uitest-glyph-preview") {
                NavGlyphPreview()   // galerie de validation des glyphes (capture)
            } else {
                RootView()
            }
            #else
            RootView()
            #endif
        }
        .modelContainer(for: [
            RunProtocol.self,
            ProtocolBlock.self,
            ProtocolStep.self,
            OperatorProfile.self,
            RunLog.self,
            PlannedSession.self
        ])
    }
}
