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

    private var status: String {
        if protocols.isEmpty { return "IDLE" }
        if protocols.contains(where: { $0.state == .synced }) { return "SYNCED" }
        return "\(protocols.count) DRAFT"
    }

    var body: some View {
        NavigationStack {
            ScreenScaffold(title: "PROTOCOLS", status: status) {
                VStack(spacing: Spacing.l) {
                    PrimaryActionButton(title: "COMPILE FROM TEMPLATE") { showingLibrary = true }

                    if protocols.isEmpty {
                        EmptyStateView(
                            headline: "NO PROTOCOL COMPILED",
                            metric: "0 PAYLOADS",
                            note: "Compile un protocole depuis un template pour commencer."
                        )
                    } else {
                        ForEach(protocols) { proto in
                            NavigationLink(value: proto) {
                                ProtocolCell(proto: proto, vma: vma)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
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
