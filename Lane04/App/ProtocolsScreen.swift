//
//  ProtocolsScreen.swift
//  Lane04
//
//  Écran 03 — ACCUEIL / PROTOCOLS. Liste des protocoles compilés (tags thermiques),
//  compilation en un geste via la bibliothèque de templates.
//

import SwiftUI
import SwiftData

struct ProtocolsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    // Les protocoles de l'utilisateur (pas les templates).
    @Query(filter: #Predicate<RunProtocol> { !$0.isTemplate }, sort: \RunProtocol.createdAt, order: .reverse)
    private var protocols: [RunProtocol]

    @Query private var profiles: [OperatorProfile]
    private var vma: Double { profiles.first?.vma ?? 16.0 }

    @State private var showingLibrary = false
    @State private var pendingDelete: RunProtocol?   // confirmation pour un [SYNCED]
    @State private var deletionBlocked = false
    // Date de planification appliquée à la création (COMPILE / NEW) — défaut : aujourd'hui.
    @State private var planDate = Calendar.current.startOfDay(for: Date())
    @State private var showingDatePicker = false

    private var status: String {
        if protocols.isEmpty { return "NO TRAINING" }   // repos explicite (« le zéro est une donnée »)
        if protocols.contains(where: { $0.state == .synced }) { return "SYNCED" }
        return "\(protocols.count) DRAFT"
    }

    var body: some View {
        @Bindable var router = router
        return NavigationStack(path: $router.protocolsPath) {
            ZStack {
                Color.void.ignoresSafeArea()
                VStack(alignment: .leading, spacing: Spacing.l) {
                    header

                    if protocols.isEmpty {
                        EmptyStateView(
                            headline: "NO PROTOCOL COMPILED",
                            metric: "0 TRAININGS",
                            note: "Compile un protocole depuis un template pour commencer."
                        )
                        Spacer()
                    } else {
                        protocolList
                    }

                    // CTA ancrée sous les trainings : le geste de compilation est
                    // la conclusion de la lecture de la liste, pas son préambule.
                    // Aplat EMBER unique (règle n°1) ; la création vierge est un
                    // recours EN CONTOUR (ne dépense pas l'accent).
                    // On choisit d'abord QUAND (date, défaut aujourd'hui), puis COMMENT
                    // (template / vierge) : la séance créée est planifiée au CALENDAR.
                    planDateSelector
                    PrimaryActionButton(title: "COMPILE FROM TEMPLATE") { showingLibrary = true }
                    OutlineActionButton(title: "NEW FROM SCRATCH", dashed: true) {
                        let draft = ProtocolActions.createBlank(in: modelContext)
                        PlanActions.plan(draft, on: planDate, in: modelContext)
                        router.openEditor(draft)
                    }
                }
                .padding(.horizontal, Grid.margin)
                .padding(.top, Grid.safeTop)
                .padding(.bottom, Grid.safeBottom + Touch.min)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: RunProtocol.self) { proto in
                ProtocolEditorView(proto: proto)
            }
        }
        .sheet(isPresented: $showingLibrary) {
            TemplateLibrarySheet(vma: vma) { template in
                let draft = Seeder.clone(template)
                modelContext.insert(draft)
                try? modelContext.save()
                PlanActions.plan(draft, on: planDate, in: modelContext)  // planifie à la date choisie
                showingLibrary = false   // ferme la sheet (y compris depuis un dossier)
            }
        }
        .sheet(isPresented: $showingDatePicker) { planDatePickerSheet }
        .alert("DELETE PROTOCOL", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("DELETE", role: .destructive) {
                if let proto = pendingDelete { ProtocolActions.delete(proto, in: modelContext) }
                pendingDelete = nil
            }
            Button("CANCEL", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("[SYNCED] sur la montre. Confirmer ?")
        }
        .alert("TRAINING SCHEDULED", isPresented: $deletionBlocked) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Ce protocole possède une séance déjà programmée sur la montre. Il reste disponible pour éviter une séance orpheline.")
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("PROTOCOLS")
                .font(.titleBrand).foregroundStyle(Color.laneWhite)
                .lineLimit(1).minimumScaleFactor(0.6)
            Spacer(minLength: Spacing.s)
            StatusBadge(status).fixedSize()
        }
    }

    // MARK: - Date de planification (défaut aujourd'hui)

    private var isPlanToday: Bool { Calendar.current.isDateInToday(planDate) }

    private var planDateSelector: some View {
        HStack(spacing: Spacing.s) {
            Text("PLANIFIER").font(.label).tracking(1.5).foregroundStyle(Color.steelHi)
            Spacer()
            dateNudge("chevron.left", "Jour précédent") { shiftPlanDate(-1) }
                .disabled(isPlanToday)                 // jamais dans le passé
                .opacity(isPlanToday ? 0.3 : 1)
            Button {
                Haptic.selection()
                showingDatePicker = true
            } label: {
                Text(Self.planLabel(planDate))
                    .font(.data).foregroundStyle(Color.laneWhite).metricDigits()
                    .frame(minWidth: 132, minHeight: Touch.min)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choisir la date de planification, \(Self.a11yDate(planDate))")
            dateNudge("chevron.right", "Jour suivant") { shiftPlanDate(1) }
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.xs)
        .glassCard()
    }

    private func dateNudge(_ symbol: String, _ a11y: String, _ action: @escaping () -> Void) -> some View {
        Button {
            Haptic.selection()
            withAnimation(.master(Duration.micro)) { action() }
        } label: {
            Image(systemName: symbol).font(.subheadline).foregroundStyle(Color.steel)
                .frame(width: Touch.min, height: Touch.min)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(a11y)
    }

    private func shiftPlanDate(_ delta: Int) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if let nd = cal.date(byAdding: .day, value: delta, to: planDate), nd >= today {
            planDate = cal.startOfDay(for: nd)
        }
    }

    // Sélecteur graphique pour sauter à une date lointaine (aujourd'hui → futur).
    private var planDatePickerSheet: some View {
        ZStack {
            Color.void.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.l) {
                Text("PLANIFIER LE").font(.label).tracking(1.5).foregroundStyle(Color.steelHi)
                DatePicker("", selection: Binding(
                    get: { planDate },
                    set: { planDate = Calendar.current.startOfDay(for: $0) }
                ), in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(.ember)
                    .environment(\.locale, Locale(identifier: "fr_FR"))
                PrimaryActionButton(title: "OK") { showingDatePicker = false }
            }
            .padding(Grid.margin)
        }
        .presentationBackground(Color.void)
        .presentationCornerRadius(Radius.sheet)
        .presentationDetents([.medium, .large])
    }

    private static let planFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR"); f.dateFormat = "EEE d MMM"
        return f
    }()
    private static func planLabel(_ date: Date) -> String {
        Calendar.current.isDateInToday(date) ? "AUJOURD'HUI" : planFormatter.string(from: date).uppercased()
    }
    private static let a11yFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR"); f.dateFormat = "EEEE d MMMM"
        return f
    }()
    private static func a11yDate(_ date: Date) -> String { a11yFormatter.string(from: date) }

    // Liste en List pour les actions de swipe (grammaire système).
    private var protocolList: some View {
        List {
            ForEach(protocols) { proto in
                NavigationLink(value: proto) {
                    ProtocolCell(proto: proto, vma: vma)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Spacing.xs, leading: 0, bottom: Spacing.xs, trailing: 0))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    deleteButton(proto)
                    duplicateButton(proto)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    deleteButton(proto)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }

    // DELETE — aplat EMBER (action destructive = signal chaud). Confirme si [SYNCED].
    private func deleteButton(_ proto: RunProtocol) -> some View {
        Button(role: .destructive) {
            guard ProtocolActions.canDelete(proto) else {
                deletionBlocked = true
                return
            }
            if proto.state == .synced {
                pendingDelete = proto
            } else {
                ProtocolActions.delete(proto, in: modelContext)
            }
        } label: {
            Label("DELETE", systemImage: "trash")
        }
        .tint(.ember)
        .accessibilityLabel("Supprimer le protocole")
    }

    // DUPLICATE — neutre (pas d'aplat d'accent), geste d'itération non destructif.
    private func duplicateButton(_ proto: RunProtocol) -> some View {
        Button {
            ProtocolActions.duplicate(proto, in: modelContext)
        } label: {
            Label("DUPLICATE", systemImage: "plus.square.on.square")
        }
        .tint(.carbon2)
        .accessibilityLabel("Dupliquer le protocole")
    }
}

