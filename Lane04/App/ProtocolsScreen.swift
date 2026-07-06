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

    // Les protocoles de l'utilisateur (pas les templates).
    @Query(filter: #Predicate<RunProtocol> { !$0.isTemplate }, sort: \RunProtocol.createdAt, order: .reverse)
    private var protocols: [RunProtocol]

    @Query private var profiles: [OperatorProfile]
    private var vma: Double { profiles.first?.vma ?? 16.0 }

    @State private var showingLibrary = false
    @State private var pendingDelete: RunProtocol?   // confirmation pour un [SYNCED]

    private var status: String {
        if protocols.isEmpty { return "IDLE" }
        if protocols.contains(where: { $0.state == .synced }) { return "SYNCED" }
        return "\(protocols.count) DRAFT"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.void.ignoresSafeArea()
                VStack(alignment: .leading, spacing: Spacing.l) {
                    header
                    PrimaryActionButton(title: "COMPILE FROM TEMPLATE") { showingLibrary = true }

                    if protocols.isEmpty {
                        EmptyStateView(
                            headline: "NO PROTOCOL COMPILED",
                            metric: "0 PAYLOADS",
                            note: "Compile un protocole depuis un template pour commencer."
                        )
                        Spacer()
                    } else {
                        protocolList
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
            }
        }
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

    var body: some View {
        ZStack {
            Color.void.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.l) {
                HStack {
                    Text("COMPILE FROM TEMPLATE")
                        .font(.titleBrand)
                        .foregroundStyle(Color.laneWhite)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(Color.steel)
                            .frame(minWidth: Touch.min, minHeight: Touch.min)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Grid.margin)
                .padding(.top, Spacing.xl)

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.xl) {
                        ForEach(Discipline.allCases) { discipline in
                            let group = templates.filter { $0.discipline == discipline }
                            if !group.isEmpty {
                                VStack(alignment: .leading, spacing: Spacing.s) {
                                    TagBadge(discipline: discipline)
                                    ForEach(group) { template in
                                        Button {
                                            onPick(template)
                                            dismiss()
                                        } label: {
                                            TemplateRow(template: template, vma: vma)
                                        }
                                        .buttonStyle(PressableStyle())
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Grid.margin)
                    .padding(.bottom, Grid.safeBottom)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .presentationBackground(Color.void)
        .presentationCornerRadius(Radius.sheet)
    }
}

private struct TemplateRow: View {
    let template: RunProtocol
    let vma: Double

    var body: some View {
        let totals = WorkoutBuilder.totals(for: template, vma: vma)
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(template.name)
                    .font(.bodyBrand)
                    .foregroundStyle(Color.laneWhite)
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
