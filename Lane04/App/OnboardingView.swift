//
//  OnboardingView.swift
//  Lane04
//
//  Écran 01 — ONBOARDING. Quatre écrans : promesse, CALIBRATION, HealthKit, pairing.
//  La CALIBRATION est en 2e position mais **skippable en un tap** (défaut 14.0,
//  [UNCALIBRATED]) — dérogation aux « 3 écrans max » documentée dans session-notes.
//  Zéro carrousel marketing — on avance au bouton, pas au swipe.
//

import SwiftUI
import SwiftData
import HealthKit

struct OnboardingView: View {
    let onComplete: () -> Void

    @Environment(LinkController.self) private var link
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [OperatorProfile]
    @State private var page = 0
    private let store = HKHealthStore()

    var body: some View {
        ZStack {
            Color.void.ignoresSafeArea()
            Group {
                switch page {
                case 0:  promise
                case 1:  calibration
                case 2:  healthKit
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

    // 02 — CALIBRATION (skippable en un tap)
    private var calibration: some View {
        chrome("02 — CALIBRATION") {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text("CALIBRATION").font(.titleBrand).foregroundStyle(Color.laneWhite)
                Text("Ta VMA cale toutes tes allures. Mesure-la (test 6 min) ou estime-la d'une course récente. Sinon, on part sur 14.0 par défaut — tu calibreras plus tard depuis OPERATOR.")
                    .font(.bodyBrand).foregroundStyle(Color.steel)
                    .fixedSize(horizontal: false, vertical: true)
                CalibrationVoiePicker { vma, provenance in
                    commitVMA(vma, provenance: provenance)
                    advance(to: 2)
                }
            }
        } cta: {
            Button("TESTER PLUS TARD") { advance(to: 2) }
                .font(.label).tracking(1.5).foregroundStyle(Color.steel)
                .frame(maxWidth: .infinity, minHeight: Touch.min)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.button)
                        .strokeBorder(Surface.hairline, lineWidth: 1)
                }
        }
    }

    /// Écrit la VMA calibrée dans le profil (créé au seed ; recréé au besoin).
    private func commitVMA(_ vma: Double, provenance: VMAProvenance) {
        let clamped = min(25, max(8, vma))
        if let profile = profiles.first {
            profile.vma = clamped
            profile.provenance = provenance
            profile.updatedAt = .now
        } else {
            modelContext.insert(OperatorProfile(vma: clamped, provenance: provenance))
        }
        try? modelContext.save()
    }

    // 03 — permission HealthKit
    private var healthKit: some View {
        chrome("03 — HEALTHKIT") {
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
                    advance(to: 3)
                }
            }
        }
    }

    // 04 — pairing
    private var pairing: some View {
        chrome("04 — PAIRING") {
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