// MARK: - Cellule de protocole

struct ProtocolCell: View {
    let proto: RunProtocol
    let vma: Double

    var body: some View {
        let totals = WorkoutBuilder.totals(for: proto, vma: vma)
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                TagBadge(discipline: proto.discipline)
                if proto.isTest { StatusBadge("TEST") }
                Spacer()
                StateBadge(state: proto.state)
            }
            Text(proto.name)
                .font(.button)
                .foregroundStyle(Color.laneWhite)
            Text("\(Format.distanceKM(totals.distance)) — \(Format.duration(totals.duration))")
                .font(.data)
                .foregroundStyle(Color.steel)
                .metricDigits()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .glassCard()
    }
}

// MARK: - Bibliothèque de templates (sheet)

struct TemplateLibrarySheet: View {
    let vma: Double
    let onPick: (RunProtocol) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<RunProtocol> { $0.isTemplate }, sort: \RunProtocol.name)
    private var templates: [RunProtocol]

    // Dossiers = filières peuplées (dans l'ordre thermique EMBER→CRYO de l'enum).
    private var populatedStyles: [Discipline] {
        Discipline.allCases.filter { d in templates.contains { $0.discipline == d } }
    }
    private func group(_ d: Discipline) -> [RunProtocol] {
        templates.filter { $0.discipline == d }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.void.ignoresSafeArea()
                VStack(alignment: .leading, spacing: Spacing.l) {
                    HStack {
                        Text("COMPILE FROM TEMPLATE")
                            .font(.titleBrand)
                            .foregroundStyle(Color.laneWhite)
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.headline)
                                .foregroundStyle(Color.steel)
                                .frame(minWidth: Touch.min, minHeight: Touch.min)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Fermer")
                    }
                    .padding(.horizontal, Grid.margin)
                    .padding(.top, Spacing.xl)

                    // Niveau 1 : les dossiers de style. On choisit une filière avant
                    // de voir ses templates (au lieu d'une liste à plat).
                    ScrollView {
                        VStack(spacing: Spacing.m) {
                            ForEach(populatedStyles) { d in
                                NavigationLink(value: d) {
                                    StyleFolderCard(discipline: d, count: group(d).count)
                                }
                                .buttonStyle(PressableStyle())
                                .accessibilityLabel("Style \(d.rawValue), \(group(d).count) protocoles")
                            }
                        }
                        .padding(.horizontal, Grid.margin)
                        .padding(.bottom, Grid.safeBottom)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            // Niveau 2 : les templates du style choisi.
            .navigationDestination(for: Discipline.self) { d in
                TemplateFolderView(discipline: d, templates: group(d), vma: vma, onPick: onPick)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationBackground(Color.void)
        .presentationCornerRadius(Radius.sheet)
    }
}

// MARK: - Dossier de style (niveau 1)

/// Carte-dossier d'une filière : tag thermique + descripteur FR + compte. Le tag
/// (contour teinté) porte l'identité ; aucun aplat (l'accent reste au hero PROTOCOLS).
private struct StyleFolderCard: View {
    let discipline: Discipline
    let count: Int

    var body: some View {
        HStack(spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                TagBadge(discipline: discipline)
                Text(discipline.subtitle).font(.bodyBrand).foregroundStyle(Color.steel)
            }
            Spacer()
            Text("\(count)").font(.data).foregroundStyle(Color.laneWhite).metricDigits()
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Color.steel)
        }
        .frame(maxWidth: .infinity, minHeight: Touch.min, alignment: .leading)
        .padding(Spacing.l)
        .glassCard()
    }
}

