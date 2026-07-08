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

    /// Label VoiceOver en français clair — la typo mono anglaise est le symbole
    /// visuel, mais l'annonce reste lisible (la perte de la TabView native ne
    /// doit rien coûter à l'accessibilité).
    var voiceOverLabel: String {
        switch self {
        case .protocols: return "Protocoles"
        case .logs:      return "Journal"
        case .console:   return "Console"
        }
    }
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
            // Bascule d'onglet en Duration.micro : opacity only (transform interdit
            // sur un plein écran ; Reduce Motion obtient déjà un simple fondu).
            .id(router.tab)
            .transition(.opacity)

            TabBar(selection: $router.tab)
        }
        .environment(router)
        .environment(injection)
        .environment(link)
        .preferredColorScheme(.dark)
        .task {
            Seeder.seedIfNeeded(modelContext)
            Seeder.ensureOperatorProfile(modelContext)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-uitest-simulate-tx") {
                injection.simulateTransmittingForUITest()
            }
            #endif
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

// MARK: - Bottom bar (custom LANE 04 — pictogrammes seuls, §06/§09)

/// Barre de navigation basse. **Pictogrammes seuls, aucun texte** (revirement —
/// voir docs/session-notes.md : « le mot est le symbole » reste la règle des
/// STATUTS, pas de la nav). Glyphes custom `NavGlyphView` en contour. Matériau
/// Liquid Glass sur VOID, hairline supérieure comme seule séparation. États :
/// ACTIVE (trait blanc + micro-barre indicatrice — clin d'œil QUAD, jamais
/// EMBER), INACTIVE (steel), FAULT (glyphe CONSOLE en trait EMBER quand une
/// faute liaison est active), DISABLED-TX (barre à 40 %, taps ignorés).
private struct TabBar: View {
    @Binding var selection: Tab
    @Environment(InjectionController.self) private var injection
    @Environment(LinkController.self) private var link
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isTX: Bool { injection.isTransmitting }

    private var switchAnimation: Animation {
        // Reduce Motion : fondu simple, zéro translation. Sinon courbe maîtresse.
        reduceMotion ? .easeInOut(duration: Duration.reduceMotion)
                     : .master(Duration.micro)
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                tabButton(tab)
            }
        }
        // Barre FLOTTANTE (style Instagram récent) : pilule Liquid Glass détachée
        // des bords, posée AU-DESSUS de l'home indicator avec un écart. Cible
        // tactile 44 pt conservée.
        .padding(.vertical, Spacing.m)
        .padding(.horizontal, Spacing.l)
        .background {
            // Liquid Glass (Surface.navBlur ≈ 20) dans la pilule + hairline sur
            // TOUT le contour (la séparation entoure la barre flottante).
            // ZÉRO ombre portée — la profondeur se lit par la luminance du verre
            // sur VOID + le hairline (règle n°8, jamais d'ombre diffuse).
            RoundedRectangle(cornerRadius: Radius.nav, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.nav, style: .continuous)
                        .strokeBorder(Surface.hairline, lineWidth: 1)
                }
        }
        // Marges qui font « flotter » : latérales (détachée des bords) + un écart
        // sous la barre, au-dessus de l'home indicator (safe area respectée).
        .padding(.horizontal, Grid.margin)
        .padding(.bottom, Spacing.xs)
        // DISABLED — TX : la barre entière chute à 40 % et ignore les taps.
        .opacity(isTX ? 0.4 : 1)
        .allowsHitTesting(!isTX)
        .animation(switchAnimation, value: isTX)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isTabBar)
    }

    @ViewBuilder
    private func tabButton(_ tab: Tab) -> some View {
        let isActive = tab == selection
        // FAULT : le mot CONSOLE porte la teinte EMBER (signal en texte) quand une
        // faute liaison est active — jamais un aplat, l'accent reste au hero.
        let isFault = tab == .console && link.hasFault
        let tint: Color = isFault ? .ember
                        : (isActive ? .laneWhite : .steel)

        Button {
            guard tab != selection else { return }
            Haptic.selection()
            withAnimation(switchAnimation) { selection = tab }
        } label: {
            NavGlyphView(tab: tab)
                .foregroundStyle(tint)
                // Micro-barre indicatrice sous le glyphe : 2 pt, largeur du
                // glyphe, toujours blanche (structure QUAD), même en faute —
                // l'EMBER vit dans le trait du glyphe, pas dans l'indicateur.
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.laneWhite)
                        .frame(height: 2)
                        .offset(y: 7)
                        .opacity(isActive ? 1 : 0)
                        .scaleEffect(x: reduceMotion || isActive ? 1 : 0.5,
                                     anchor: .center)
                }
                .frame(maxWidth: .infinity, minHeight: Touch.min)
                .contentShape(Rectangle())      // zone de tap généreuse ≥ 44 pt
        }
        .buttonStyle(.plain)
        // Identifiant = le mot brut (tests + parité avec l'ancienne TabView) ;
        // le label VoiceOver reste en français clair.
        .accessibilityIdentifier(tab.rawValue)
        .accessibilityLabel(tab.voiceOverLabel)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
        .accessibilityValue(isFault ? "Défaut système" : "")
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
