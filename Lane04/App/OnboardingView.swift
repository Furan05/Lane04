//
//  OnboardingView.swift
//  Lane04
//
//  Écran 01 — ONBOARDING. Trois écrans max : promesse, permission HealthKit, pairing.
//  Zéro carrousel marketing — on avance au bouton, pas au swipe.
//

import SwiftUI
import HealthKit

struct OnboardingView: View {
    let onComplete: () -> Void

    @Environment(LinkController.self) private var link
    @State private var page = 0
    private let store = HKHealthStore()

    var body: some View {
        ZStack {
            Color.void.ignoresSafeArea()
            Group {
                switch page {
                case 0:  promise
                case 1:  healthKit
                default: pairing
                }
            }
            .transition(.opacity)
        }
        .preferredColorScheme(.dark)
    }

    // 01 — promesse
    private var promise: some View {
        chrome("01 — INITIALIZE") {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text("LANE 04").font(.display).foregroundStyle(Color.laneWhite)
                Text("COMPILE. INJECT. RUN.")
                    .font(.label).tracking(1.5).foregroundStyle(Color.ember)
                Text("Un compilateur d'entraînements de course. Tu conçois ton protocole, tu l'injectes dans ta montre. Sans abonnement, sans serveur.")
                    .font(.bodyBrand).foregroundStyle(Color.steel)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } cta: {
            PrimaryActionButton(title: "INITIALIZE") { advance(to: 1) }
        }
    }

    // 02 — permission HealthKit
    private var healthKit: some View {
        chrome("02 — HEALTHKIT") {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text("HEALTHKIT").font(.titleBrand).foregroundStyle(Color.laneWhite)
                Text("LANE 04 écrit tes séances dans Santé pour les transmettre à ta montre. Aucune donnée ne quitte ton téléphone — aucun serveur.")
                    .font(.bodyBrand).foregroundStyle(Color.steel)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } cta: {
            PrimaryActionButton(title: "GRANT ACCESS") {
                Task {
                    if HKHealthStore.isHealthDataAvailable() {
                        try? await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [])
                    }
                    await link.refresh()
                    advance(to: 2)
                }
            }
        }
    }

    // 03 — pairing
    private var pairing: some View {
        chrome("03 — PAIRING") {
            VStack(alignment: .leading, spacing: Spacing.l) {
                HStack {
                    Spacer()
                    QuadIndicator(lit: link.isReady ? 4 : 2, tint: link.isReady ? .cryo : .ember)
                    Spacer()
                }
                .padding(.vertical, Spacing.l)
                Text("APPAIRE TA MONTRE").font(.titleBrand).foregroundStyle(Color.laneWhite)
                Text("Lie ta montre pour recevoir tes protocoles. Tu pourras aussi le faire plus tard depuis un protocole.")
                    .font(.bodyBrand).foregroundStyle(Color.steel)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } cta: {
            VStack(spacing: Spacing.s) {
                PrimaryActionButton(title: link.isPairing ? "PAIRING…" : "PAIR") {
                    Task { await link.pair(); onComplete() }
                }
                .disabled(link.isPairing)
                Button("LATER") { onComplete() }
                    .font(.label).tracking(1.5).foregroundStyle(Color.steel)
                    .frame(maxWidth: .infinity, minHeight: Touch.min)
            }
        }
    }

    // MARK: Chrome commun

    private func advance(to next: Int) {
        withAnimation(.master(Duration.scene)) { page = next }
    }

    @ViewBuilder
    private func chrome<Body: View, CTA: View>(
        _ index: String,
        @ViewBuilder _ body: () -> Body,
        @ViewBuilder cta: () -> CTA
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text("[\(index)]").font(.label).tracking(1.5).foregroundStyle(Color.steelHi)
            Spacer()
            body()
            Spacer()
            cta()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Grid.margin)
        .padding(.top, Grid.safeTop)
        .padding(.bottom, Grid.safeBottom)
    }
}
