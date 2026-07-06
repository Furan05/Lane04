//
//  OperatorScreen.swift
//  Lane04
//
//  Écran 08 — OPERATOR. Profil physiologique : VMA saisie, zones Z1–Z5 dérivées,
//  spectre thermique. Accessible depuis CONSOLE.
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

    var body: some View {
        ScreenScaffold(title: "OPERATOR", status: "CALIBRATED", onBack: onBack) {
            VStack(spacing: Spacing.xl) {
                vmaEditor
                zonesList
            }
        }
    }

    // MARK: VMA

    private var vmaEditor: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("VMA")
                .font(.label).tracking(1.5).foregroundStyle(Color.cryo)
            HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text(String(format: "%.1f", profile.vma))
                        .font(.dataXL).foregroundStyle(Color.laneWhite)
                        .metricDigits().contentTransition(.numericText())
                    Text("KM/H").font(.label).tracking(1.5).foregroundStyle(Color.steel)
                }
                Spacer()
                stepper
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .glassCard()
    }

    private var stepper: some View {
        HStack(spacing: 1) {
            stepButton("minus") { setVMA(profile.vma - 0.5) }
            stepButton("plus") { setVMA(profile.vma + 0.5) }
        }
        .background(Surface.hairline)
        .clipShape(RoundedRectangle(cornerRadius: Radius.control))
    }

    private func stepButton(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button {
            Haptic.selection()
            withAnimation(.master(Duration.micro)) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(Color.laneWhite)
                .frame(width: Touch.min, height: Touch.min)
                .background(Color.carbon2)
        }
        .buttonStyle(.plain)
    }

    private func setVMA(_ value: Double) {
        profile.vma = min(25, max(8, (value * 2).rounded() / 2))
        profile.updatedAt = .now
    }

    // MARK: Zones + spectre thermique

    private var zonesList: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("ZONES")
                .font(.label).tracking(1.5).foregroundStyle(Color.steelHi)
            VStack(spacing: 0) {
                let zones = Array(TrainingZone.allCases.reversed()) // Z5 → Z1
                ForEach(Array(zones.enumerated()), id: \.element) { index, zone in
                    zoneRow(zone, t: Double(index) / Double(zones.count - 1))
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

    private func zoneRow(_ zone: TrainingZone, t: Double) -> some View {
        let tint = Color.ember.blended(with: .cryo, t: t) // spectre EMBER→CRYO
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
