//
//  LogsScreen.swift
//  Lane04
//
//  Écran 05/06 — LOGS. Journal des injections (trace de transmission, PAS de séance
//  courue). On affiche tag + nom du protocole + horodatage ; JAMAIS de km/chrono
//  prétendus exécutés. Lecture HealthKit des vraies séances = chantier V2.
//

import SwiftUI
import SwiftData

struct LogsScreen: View {
    @Query(sort: \RunLog.date, order: .reverse) private var logs: [RunLog]

    /// CHARGE transmise sur les 7 derniers jours (fenêtre glissante) — le vrai usage
    /// du TRIMP : suivre la dose. Charge *transmise*, jamais *encaissée* (V2).
    private var rollingLoad: Int {
        let since = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return logs.filter { $0.date >= since }.reduce(0) { $0 + $1.load }
    }
    private var totalLoad: Int { logs.reduce(0) { $0 + $1.load } }

    var body: some View {
        ScreenScaffold(title: "LOGS", status: logs.isEmpty ? "NO DATA" : "\(logs.count) LOGS") {
            if logs.isEmpty {
                EmptyStateView(
                    headline: "NO TRAINING LOGGED",
                    metric: "0",
                    note: "Chaque injection réussie s'inscrit ici."
                )
            } else {
                VStack(spacing: Spacing.s) {
                    loadSummary
                    ForEach(logs) { log in
                        LogRow(log: log)
                    }
                }
            }
        }
    }

    // Bandeau de cumul — CHARGE transmise (7 jours glissants + total). Métriques
    // neutres, chiffres tabulaires : jamais un aplat d'accent.
    private var loadSummary: some View {
        HStack(spacing: 0) {
            summaryTile("CHARGE · 7 J", Format.load(rollingLoad))
            summaryTile("CHARGE · TOTAL", Format.load(totalLoad))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .glassCard()
    }

    private func summaryTile(_ label: String, _ value: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(label).font(.label).tracking(1.5).foregroundStyle(Color.steelHi)
            Text(value).font(.data).foregroundStyle(Color.laneWhite).metricDigits()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct LogRow: View {
    let log: RunLog

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                TagBadge(discipline: log.discipline)
                Spacer()
                StateBadge(state: .synced)
            }
            Text(log.protocolName.isEmpty ? "PROTOCOL" : log.protocolName)
                .font(.bodyBrand).foregroundStyle(Color.laneWhite)
            // Trace de transmission — pas de distance/chrono courus. CHARGE = charge
            // planifiée transmise (figée à l'injection), à droite en chasse fixe.
            HStack(spacing: Spacing.s) {
                Text("INJECTED — \(Format.dateTime(log.date))")
                    .font(.data).foregroundStyle(Color.steel).metricDigits()
                Spacer()
                Text("CHARGE \(Format.load(log.load))")
                    .font(.data).foregroundStyle(Color.steelHi).metricDigits()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .glassCard()
    }
}
