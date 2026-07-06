//
//  RootView.swift
//  Lane04
//
//  Coquille de navigation (Phase 0). Tab bar PROTOCOLS / LOGS / CONSOLE.
//  Les écrans sont des placeholders thémés — leur contenu réel arrive en Phase 2–3.
//

import SwiftUI
import SwiftData

// MARK: - Onglets

enum Tab: String, CaseIterable, Identifiable {
    case protocols = "PROTOCOLS"
    case logs = "LOGS"
    case console = "CONSOLE"
    var id: String { rawValue }
}

// MARK: - Racine

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var tab: Tab = .protocols

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.void.ignoresSafeArea()

            Group {
                switch tab {
                case .protocols: ProtocolsScreen()
                case .logs: LogsScreen()
                case .console: ConsoleScreen()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            TabBar(selection: $tab)
        }
        .preferredColorScheme(.dark)
        .task { Seeder.seedIfNeeded(modelContext) }
    }
}

// MARK: - Tab bar (custom, typo mono conforme)

private struct TabBar: View {
    @Binding var selection: Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                let isActive = tab == selection
                Button {
                    withAnimation(.master(Duration.micro)) { selection = tab }
                } label: {
                    Text(tab.rawValue)
                        .font(.label)
                        .tracking(1.5)
                        // L'onglet actif reste en blanc : l'accent est réservé aux actions.
                        .foregroundStyle(isActive ? Color.laneWhite : Color.steel)
                        .frame(maxWidth: .infinity, minHeight: Touch.min)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.s)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(Surface.hairline).frame(height: 1)
        }
    }
}

// MARK: - Scaffold commun (grammaire : statut [BRACKET] en haut à droite)

struct ScreenScaffold<Content: View>: View {
    let title: String
    let status: String
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color.void.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.xl) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.titleBrand)
                        .foregroundStyle(Color.laneWhite)
                    Spacer()
                    StatusBadge(status)
                }
                content
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Grid.margin)
            .padding(.top, Grid.safeTop)
            .padding(.bottom, Grid.safeBottom + Touch.min)
        }
    }
}

/// Statut système `[BRACKET]` — mono, radius 0, contour hairline.
struct StatusBadge: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text("[\(text)]")
            .font(.label)
            .tracking(1.5)
            .foregroundStyle(Color.steelHi)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.badge)
                    .strokeBorder(Surface.hairline, lineWidth: 1)
            }
    }
}

// MARK: - Placeholders thémés (Phase 0)

private struct ProtocolsScreen: View {
    @Query(filter: #Predicate<RunProtocol> { $0.isTemplate }, sort: \RunProtocol.name)
    private var templates: [RunProtocol]

    var body: some View {
        ScreenScaffold(title: "PROTOCOLS", status: "IDLE") {
            if templates.isEmpty {
                EmptyStateView(
                    headline: "NO PROTOCOL COMPILED",
                    metric: "0 PAYLOADS",
                    note: "Les protocoles arrivent avec ta première compilation."
                )
            } else {
                // Phase 1 : preuve du seed. La vraie liste (cellules, tags) arrive en Phase 3.
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("\(templates.count)")
                        .font(.dataXL).foregroundStyle(Color.laneWhite).metricDigits()
                    Text("TEMPLATES DISPONIBLES")
                        .font(.label).tracking(1.5).foregroundStyle(Color.steelHi)
                    Text("Clonables en [DRAFT] via COMPILE FROM TEMPLATE — liste en Phase 3.")
                        .font(.bodyBrand).foregroundStyle(Color.steel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.l)
                .glassCard()
            }
        }
    }
}

private struct LogsScreen: View {
    var body: some View {
        ScreenScaffold(title: "LOGS", status: "30D") {
            EmptyStateView(
                headline: "NO DATA LOGGED",
                metric: "0.0 KM",
                note: "Les données arrivent avec la première séance."
            )
        }
    }
}

private struct ConsoleScreen: View {
    @AppStorage(SettingsKey.txMode) private var txMode = TXMode.ritual.rawValue
    @AppStorage(SettingsKey.paceUnit) private var paceUnit = PaceUnit.minPerKm.rawValue
    @AppStorage(SettingsKey.haptics) private var haptics = true
    @AppStorage(SettingsKey.watchTarget) private var target = WatchTarget.ultra2.rawValue

    var body: some View {
        ScreenScaffold(title: "CONSOLE", status: "V1.0") {
            VStack(spacing: 0) {
                settingRow("TX MODE", txMode)
                hairline
                settingRow("UNITS", paceUnit)
                hairline
                settingRow("HAPTICS", haptics ? "ON" : "OFF")
                hairline
                settingRow("TARGET", target)
            }
        }
    }

    private func settingRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).font(.label).tracking(1.5).foregroundStyle(Color.steel)
            Spacer()
            Text(value).font(.data).foregroundStyle(Color.laneWhite).metricDigits()
        }
        .frame(minHeight: Touch.min)
    }

    private var hairline: some View {
        Rectangle().fill(Surface.hairline).frame(height: 1)
    }
}

/// Vide conforme : le zéro est une donnée, affiché en mono, jamais une excuse.
private struct EmptyStateView: View {
    let headline: String
    let metric: String
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(metric)
                .font(.dataXL)
                .foregroundStyle(Color.laneWhite)
                .metricDigits()
            Text(headline)
                .font(.label)
                .tracking(1.5)
                .foregroundStyle(Color.steelHi)
            Text(note)
                .font(.bodyBrand)
                .foregroundStyle(Color.steel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .glassCard()
    }
}

#Preview {
    RootView()
        .modelContainer(for: [
            RunProtocol.self, ProtocolBlock.self, ProtocolStep.self,
            OperatorProfile.self, RunLog.self
        ], inMemory: true)
}
