//
//  OperatorScreen.swift
//  Lane04
//
//  Écran 08 — OPERATOR. Profil physiologique : VMA (mesurée / estimée / défaut),
//  zones Z1–Z5 dérivées, spectre thermique. Accessible depuis CONSOLE.
//  L'instrument distingue toujours la MESURE de l'ESTIMATION et montre sa formule.
//

import SwiftUI
import SwiftData

struct OperatorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [OperatorProfile]

    var body: some View {
        Group {
            if let profile = profiles.first {
                OperatorContent(profile: profile, onBack: { dismiss() })
            } else {
                ScreenScaffold(title: "OPERATOR", status: "NO DATA", onBack: { dismiss() }) {
                    EmptyStateView(headline: "PROFILE MISSING", metric: "--", note: "Profil indisponible.")
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct OperatorContent: View {
    @Bindable var profile: OperatorProfile
    let onBack: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    var body: some View {
        ScreenScaffold(title: "OPERATOR", status: statusText, onBack: onBack) {
            VStack(spacing: Spacing.xl) {
                vmaReadout
                calibration
                zonesList
            }
        }
    }

    // MARK: Statut [BRACKET] selon provenance

    private var statusText: String {
        switch profile.provenance {
        case .calibrated:   return "CALIBRATED — \(Format.dayMonth(profile.updatedAt))"
        case .estimated:    return "ESTIMATED"
        case .uncalibrated: return "UNCALIBRATED"
        }
    }

    /// Ligne de provenance en français (langue de lecture) sous la VMA.
    private var provenanceNote: String {
        switch profile.provenance {
        case .calibrated:   return "Mesurée au test 6 min le \(Format.dayMonth(profile.updatedAt))."
        case .estimated:    return "Estimée d'une course récente. Mesure-la pour plus de précision."
        case .uncalibrated: return "Valeur par défaut. Calibre pour caler tes zones."
        }
    }

    private var provenanceTint: Color {
        profile.provenance == .calibrated ? .cryo : .steel
    }

    // MARK: VMA (lecture seule — la valeur se règle par calibration)

    private var vmaReadout: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("VMA")
                .font(.label).tracking(1.5).foregroundStyle(provenanceTint)
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(String(format: "%.1f", profile.vma))
                    .font(.dataXL).foregroundStyle(Color.laneWhite)
                    .metricDigits().contentTransition(.numericText())
                Text("KM/H").font(.label).tracking(1.5).foregroundStyle(Color.steel)
            }
            Text(provenanceNote)
                .font(.bodyBrand).foregroundStyle(Color.steel)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .glassCard()
    }

    // MARK: CALIBRATION (deux voies, mutuellement exclusives)

    private var calibration: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text("CALIBRATION")
                .font(.label).tracking(1.5).foregroundStyle(Color.steelHi)
            CalibrationVoiePicker(
                onCommit: { vma, provenance in commit(vma, provenance: provenance) },
                onPrepareTest: prepareAndOpenTest
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .glassCard()
    }

    /// Clone-ou-réutilise TEST_VMA (idempotent) et ouvre son éditeur par le chemin
    /// nominal — le hero INJECT PAYLOAD y fait le reste. Aucun flux parallèle.
    private func prepareAndOpenTest() {
        guard let test = ProtocolActions.prepareTestVMA(in: modelContext) else { return }
        router.openEditor(test)
    }

    private func commit(_ vma: Double, provenance: VMAProvenance) {
        withAnimation(.master(Duration.micro)) {
            profile.vma = min(25, max(8, vma))
            profile.provenance = provenance
            profile.updatedAt = .now
        }
        Haptic.done()
    }

    // MARK: Zones + spectre thermique

    private var zonesList: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("ZONES")
                .font(.label).tracking(1.5).foregroundStyle(Color.steelHi)
            VStack(spacing: 0) {
                let zones = Array(TrainingZone.allCases.reversed()) // Z5 → Z1
                ForEach(zones) { zone in
                    zoneRow(zone)
                    if zone != zones.last {
                        Rectangle().fill(Surface.hairline).frame(height: 1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .glassCard()
    }

    private func zoneRow(_ zone: TrainingZone) -> some View {
        let tint = zone.color
        return HStack(spacing: Spacing.m) {
            RoundedRectangle(cornerRadius: 1)
                .fill(tint)
                .frame(width: 4, height: 36)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(zone.rawValue)
                    .font(.label).tracking(1.5).foregroundStyle(tint)
                Text(zone.effect)
                    .font(.bodyBrand).foregroundStyle(Color.steel)
            }
            Spacer()
            Text("\(zone.paceRangeString(vma: profile.vma)) /KM")
                .font(.data).foregroundStyle(Color.laneWhite).metricDigits()
        }
        .frame(minHeight: Touch.min)
    }
}
