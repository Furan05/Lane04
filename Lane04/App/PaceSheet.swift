//
//  PaceSheet.swift
//  Lane04
//
//  Écran 12 — SHEET / SÉLECTEUR D'ALLURE. Readout DATA-XL, règle graduée, crans 5 s,
//  zone physiologique en direct. OUT OF RANGE : readout EMBER, COMMIT reste actif
//  (l'athlète a toujours raison), mais l'écart est nommé.
//

import SwiftUI

struct PaceSheet: View {
    @Bindable var step: ProtocolStep
    let vma: Double
    let provenance: VMAProvenance
    @Environment(\.dismiss) private var dismiss
    /// L'allure en s/km est la valeur de TRAVAIL de cet écran : molette et boutons la
    /// pilotent tous les deux, et le % n'en est dérivé qu'à l'affichage. Ce qui est
    /// PERSISTÉ au COMMIT reste `step.percentVMA` (relatif à la VMA).
    @State private var paceSeconds: Int

    init(step: ProtocolStep, vma: Double, provenance: VMAProvenance = .calibrated) {
        self._step = Bindable(wrappedValue: step)
        self.vma = vma
        self.provenance = provenance
        let initial = VMACalculator.paceSecondsPerKm(vma: vma, percent: step.percentVMA) ?? 240
        self._paceSeconds = State(initialValue: Int(initial.rounded()))
    }

    private var currentPercent: Double {
        VMACalculator.percent(paceSecondsPerKm: Double(paceSeconds), vma: vma)
    }
    private var zone: TrainingZone? { TrainingZone.zone(forPercent: currentPercent) }
    private var outOfRange: Bool { zone == nil }
    private var readoutTint: Color { outOfRange ? .ember : .laneWhite }

    private func paceLabel(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    var body: some View {
        ZStack {
            Color.void.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.xl) {
                HStack {
                    Text("EFFORT PACE").font(.label).tracking(1.5).foregroundStyle(Color.steelHi)
                    Spacer()
                    if let zone {
                        Text("ZONE: \(zone.rawValue)").font(.label).tracking(1.5).foregroundStyle(zone.color)
                    } else {
                        Text("[OUT OF RANGE]").font(.label).tracking(1.5).foregroundStyle(Color.ember)
                    }
                }

                // Readout DATA-XL
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text(paceLabel(paceSeconds))
                        .font(.dataXL).foregroundStyle(readoutTint)
                        .metricDigits().contentTransition(.numericText())
                    Text("/KM").font(.label).tracking(1.5).foregroundStyle(Color.steel)
                }
                if let zone {
                    Text(zone.effect).font(.bodyBrand).foregroundStyle(Color.steel)
                }

                // Molette — mode de saisie complémentaire, MÊME valeur que les boutons.
                PaceWheel(paceSeconds: $paceSeconds, vma: vma, provenance: provenance)

                // Crans ±5 s — la voie précise, inchangée.
                HStack(spacing: Spacing.s) {
                    cranButton("−5S") { adjust(+5) }   // plus lent = allure + grande
                    cranButton("+5S") { adjust(-5) }   // plus rapide = allure - petite
                }

                PrimaryActionButton(title: "COMMIT") {
                    step.percentVMA = currentPercent
                    dismiss()
                }
            }
            .padding(.horizontal, Grid.margin)
            .padding(.top, Spacing.xl)
        }
        .presentationBackground(Color.void)
        .presentationCornerRadius(Radius.sheet)
        .presentationDetents([.medium])
    }

    // L'ancienne règle graduée STATIQUE (9 traits fixes autour du centre) est
    // remplacée par `PaceWheel` : une vraie échelle qui défile, avec les mêmes crans
    // de 5 s. En garder deux superposées donnerait deux graduations contradictoires.

    private func cranButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button {
            Haptic.selection()
            withAnimation(.master(Duration.micro)) { action() }
        } label: {
            Text(title)
                .font(.data).foregroundStyle(Color.laneWhite).metricDigits()
                .frame(maxWidth: .infinity, minHeight: Touch.min)
                .background(Color.carbon2, in: RoundedRectangle(cornerRadius: Radius.control))
        }
        .buttonStyle(PressableStyle())
    }

    private func adjust(_ deltaSeconds: Int) {
        paceSeconds = max(120, min(600, paceSeconds + deltaSeconds)) // 2:00 … 10:00
    }
}
