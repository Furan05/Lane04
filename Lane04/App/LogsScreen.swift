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

    var body: some View {
        ScreenScaffold(title: "LOGS", status: logs.isEmpty ? "IDLE" : "\(logs.count) LOGS") {
            if logs.isEmpty {
                EmptyStateView(
                    headline: "NO PAYLOAD LOGGED",
                    metric: "0",
                    note: "Chaque injection réussie s'inscrit ici."
                )
            } else {
                VStack(spacing: Spacing.s) {
                    ForEach(logs) { log in
                        LogRow(log: log)
                    }
                }
            }
        }
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
            // Trace de transmission — pas de distance/chrono courus.
            Text("INJECTED — \(Format.dateTime(log.date))")
                .font(.data).foregroundStyle(Color.steel).metricDigits()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .glassCard()
    }
}
