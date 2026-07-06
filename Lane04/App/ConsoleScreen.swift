//
//  ConsoleScreen.swift
//  Lane04
//
//  Écran 07 — CONSOLE. Réglages en paires clé/valeur (@AppStorage) + accès OPERATOR.
//  TX MODE ne sera réellement testable qu'avec l'injection (Phase 3).
//

import SwiftUI
import SwiftData

struct ConsoleScreen: View {
    @AppStorage(SettingsKey.txMode) private var txMode = TXMode.ritual.rawValue
    @AppStorage(SettingsKey.paceUnit) private var paceUnit = PaceUnit.minPerKm.rawValue
    @AppStorage(SettingsKey.haptics) private var haptics = true
    @AppStorage(SettingsKey.watchTarget) private var target = WatchTarget.ultra2.rawValue

    @Query private var profiles: [OperatorProfile]
    private var vma: Double { profiles.first?.vma ?? 16.0 }

    var body: some View {
        NavigationStack {
            ScreenScaffold(title: "CONSOLE", status: "V1.0") {
                VStack(spacing: Spacing.l) {
                    NavigationLink { OperatorScreen() } label: { operatorRow }
                        .buttonStyle(PressableStyle())

                    settingsCard
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: OPERATOR entry

    private var operatorRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("OPERATOR").font(.button).foregroundStyle(Color.laneWhite)
                Text("PROFIL PHYSIOLOGIQUE").font(.label).tracking(1.5).foregroundStyle(Color.steelHi)
            }
            Spacer()
            Text("VMA \(String(format: "%.1f", vma))")
                .font(.data).foregroundStyle(Color.cryo).metricDigits()
            Image(systemName: "chevron.right").font(.headline).foregroundStyle(Color.steel)
        }
        .frame(maxWidth: .infinity, minHeight: Touch.min, alignment: .leading)
        .padding(Spacing.l)
        .glassCard()
    }

    // MARK: Réglages

    private var settingsCard: some View {
        VStack(spacing: 0) {
            cycleRow("TX MODE", $txMode, TXMode.allCases.map(\.rawValue))
            hairline
            cycleRow("UNITS", $paceUnit, PaceUnit.allCases.map(\.rawValue))
            hairline
            toggleRow("HAPTICS", $haptics)
            hairline
            cycleRow("TARGET", $target, WatchTarget.allCases.map(\.rawValue))
        }
        .padding(.horizontal, Spacing.l)
        .glassCard()
    }

    private func cycleRow(_ key: String, _ value: Binding<String>, _ options: [String]) -> some View {
        Button {
            Haptic.selection()
            let i = options.firstIndex(of: value.wrappedValue) ?? -1
            value.wrappedValue = options[(i + 1) % options.count]
        } label: {
            row(key, value.wrappedValue)
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(_ key: String, _ value: Binding<Bool>) -> some View {
        Button {
            Haptic.selection()
            value.wrappedValue.toggle()
        } label: {
            row(key, value.wrappedValue ? "ON" : "OFF")
        }
        .buttonStyle(.plain)
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).font(.label).tracking(1.5).foregroundStyle(Color.steel)
            Spacer()
            Text(value).font(.data).foregroundStyle(Color.laneWhite).metricDigits()
        }
        .frame(minHeight: Touch.min)
        .contentShape(Rectangle())
    }

    private var hairline: some View {
        Rectangle().fill(Surface.hairline).frame(height: 1)
    }
}
