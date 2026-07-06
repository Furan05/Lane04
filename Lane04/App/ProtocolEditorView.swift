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

struct ProtocolEditorView: View {
    @Bindable var proto: RunProtocol
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(InjectionController.self) private var injection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(SettingsKey.txMode) private var txMode = TXMode.ritual.rawValue
    @Query private var profiles: [OperatorProfile]
    private var vma: Double { profiles.first?.vma ?? 16.0 }

    @State private var editingStep: ProtocolStep?

    private var orderedBlocks: [ProtocolBlock] {
        proto.blocks.sorted { $0.order < $1.order }
    }

    var body: some View {
        ZStack {
            ScreenScaffold(title: "PROTOCOL", status: injection.status(for: proto), onBack: { dismiss() }) {
                VStack(spacing: Spacing.l) {
                    consoleHeader
                    ForEach(orderedBlocks) { block in
                        blockCard(block)
                    }
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
                summaryTile("CHARGE", "\(load)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .glassCard()
    }

    /// Charge = index durée × intensité (min × %VMA/100), tabulaire.
    private var load: Int {
        var total = 0.0
        for b in proto.blocks {
            for s in b.steps where s.goalKind == .time {
                total += Double(b.iterations) * (s.goalValue / 60) * (s.percentVMA / 100)
            }
            for s in b.steps where s.goalKind == .distance {
                let v = VMACalculator.speed(vma: vma, percent: s.percentVMA)
                let minutes = v > 0 ? (s.goalValue / v) / 60 : 0
                total += Double(b.iterations) * minutes * (s.percentVMA / 100)
            }
        }
        return Int(total.rounded())
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

    // MARK: Hero — 4 états (§09) pilotés par le contrôleur d'injection

    @ViewBuilder
    private var heroInject: some View {
        let active = injection.activeID == proto.persistentModelID
        let phase: InjectionController.Phase = active ? injection.phase : .idle
        VStack(spacing: Spacing.s) {
            switch phase {
            case .idle, .delivered:
                targetLine
                if case .delivered = phase {
                    deliveredBar
                } else {
                    PrimaryActionButton(title: "INJECT PAYLOAD") { startInjection() }
                }
            case .arming, .transferring, .flashing:
                targetLine
                InjectingBar(progress: currentProgress, label: "INJECTING \(Int(currentProgress * 100))%")
            case .fault(let reason):
                FaultBanner(reason: reason)
                Button {
                    injection.acknowledgeFault()
                    startInjection()
                } label: {
                    Text("RETRY INJECT")
                        .font(.button).foregroundStyle(Color.ember)
                        .frame(maxWidth: .infinity, minHeight: Touch.min).padding(.vertical, Spacing.m)
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.button)
                                .strokeBorder(Color.ember, lineWidth: 1.5)
                        }
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(.top, Spacing.m)
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
        Text("PAYLOAD DELIVERED")
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

// MARK: - Bannière de faute (clignotement 1.2 s, cause nommée — écran 11)

private struct FaultBanner: View {
    let reason: String
    @State private var blink = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("[SYNC FAULT]")
                .font(.label).tracking(1.5).foregroundStyle(Color.ember)
                .opacity(blink ? 0.3 : 1)
            Text(reason)
                .font(.data).foregroundStyle(Color.laneWhite).metricDigits()
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card)
                .strokeBorder(Color.ember.opacity(0.5), lineWidth: 1)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { blink = true }
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