// MARK: - Contenu d'un dossier de style (niveau 2)

private struct TemplateFolderView: View {
    let discipline: Discipline
    let templates: [RunProtocol]
    let vma: Double
    let onPick: (RunProtocol) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.void.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.l) {
                HStack(spacing: Spacing.m) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3).foregroundStyle(Color.steel)
                            .frame(minWidth: Touch.min, minHeight: Touch.min, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Retour aux styles")
                    TagBadge(discipline: discipline)
                    Text(discipline.subtitle).font(.bodyBrand).foregroundStyle(Color.steel)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Spacer()
                }
                .padding(.horizontal, Grid.margin)
                .padding(.top, Spacing.xl)

                ScrollView {
                    VStack(spacing: Spacing.s) {
                        ForEach(templates) { template in
                            Button { onPick(template) } label: {
                                TemplateRow(template: template, vma: vma)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    .padding(.horizontal, Grid.margin)
                    .padding(.bottom, Grid.safeBottom)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct TemplateRow: View {
    let template: RunProtocol
    let vma: Double

    var body: some View {
        let totals = WorkoutBuilder.totals(for: template, vma: vma)
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.s) {
                    Text(template.name)
                        .font(.bodyBrand)
                        .foregroundStyle(Color.laneWhite)
                    if template.isTest { StatusBadge("TEST") }
                }
                Text("\(Format.distanceKM(totals.distance)) — \(Format.duration(totals.duration))")
                    .font(.data)
                    .foregroundStyle(Color.steel)
                    .metricDigits()
            }
            Spacer()
            Image(systemName: "plus")
                .font(.headline)
                .foregroundStyle(Color.ember)
        }
        .frame(maxWidth: .infinity, minHeight: Touch.min, alignment: .leading)
        .padding(Spacing.l)
        .glassCard()
    }
}
