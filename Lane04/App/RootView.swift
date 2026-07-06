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
    // Navigation partagée (onglet + pile PROTOCOLS) : pilotable depuis OPERATOR.
    @State private var router = AppRouter()
    // Vit ici pour survivre à la disparition de l'éditeur (statut [TX…] persistant).
    @State private var injection = InjectionController()
    @State private var link = LinkController()
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    var body: some View {
        @Bindable var router = router
        return ZStack(alignment: .bottom) {
            Color.void.ignoresSafeArea()

            Group {
                switch router.tab {
                case .protocols: ProtocolsScreen()
                case .logs: LogsScreen()
                case .console: ConsoleScreen()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            TabBar(selection: $router.tab)
        }
        .environment(router)
        .environment(injection)
        .environment(link)
        .preferredColorScheme(.dark)
        .task {
            Seeder.seedIfNeeded(modelContext)
            Seeder.ensureOperatorProfile(modelContext)
            await link.refresh()
        }
        .fullScreenCover(isPresented: Binding(get: { !hasOnboarded }, set: { _ in })) {
            OnboardingView {
                hasOnboarded = true
                Task { await link.refresh() }
            }
            .environment(link)
        }
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
    var onBack: (() -> Void)? = nil
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color.void.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.l) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                    if let onBack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundStyle(Color.steel)
                                .frame(minWidth: Touch.min, minHeight: Touch.min, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                    Text(title)
                        .font(.titleBrand)
                        .foregroundStyle(Color.laneWhite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer(minLength: Spacing.s)
                    StatusBadge(status).fixedSize()
                }
                ScrollView {
                    content
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, Grid.safeBottom + Touch.min)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .padding(.horizontal, Grid.margin)
            .padding(.top, Grid.safeTop)
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

#Preview {
    RootView()
        .modelContainer(for: [
            RunProtocol.self, ProtocolBlock.self, ProtocolStep.self,
            OperatorProfile.self, RunLog.self
        ], inMemory: true)
}
