//
//  CalibrationInputs.swift
//  Lane04
//
//  Les deux voies de calibration VMA, réutilisées en OPERATOR et en onboarding.
//  L'instrument montre toujours sa formule et ne prétend rien qu'il ne sache.
//

import SwiftUI

// MARK: - Sélecteur de voie + picker (mutuellement exclusif)

/// Voie de calibration active — un seul picker (donc un seul aplat d'accent EMBER)
/// visible à la fois, cf. règle absolue n°1.
enum CalibrationVoie: String, CaseIterable, Identifiable {
    case measure = "MESURE"
    case estimate = "ESTIMATION"
    var id: String { rawValue }
}

/// Les deux voies de calibration sous un sélecteur, partagées entre OPERATOR et
/// l'onboarding. `onCommit` reçoit la VMA retenue + sa provenance.
struct CalibrationVoiePicker: View {
    var onCommit: (Double, VMAProvenance) -> Void

    @State private var voie: CalibrationVoie = .measure

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            selector
            switch voie {
            case .measure:
                MeasurePicker { onCommit($0, .calibrated) }
            case .estimate:
                EstimationPicker { vma, _ in onCommit(vma, .estimated) }
            }
        }
    }

    private var selector: some View {
        HStack(spacing: 1) {
            ForEach(CalibrationVoie.allCases) { v in
                let active = v == voie
                Button {
                    Haptic.selection()
                    withAnimation(.master(Duration.micro)) { voie = v }
                } label: {
                    Text(v.rawValue)
                        .font(.label).tracking(1.5)
                        .foregroundStyle(active ? Color.void : Color.steel)
                        .frame(maxWidth: .infinity, minHeight: Touch.min)
                        .background(active ? Color.laneWhite : Color.carbon2)
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.control))
    }
}

// MARK: - Estimation (course récente → VMA) — statut [ESTIMATED]

struct EstimationPicker: View {
    /// (vma, coefficient)
    var onEstimate: (Double, Double) -> Void

    @State private var distance: RaceDistance = .tenK
    @State private var seconds: Int = 3000 // 50:00

    private var result: (vma: Double, coefficient: Double) {
        VMAEstimator.estimate(distance, seconds: Double(seconds))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(spacing: Spacing.s) {
                ForEach(RaceDistance.allCases) { d in distanceChip(d) }
            }

            CalibrationStepper(label: "CHRONO", value: Format.clock(seconds)) {
                seconds = max(900, min(9000, seconds - 30))
            } plus: {
                seconds = max(900, min(9000, seconds + 30))
            }

            // Readout + formule affichée (coefficient discret réellement utilisé).
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(String(format: "%.1f", result.vma))
                    .font(.dataXL).foregroundStyle(Color.laneWhite).metricDigits()
                    .contentTransition(.numericText())
                Text("KM/H").font(.label).tracking(1.5).foregroundStyle(Color.steel)
            }
            Text("\(distance.rawValue) \(Format.clock(seconds)) → coeff \(String(format: "%.2f", result.coefficient))")
                .font(.data).foregroundStyle(Color.steelHi).metricDigits()

            PrimaryActionButton(title: "USE ESTIMATE") {
                onEstimate(result.vma, result.coefficient)
            }
        }
    }

    private func distanceChip(_ d: RaceDistance) -> some View {
        let active = d == distance
        return Button {
            Haptic.selection()
            withAnimation(.master(Duration.micro)) { distance = d }
        } label: {
            Text(d.rawValue)
                .font(.label).tracking(1.5)
                .foregroundStyle(active ? Color.void : Color.steel)
                .frame(maxWidth: .infinity, minHeight: Touch.min)
                .background(active ? Color.laneWhite : Color.carbon2,
                            in: RoundedRectangle(cornerRadius: Radius.control))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mesure (demi-Cooper) — statut [CALIBRATED]

struct MeasurePicker: View {
    var onMeasure: (Double) -> Void

    @State private var meters: Int = 1400 // → VMA 14.0

    private var vma: Double { VMACalculator.vmaFromHalfCooper(meters: Double(meters)) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            CalibrationStepper(label: "DISTANCE 6:00", value: "\(meters) M") {
                meters = max(500, min(3600, meters - 10))
            } plus: {
                meters = max(500, min(3600, meters + 10))
            }

            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(String(format: "%.1f", vma))
                    .font(.dataXL).foregroundStyle(Color.laneWhite).metricDigits()
                    .contentTransition(.numericText())
                Text("KM/H").font(.label).tracking(1.5).foregroundStyle(Color.steel)
            }
            // Formule demi-Cooper affichée.
            Text("VMA = \(meters) / 100")
                .font(.data).foregroundStyle(Color.steelHi).metricDigits()

            PrimaryActionButton(title: "VALIDATE") { onMeasure(vma) }
        }
    }
}

// MARK: - Stepper de calibration (valeur mono + crans −/+)

private struct CalibrationStepper: View {
    let label: String
    let value: String
    let minus: () -> Void
    let plus: () -> Void

    var body: some View {
        HStack(spacing: Spacing.m) {
            Text(label).font(.label).tracking(1.5).foregroundStyle(Color.steel)
            Spacer()
            Text(value).font(.data).foregroundStyle(Color.laneWhite).metricDigits()
            HStack(spacing: 1) {
                cran("minus", minus)
                cran("plus", plus)
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.control))
        }
        .frame(minHeight: Touch.min)
    }

    private func cran(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button {
            Haptic.selection()
            withAnimation(.master(Duration.micro)) { action() }
        } label: {
            Image(systemName: symbol).font(.subheadline).foregroundStyle(Color.laneWhite)
                .frame(width: Touch.min, height: Touch.min)
                .background(Color.carbon2)
        }
        .buttonStyle(.plain)
    }
}
