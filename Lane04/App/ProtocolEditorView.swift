//
//  ProtocolEditorView.swift
//  Lane04
//
//  Écran-cœur (§09) — édition d'un protocole [DRAFT]. Header console, cartes
//  d'intervalles (dualité effort EMBER / récup CRYO), stepper répétitions,
//  allure éditable via la sheet §12. Le hero INJECT (chorégraphie) arrive en 3b.
//

import SwiftUI
import SwiftData
import UIKit

struct ProtocolEditorView: View {
    @Bindable var proto: RunProtocol
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(InjectionController.self) private var injection
    @Environment(LinkController.self) private var link
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @AppStorage(SettingsKey.txMode) private var txMode = TXMode.ritual.rawValue
    @Query private var profiles: [OperatorProfile]
    private var vma: Double { profiles.first?.vma ?? 16.0 }

    @State private var editingStep: ProtocolStep?
    @State private var showingPairing = false

    private var orderedBlocks: [ProtocolBlock] {
        proto.blocks.sorted { $0.order < $1.order }
    }

    var body: some View {
        ZStack {
            ScreenScaffold(title: "PROTOCOL",
                           status: link.isReady ? injection.status(for: proto) : link.bracket,
                           onBack: { dismiss() }) {
                VStack(spacing: Spacing.l) {
                    consoleHeader
                    ForEach(orderedBlocks) { block in
                        blockCard(block)
                    }
                    // Sans liaison : cellules à 45 %, hero éteint (écran 09).
                    .opacity(link.isReady ? 1 : 0.45)
                    heroInject
                }
            }
            // FLASH — l'obturateur du chronométreur (jamais avant la vérité).
            if isFlashing {
                Color.white.ignoresSafeArea().transition(.opacity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $editingStep) { step in
            PaceSheet(step: step, vma: vma)
        }
        .sheet(isPresented: $showingPairing) {
            NavigationStack { PairingView() }
        }
    }

    private var isFlashing: Bool {
        injection.activeID == proto.persistentModelID && injection.phase == .flashing
    }

    // MARK: Header console (nom + résumé recalculé)

    private var consoleHeader: some View {
        let totals = WorkoutBuilder.totals(for: proto, vma: vma)
        return VStack(alignment: .leading, spacing: Spacing.m) {
            TagBadge(discipline: proto.discipline)
            Text(proto.name).font(.titleBrand).foregroundStyle(Color.laneWhite)
            HStack(spacing: 0) {
                summaryTile("DISTANCE", Format.distanceKM(totals.distance))
                summaryTile("DURÉE", Format.duration(totals.duration))
            }
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

    // MARK: Carte de bloc

    @ViewBuilder
    private func blockCard(_ block: ProtocolBlock) -> some View {
        let isWrapper = block.iterations == 1 && block.steps.count == 1
            && (block.steps.first?.role == .warmup || block.steps.first?.role == .cooldown)
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text(block.title).font(.label).tracking(1.5).foregroundStyle(Color.steel)
                Spacer()
                if !isWrapper {
                    repsStepper(block)
                }
            }
            ForEach(block.steps.sorted { $0.order < $1.order }) { step in
                stepRow(step)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .glassCard()
    }

    private func repsStepper(_ block: ProtocolBlock) -> some View {
        HStack(spacing: Spacing.s) {
            stepButton("minus") { if block.iterations > 1 { block.iterations -= 1 } }
            Text("\(block.iterations)×").font(.data).foregroundStyle(Color.laneWhite)
                .metricDigits().contentTransition(.numericText())
                .frame(minWidth: 44)
            stepButton("plus") { if block.iterations < 20 { block.iterations += 1 } }
        }
    }

    private func stepButton(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button {
            Haptic.selection()
            withAnimation(.master(Duration.micro)) { action() }
        } label: {
            Image(systemName: symbol).font(.subheadline).foregroundStyle(Color.laneWhite)
                .frame(width: Touch.min, height: Touch.min)
                .background(Color.carbon2, in: RoundedRectangle(cornerRadius: Radius.control))
        }
        .buttonStyle(.plain)
    }

    // MARK: Ligne de pas (dualité effort/récup)

    @ViewBuilder
    private func stepRow(_ step: ProtocolStep) -> some View {
        let isEffort = step.role.isEffort
        HStack(spacing: Spacing.m) {
            IntervalRail(effort: isEffort)
            Text(goalLabel(step))
                .font(.data).foregroundStyle(isEffort ? Color.laneWhite : Color.steel).metricDigits()
            Spacer()
            if isEffort {
                Button { editingStep = step } label: {
                    HStack(spacing: Spacing.xs) {
                        Text("\(VMACalculator.paceString(vma: vma, percent: step.percentVMA)) /KM")
                            .font(.data).foregroundStyle(Color.ember).metricDigits()
                        Image(systemName: "slider.horizontal.3").font(.footnote).foregroundStyle(Color.ember)
                    }
                    .frame(minHeight: Touch.min)
                }
                .buttonStyle(.plain)
            } else {
                Text("\(VMACalculator.paceString(vma: vma, percent: step.percentVMA)) /KM")
                    .font(.data).foregroundStyle(Color.steel).metricDigits()
            }
        }
        .frame(minHeight: Touch.min)
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.s)
        .background(isEffort ? Color.ember.opacity(0.06) : Color.clear,
                    in: RoundedRectangle(cornerRadius: Radius.control))
    }

    private func goalLabel(_ step: ProtocolStep) -> String {
        switch step.goalKind {
        case .time:
            let s = Int(step.goalValue)
            return s < 60 ? "\(s) S" : "\(s / 60) MIN"
        case .distance:
            return step.goalValue < 1000 ? "\(Int(step.goalValue)) M"
                                         : String(format: "%.1f KM", step.goalValue / 1000)
        }
    }

    // MARK: Hero — liaison d'abord (09/10), puis injection 4 états (§09)

    @ViewBuilder
    private var heroInject: some View {
        VStack(spacing: Spacing.s) {
            if link.isReady {
                injectionHero
            } else {
                linkFault // hero éteint : jamais cliquable sans liaison
            }
        }
        .padding(.top, Spacing.m)
    }

    /// Écrans 09 (NO LINK) / 10 (ACCESS DENIED) — bannière contour, CTA de recours
    /// en contour (l'aplat reste réservé à l'injection).
    @ViewBuilder
    private var linkFault: some View {
        switch link.status {
        case .healthKitDenied:
            FaultCard(status: "ACCESS DENIED", cause: "HEALTHKIT REQUIRED",
                      detail: "L'écriture des séances est bloquée. Autorise LANE 04 dans Réglages.",
                      ctaTitle: "OPEN SETTINGS", action: openSettings)
        default:
            FaultCard(status: "NO LINK", cause: "WATCH UNPAIRED",
                      detail: "Aucune liaison montre. Ouvre l'appairage pour injecter.",
                      ctaTitle: "OPEN PAIRING", action: { showingPairing = true })
        }
    }

    @ViewBuilder
    private var injectionHero: some View {
        let active = injection.activeID == proto.persistentModelID
        let phase: InjectionController.Phase = active ? injection.phase : .idle
        switch phase {
        case .idle, .delivered:
            targetLine
            if case .delivered = phase {
                deliveredBar
            } else {
                PrimaryActionButton(title: "INJECT TRAINING") { startInjection() }
            }
        case .arming, .transferring, .flashing:
            targetLine
            InjectingBar(progress: currentProgress, label: "INJECTING \(Int(currentProgress * 100))%")
        case .fault(let reason):
            // Écran 11 — SYNC FAULT : cause nommée, une seule action.
            FaultCard(status: "SYNC FAULT", cause: reason,
                      ctaTitle: "RETRY INJECT", blinking: true,
                      action: { injection.acknowledgeFault(); startInjection() })
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }

    private var targetLine: some View {
        Text("TARGET: WATCH — [PAIRED]")
            .font(.label).tracking(1.5).foregroundStyle(Color.steelHi)
    }

    private var currentProgress: Double {
        if case .transferring(let p) = injection.phase { return p }
        if case .flashing = injection.phase { return 1 }
        return 0
    }

    private var deliveredBar: some View {
        Text("TRAINING DELIVERED")
            .font(.button).foregroundStyle(Color.void)
            .frame(maxWidth: .infinity, minHeight: Touch.min).padding(.vertical, Spacing.m)
            .background(Color.cryo, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
    }

    private func startInjection() {
        let count = UserDefaults.standard.integer(forKey: SettingsKey.successfulInjections)
        let forced = txMode == TXMode.fast.rawValue
        let mode: TXMode = (forced || count >= 9) ? .fast : .ritual // 10ᵉ injection → FAST
        Task {
            await injection.inject(proto: proto, vma: vma, mode: mode,
                                   reduceMotion: reduceMotion, context: modelContext)
        }
    }
}

// MARK: - Hero « INJECTING » (faisceau = progression, % qui respire)

private struct InjectingBar: View {
    let progress: Double
    let label: String
    @State private var breathe = false

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: Radius.button).fill(Color.ember.opacity(0.3))
            GeometryReader { g in
                RoundedRectangle(cornerRadius: Radius.button)
                    .fill(Color.ember)
                    .frame(width: max(0, g.size.width * progress))
                    .animation(.linear(duration: 0.05), value: progress)
            }
            Text(label)
                .font(.button).foregroundStyle(Color.void).metricDigits()
                .frame(maxWidth: .infinity)
                .opacity(breathe ? 0.6 : 1)
        }
        .frame(height: Touch.min + Spacing.m * 2)
        .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { breathe = true }
        }
    }
}

/// Rail vertical d'intervalle : effort = EMBER plein, récup = CRYO pointillé (§09).
private struct IntervalRail: View {
    let effort: Bool
    var body: some View {
        VLine()
            .stroke(effort ? Color.ember : Color.cryo,
                    style: StrokeStyle(lineWidth: effort ? 3 : 2,
                                       dash: effort ? [] : [3, 3]))
            .frame(width: 3, height: 28)
    }
}

private struct VLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return p
    }
}
