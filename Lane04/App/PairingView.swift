//
//  PairingView.swift
//  Lane04
//
//  Écran 02 — PAIRING WATCH. Le QUAD sert de jauge de liaison. PAIR demande les
//  autorisations (WorkoutScheduler + HealthKit). Utilisé en sheet (depuis NO LINK)
//  et dans l'onboarding (embedded).
//

import SwiftUI

struct PairingView: View {
    var embedded: Bool = false
    var onPaired: () -> Void = {}

    @Environment(LinkController.self) private var link
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScreenScaffold(title: "PAIRING", status: link.bracket,
                       onBack: embedded ? nil : { dismiss() }) {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                HStack {
                    Spacer()
                    QuadIndicator(lit: link.isReady ? 4 : 2,
                                  tint: link.isReady ? .cryo : .ember)
                    Spacer()
                }
                .padding(.vertical, Spacing.xl)

                Text("TARGET: WATCH ULTRA 2")
                    .font(.label).tracking(1.5).foregroundStyle(Color.steelHi)

                Text("Lie ta montre pour injecter tes protocoles. Pendant l'effort, LANE 04 s'efface — l'app Exercice prend le relais.")
                    .font(.bodyBrand).foregroundStyle(Color.steel)
                    .fixedSize(horizontal: false, vertical: true)

                if link.isReady {
                    Text("TRAINING LINK ESTABLISHED")
                        .font(.label).tracking(1.5).foregroundStyle(Color.cryo)
                }

                PrimaryActionButton(title: link.isPairing ? "PAIRING…" : "PAIR") {
                    Task {
                        await link.pair()
                        if link.isReady {
                            onPaired()
                            if !embedded { dismiss() }
                        }
                    }
                }
                .disabled(link.isPairing)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await link.refresh() }
    }
}
