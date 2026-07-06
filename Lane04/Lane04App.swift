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
        // Seam de test UI : sauter l'onboarding pour atteindre directement l'app.
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-uitest-skip-onboarding") {
            UserDefaults.standard.set(true, forKey: "hasOnboarded")
        }
        if args.contains("-uitest-force-onboarding") {
            UserDefaults.standard.set(false, forKey: "hasOnboarded")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            RunProtocol.self,
            ProtocolBlock.self,
            ProtocolStep.self,
            OperatorProfile.self,
            RunLog.self
        ])
    }
}
