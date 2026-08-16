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
    /// Mesurée, estimée ou jamais renseignée — la molette le mentionne discrètement.
    private var vmaProvenance: VMAProvenance { profiles.first?.provenance ?? .uncalibrated }

    @State private var editingStep: ProtocolStep?   // sheet d'allure (%VMA)
    @State private var editingGoal: ProtocolStep?   // sheet d'objectif (durée/distance)
    @State private var showingPairing = false
    @State private var showingSchedule = false      // sheet de date (SCHEDULE)
    @State private var pendingDate = Date()
    @State private var draggingStepID: UUID?        // pas saisi (éteint à 40 %)
    @State private var dropTargetID: UUID?          // pas survolé (hairline d'insertion)

    private var orderedBlocks: [ProtocolBlock] {
        proto.blocks.sorted { $0.order < $1.order }
    }

    /// Le protocole est en cours de construction/édition → affordances du builder
    /// (rename, tag, add/del/reorder blocs, add/del pas, objectif éditable).
    private var isDraft: Bool { proto.state == .draft }

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
                    // Sans liaison : cellules à 45 %, hero éteint (écran 09). MAIS
                    // un [DRAFT] se construit hors ligne → jamais dimmé pendant l'édition
                    // (la faute de liaison est portée par le hero, pas par le contenu).
                    .opacity(link.isReady || isDraft ? 1 : 0.45)
                    if isDraft {
                        OutlineActionButton(title: "+ AJOUTER UN BLOC") {
                            withAnimation(.master(Duration.standard)) {
                                _ = ProtocolActions.addWorkBlock(to: proto, in: modelContext)
                            }
                        }
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
            PaceSheet(step: step, vma: vma, provenance: vmaProvenance)
        }
        .sheet(item: $editingGoal) { step in
            StepGoalSheet(step: step)
        }
        .sheet(isPresented: $showingPairing) {
            NavigationStack { PairingView() }
        }
        .sheet(isPresented: $showingSchedule) { scheduleSheet }
    }

    private var isFlashing: Bool {
        injection.activeID == proto.persistentModelID && injection.phase == .flashing
    }

    // MARK: Header console (nom + résumé recalculé)

    private var consoleHeader: some View {
        let totals = WorkoutBuilder.totals(for: proto, vma: vma)
        return VStack(alignment: .leading, spacing: Spacing.m) {
            tagControl
            nameControl
            scheduleControl
            HStack(spacing: 0) {
                summaryTile("DISTANCE", Format.distanceKM(totals.distance))
                summaryTile("DURÉE", Format.duration(totals.duration))
                summaryTile("CHARGE", Format.load(WorkoutBuilder.trimp(for: proto, vma: vma)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .glassCard()
    }

    // MARK: SCHEDULE — la date de la séance (optionnelle)

    /// L'occurrence sur laquelle agit l'éditeur : la prochaine à venir, sinon la plus
    /// récente. Un protocole peut être planifié plusieurs jours (le calendrier reste
    /// la vue complète) — l'éditeur n'en pilote qu'une.
    private var editableSession: PlannedSession? {
        let now = Date()
        return proto.plans.filter { $0.date >= now }.min { $0.date < $1.date }
            ?? proto.plans.max { $0.date < $1.date }
    }

    private var scheduleValue: String {
        guard let session = editableSession else { return "NO DATE" }
        return Format.dateTime(session.date)
    }

    /// Contour neutre, valeur en mono tabulaire. Aucun aplat : l'unique accent de
    /// l'écran reste le hero INJECT (règle n°1).
    private var scheduleControl: some View {
        Button { presentSchedule() } label: {
            HStack(spacing: Spacing.s) {
                Text("SCHEDULE").font(.label).tracking(1.5).foregroundStyle(Color.steelHi)
                Spacer()
                Text(scheduleValue)
                    .font(.data).foregroundStyle(Color.laneWhite).metricDigits()
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Color.steel)
            }
            .frame(minHeight: Touch.min)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(editableSession == nil
                            ? "Aucune date planifiée, choisir une date"
                            : "Séance planifiée le \(scheduleValue), changer la date")
    }

    private func presentSchedule() {
        // Déjà sur la montre : la changer exige de parler à la montre (retrait).
        // Sans liaison, on envoie appairer plutôt que de promettre un déplacement.
        if let session = editableSession, session.state == .scheduled, !link.isReady {
            showingPairing = true
            return
        }
        pendingDate = editableSession?.date ?? Date()
        showingSchedule = true
    }

    /// `PLANNED` → simple déplacement local. `SCHEDULED` → retrait de la montre PUIS
    /// réinjection (`InjectionController.reschedule`), jamais un déplacement sec.
    private func applySchedule(_ day: Date) {
        guard let session = editableSession else {
            PlanActions.plan(proto, on: day, in: modelContext)
            return
        }
        if session.state == .scheduled {
            Task {
                await injection.reschedule(session: session, to: day, vma: vma,
                                           mode: TXMode(rawValue: txMode) ?? .ritual,
                                           reduceMotion: reduceMotion, context: modelContext)
            }
        } else {
            PlanActions.reschedule(session, to: day, in: modelContext)
        }
    }

    private var scheduleSheet: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text("SCHEDULE").font(.label).tracking(1.5).foregroundStyle(Color.steelHi)
            DatePicker("", selection: $pendingDate, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(Color.ember)
            OutlineActionButton(title: "COMMIT DATE") {
                applySchedule(pendingDate)
                showingSchedule = false
            }
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.carbon1.ignoresSafeArea())
    }

    // Tag [BRACKET] — éditable en [DRAFT] via un menu des 5 filières (nomenclature
    // stricte : jamais de 6e catégorie). Figé sinon.
    @ViewBuilder
    private var tagControl: some View {
        if isDraft {
            Menu {
                ForEach(Discipline.allCases) { d in
                    Button { proto.discipline = d } label: { Text(d.tag) }
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    TagBadge(discipline: proto.discipline)
                    Image(systemName: "chevron.down").font(.caption2).foregroundStyle(Color.steel)
                }
                .frame(minHeight: Touch.min)
            }
            .accessibilityLabel("Changer la filière")
        } else {
            TagBadge(discipline: proto.discipline)
        }
    }

    // Nom — éditable en [DRAFT] (champ mono expandé), figé sinon.
    @ViewBuilder
    private var nameControl: some View {
        if isDraft {
            TextField("NOM DU PROTOCOLE", text: $proto.name)
                .font(.titleBrand).foregroundStyle(Color.laneWhite)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .accessibilityLabel("Nom du protocole")
        } else {
            Text(proto.name).font(.titleBrand).foregroundStyle(Color.laneWhite)
        }
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
        let isWrapper = ProtocolActions.isWarmupWrapper(block) || ProtocolActions.isCooldownWrapper(block)
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(spacing: Spacing.s) {
                Text(block.title).font(.label).tracking(1.5).foregroundStyle(Color.steel)
                Spacer()
                if isDraft && !isWrapper {
                    blockMenu(block)
                }
                if !isWrapper {
                    repsStepper(block)
                }
            }
            ForEach(Array(block.steps.sorted { $0.order < $1.order }.enumerated()), id: \.element.id) { index, step in
                reorderableStepRow(step, at: index, in: block)
            }
            // Ajout de pas — réservé aux blocs d'effort d'un [DRAFT].
            if isDraft && !isWrapper {
                addStepRow(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .glassCard()
    }

    // Menu de bloc (⋯) : réordonner / supprimer. Réservé aux blocs d'effort d'un [DRAFT].
    private func blockMenu(_ block: ProtocolBlock) -> some View {
        Menu {
            Button { moveBlock(block, by: -1) } label: { Label("MONTER", systemImage: "arrow.up") }
            Button { moveBlock(block, by: 1) } label: { Label("DESCENDRE", systemImage: "arrow.down") }
            Button(role: .destructive) {
                Haptic.tick()
                withAnimation(.master(Duration.standard)) {
                    ProtocolActions.deleteBlock(block, from: proto, in: modelContext)
                }
            } label: { Label("SUPPRIMER LE BLOC", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis").font(.subheadline).foregroundStyle(Color.steel)
                .frame(width: Touch.min, height: Touch.min)
        }
        .accessibilityLabel("Options du bloc")
    }

    private func moveBlock(_ block: ProtocolBlock, by delta: Int) {
        Haptic.selection()
        withAnimation(.master(Duration.standard)) {
            ProtocolActions.moveBlock(block, by: delta, in: proto, context: modelContext)
        }
    }

    // Deux recours de structure : + EFFORT (EMBER texte) / + RÉCUP (CRYO texte).
    // Signaux thermiques en TEXTE (contour) — jamais un aplat, l'accent reste au hero.
    private func addStepRow(_ block: ProtocolBlock) -> some View {
        HStack(spacing: Spacing.s) {
            addStepButton("+ EFFORT", .ember, "Ajouter un pas d'effort") {
                _ = ProtocolActions.addStep(to: block, role: .work, in: modelContext)
            }
            addStepButton("+ RÉCUP", .cryo, "Ajouter un pas de récupération") {
                _ = ProtocolActions.addStep(to: block, role: .recovery, in: modelContext)
            }
        }
    }

    private func addStepButton(_ title: String, _ tint: Color, _ a11y: String,
                               _ action: @escaping () -> Void) -> some View {
        Button {
            Haptic.selection()
            withAnimation(.master(Duration.micro)) { action() }
        } label: {
            Text(title)
                .font(.label).tracking(1.5).foregroundStyle(tint)
                .frame(maxWidth: .infinity, minHeight: Touch.min)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.control).strokeBorder(Surface.hairline, lineWidth: 1)
                }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(a11y)
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

    // MARK: Glisser-déposer vertical des pas (intra-bloc)

    /// Un pas se saisit par appui long puis se glisse — aucun mode « Edit » à activer.
    /// Mécanisme SwiftUI natif (`draggable`/`dropDestination`) : l'auto-scroll aux
    /// bords et la mécanique du geste sont portés par le système.
    /// ⚠️ Le lift système dessine une ombre portée — **dérogation assumée à la règle 8**
    /// (décision operator) : elle appartient à la couche de drag de l'OS, le temps du
    /// geste seulement. Toute l'élévation que NOUS dessinons reste en paliers de
    /// luminance (CARBON-2) + hairline.
    @ViewBuilder
    private func reorderableStepRow(_ step: ProtocolStep, at index: Int, in block: ProtocolBlock) -> some View {
        let isDragged = draggingStepID == step.id
        VStack(spacing: 0) {
            // Position d'insertion — hairline blanc 2 pt, idiome QUAD (comme le jour
            // sélectionné du calendrier). Pas d'accent : l'EMBER reste au hero.
            Rectangle()
                .fill(Color.laneWhite)
                .frame(height: 2)
                .opacity(dropTargetID == step.id && !isDragged ? 1 : 0)
            stepRow(step, in: block)
                .opacity(isDragged ? 0.4 : 1)
                .animation(.master(Duration.micro), value: isDragged)
        }
        .modifier(StepDragModifier(
            enabled: canReorder(block),
            payload: step.id.uuidString,
            onGrab: {
                Haptic.arm()                       // PRISE — impact rigide
                draggingStepID = step.id
            },
            onTargeted: { targeted in
                dropTargetID = targeted ? step.id : nil
            },
            onDrop: { payload in
                drop(payload, at: index, in: block)
            },
            preview: { stepRow(step, in: block).frame(maxWidth: 320) }
        ))
    }

    /// Réordonner reste possible hors [DRAFT] — c'est ce qui rend l'invalidation d'une
    /// injection atteignable. Exclus : les templates du catalogue (jamais édités en
    /// place) et les blocs à un seul pas.
    private func canReorder(_ block: ProtocolBlock) -> Bool {
        !proto.isTemplate && block.steps.count > 1
    }

    private func drop(_ payload: String, at index: Int, in block: ProtocolBlock) -> Bool {
        defer { draggingStepID = nil; dropTargetID = nil }
        guard let id = UUID(uuidString: payload),
              let moved = block.steps.first(where: { $0.id == id })
        else { return false }

        let didMove = withAnimation(.master(Duration.standard)) {
            ProtocolActions.moveStep(moved, to: index, in: block, context: modelContext)
        }
        if didMove { Haptic.tick() }               // DÉPÔT — impact souple
        return didMove
    }

    // MARK: Ligne de pas (dualité effort/récup)

    @ViewBuilder
    private func stepRow(_ step: ProtocolStep, in block: ProtocolBlock) -> some View {
        let isEffort = step.role.isEffort
        HStack(spacing: Spacing.m) {
            IntervalRail(effort: isEffort)
            goalControl(step, isEffort: isEffort)
            Spacer()
            paceControl(step, isEffort: isEffort)
            // Supprimer le pas — [DRAFT] uniquement, et jamais le dernier pas d'un bloc.
            if isDraft && block.steps.count > 1 {
                Button {
                    Haptic.tick()
                    withAnimation(.master(Duration.micro)) {
                        ProtocolActions.deleteStep(step, from: block, in: modelContext)
                    }
                } label: {
                    Image(systemName: "xmark").font(.caption).foregroundStyle(Color.steel)
                        .frame(width: Touch.min, height: Touch.min)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Supprimer le pas")
            }
        }
        .frame(minHeight: Touch.min)
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.s)
        .background(isEffort ? Color.ember.opacity(0.06) : Color.clear,
                    in: RoundedRectangle(cornerRadius: Radius.control))
    }

    // Objectif (durée/distance) — éditable en [DRAFT] (sheet), figé sinon.
    @ViewBuilder
    private func goalControl(_ step: ProtocolStep, isEffort: Bool) -> some View {
        if isDraft {
            Button { editingGoal = step } label: {
                HStack(spacing: Spacing.xs) {
                    Text(goalLabel(step))
                        .font(.data).foregroundStyle(isEffort ? Color.laneWhite : Color.steel).metricDigits()
                    Image(systemName: "pencil").font(.caption2).foregroundStyle(Color.steel)
                }
                .frame(minHeight: Touch.min)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Modifier l'objectif du pas")
        } else {
            Text(goalLabel(step))
                .font(.data).foregroundStyle(isEffort ? Color.laneWhite : Color.steel).metricDigits()
        }
    }

    // Allure (%VMA) — éditable pour l'effort (sheet §12), lecture seule pour la récup.
    @ViewBuilder
    private func paceControl(_ step: ProtocolStep, isEffort: Bool) -> some View {
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
            .accessibilityLabel("Modifier l'allure de l'effort")
        } else {
            Text("\(VMACalculator.paceString(vma: vma, percent: step.percentVMA)) /KM")
                .font(.data).foregroundStyle(Color.steel).metricDigits()
        }
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
        case .deliveryWarning(let reason):
            // La montre a bien reçu la séance : aucune relance d'injection ici,
            // sinon on programmerait un doublon.
            FaultCard(status: "DELIVERED", cause: reason,
                      detail: "La séance est sur la montre, mais son journal local n'a pas été enregistré.",
                      ctaTitle: "DISMISS", action: injection.acknowledgeFault)
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

/// Glisser-déposer natif appliqué à une ligne de pas — ou rien du tout si le
/// réordonnancement n'a pas lieu d'être (template, bloc à un seul pas).
/// `payload` est `@autoclosure @escaping` côté SwiftUI : `onGrab` est donc évalué
/// au DÉBUT du geste, ce qui donne le retour haptique de prise sans gesture parallèle.
private struct StepDragModifier<Preview: View>: ViewModifier {
    let enabled: Bool
    let payload: String
    let onGrab: () -> Void
    let onTargeted: (Bool) -> Void
    let onDrop: (String) -> Bool
    @ViewBuilder let preview: () -> Preview

    func body(content: Content) -> some View {
        if enabled {
            content
                .draggable({ onGrab(); return payload }(), preview: preview)
                .dropDestination(for: String.self) { items, _ in
                    guard let first = items.first else { return false }
                    return onDrop(first)
                } isTargeted: { onTargeted($0) }
        } else {
            content
        }
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
