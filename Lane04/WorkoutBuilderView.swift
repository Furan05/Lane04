//
//  WorkoutBuilderView.swift
//  Lane04
//
//  Created by François.Dubois on 03/07/2026.
//

import SwiftUI
import WorkoutKit
import HealthKit

// MARK: - Design System « Lane 04 »

private extension Color {
    /// Cyan électrique — couleur d'accent signature de Lane 04. (#00FFFF)
    static let laneCyan = Color(red: 0, green: 1, blue: 1)
}

/// Cadre « Liquid Glass » : carte flottante translucide sur fond noir OLED,
/// soulignée d'une fine bordure cyan dont l'intensité dépend de la sélection.
private struct LiquidGlassCard<Content: View>: View {
    var selected: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.laneCyan.opacity(selected ? 0.9 : 0.3),
                                  lineWidth: selected ? 1.5 : 0.5)
            }
    }
}

// MARK: - Vue principale

struct WorkoutBuilderView: View {

    // Entrées de l'utilisateur.
    @State private var vma: Double = 16.0
    @State private var selectedCategory: SessionCategory = .endurance
    @State private var selectedSessionID: String = RunSession.sessions(in: .endurance).first!.id

    // État de l'injection vers l'Apple Watch.
    @State private var isInjecting = false
    @State private var statusMessage: String?

    private var selectedSession: RunSession {
        RunSession.catalog.first { $0.id == selectedSessionID } ?? RunSession.catalog[0]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    header
                    vmaCard
                    sessionPicker
                    detailCard
                    Spacer(minLength: 96)
                }
                .padding(20)
            }

            VStack(spacing: 8) {
                Spacer()
                if let statusMessage {
                    Text(statusMessage)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Color.laneCyan.opacity(0.85))
                        .transition(.opacity)
                }
                injectButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: En-tête

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("LANE 04")
                .font(.system(size: 40, weight: .black, design: .default))
                .foregroundStyle(.white)
            Text("WORKOUT BUILDER")
                .font(.system(.caption, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Color.laneCyan.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: Carte VMA

    private var vmaCard: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 18) {
                cardTitle("VMA")

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", vma))
                            .font(.system(size: 44, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                            .monospacedDigit()
                        Text("km/h")
                            .font(.system(.title3, design: .monospaced))
                            .foregroundStyle(Color.laneCyan.opacity(0.7))
                    }
                    Spacer()
                    Stepper("", value: $vma, in: 8...25, step: 0.5)
                        .labelsHidden()
                        .tint(.laneCyan)
                        .fixedSize()
                }

                Divider().overlay(Color.laneCyan.opacity(0.15))

                // Allures de référence dérivées de la VMA.
                HStack(spacing: 0) {
                    zonePace("EF", percent: 65)
                    zonePace("SEUIL", percent: 85)
                    zonePace("VMA", percent: 100)
                }
            }
        }
    }

    private func zonePace(_ label: String, percent: Double) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
            Text(VMACalculator.paceString(vma: vma, percent: percent))
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(Color.laneCyan)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("/km")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Sélecteur de séances

    private var sessionPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle("SÉANCE")
                .padding(.leading, 4)

            categorySelector

            ForEach(RunSession.sessions(in: selectedCategory)) { session in
                Button {
                    withAnimation(.snappy) { selectedSessionID = session.id }
                } label: {
                    sessionRow(session)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Barre horizontale de familles de séances (filtre pour désencombrer).
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SessionCategory.allCases) { category in
                    let isActive = category == selectedCategory
                    Button {
                        withAnimation(.snappy) {
                            selectedCategory = category
                            // Garde une sélection valide dans la nouvelle famille.
                            if let first = RunSession.sessions(in: category).first {
                                selectedSessionID = first.id
                            }
                        }
                    } label: {
                        Label(category.label, systemImage: category.systemImage)
                            .font(.system(.footnote, design: .monospaced))
                            .fontWeight(isActive ? .bold : .regular)
                            .foregroundStyle(isActive ? .black : .white.opacity(0.75))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background {
                                Capsule().fill(isActive ? Color.laneCyan : Color.white.opacity(0.06))
                            }
                            .overlay {
                                Capsule().strokeBorder(Color.laneCyan.opacity(isActive ? 0 : 0.25),
                                                       lineWidth: 0.5)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
        .scrollClipDisabled()
    }

    private func sessionRow(_ session: RunSession) -> some View {
        let isSelected = session.id == selectedSessionID
        return LiquidGlassCard(selected: isSelected) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(session.name)
                            .font(.system(.headline, design: .monospaced))
                            .foregroundStyle(.white)
                        focusTag(session.focus)
                    }
                    Text(session.summary)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.laneCyan : .white.opacity(0.3))
            }
        }
    }

    private func focusTag(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(1)
            .foregroundStyle(.black)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.laneCyan.opacity(0.85), in: Capsule())
    }

    // MARK: Détail de la séance sélectionnée

    private var detailCard: some View {
        let totals = selectedSession.totals(vma: vma)
        return LiquidGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                cardTitle("STRUCTURE @ \(String(format: "%.1f", vma)) km/h")

                if let warmup = selectedSession.warmup {
                    stepLine(label: "ÉCHAUFFEMENT", step: warmup, iterations: 1)
                    Divider().overlay(Color.laneCyan.opacity(0.12))
                }

                ForEach(selectedSession.blocks) { block in
                    blockView(block)
                    Divider().overlay(Color.laneCyan.opacity(0.12))
                }

                if let cooldown = selectedSession.cooldown {
                    stepLine(label: "RETOUR AU CALME", step: cooldown, iterations: 1)
                    Divider().overlay(Color.laneCyan.opacity(0.12))
                }

                // Totaux estimés.
                HStack {
                    totalTile("DISTANCE", value: String(format: "%.1f km", totals.distance / 1000))
                    totalTile("DURÉE", value: Self.formatDuration(totals.duration))
                }
                .padding(.top, 2)
            }
        }
    }

    private func blockView(_ block: SessionBlock) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(block.title.uppercased())
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Color.laneCyan.opacity(0.8))
            ForEach(block.steps) { step in
                stepLine(label: nil, step: step, iterations: block.iterations)
            }
        }
    }

    /// Une ligne de pas : rôle, cible (durée/distance), allure calculée.
    private func stepLine(label: String?, step: SessionStep, iterations: Int) -> some View {
        let isWork = step.role == .work
        let prefix = iterations > 1 ? "\(iterations) × " : ""
        let title = label ?? "\(prefix)\(step.goal.label)"
        return HStack {
            Circle()
                .fill(isWork ? Color.laneCyan : Color.white.opacity(0.25))
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(isWork ? .white : .white.opacity(0.7))
            Spacer()
            Text(VMACalculator.paceString(vma: vma, percent: step.percentVMA) + " /km")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(isWork ? Color.laneCyan : .white.opacity(0.45))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }

    private func totalTile(_ label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Bouton d'action

    private var injectButton: some View {
        Button(action: injectToWatch) {
            HStack(spacing: 10) {
                if isInjecting { ProgressView().tint(.black) }
                Text(isInjecting ? "INJECTION…" : "INJECTER LE PAYLOAD")
                    .font(.system(.headline, design: .monospaced))
                    .tracking(2)
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.laneCyan.opacity(isInjecting ? 0.5 : 1),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.laneCyan.opacity(0.4), radius: 16, y: 0)
        }
        .buttonStyle(.plain)
        .disabled(isInjecting)
    }

    // MARK: Composants réutilisables

    private func cardTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .tracking(3)
            .foregroundStyle(Color.laneCyan)
    }

    nonisolated private static func formatDuration(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: Actions

    /// Construit la séance sélectionnée pour la VMA courante et l'injecte sur
    /// l'Apple Watch via `WorkoutScheduler`.
    private func injectToWatch() {
        let workout = selectedSession.customWorkout(vma: vma)

        isInjecting = true
        withAnimation { statusMessage = "Autorisation…" }

        // La vue est isolée @MainActor : le Task hérite de cet acteur.
        Task {
            defer { isInjecting = false }

            let auth = await WorkoutScheduler.shared.requestAuthorization()
            guard auth == .authorized else {
                withAnimation { statusMessage = "Autorisation refusée." }
                return
            }

            let plan = WorkoutPlan(.custom(workout))
            let when = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: Date().addingTimeInterval(60)
            )
            await WorkoutScheduler.shared.schedule(plan, at: when)

            withAnimation { statusMessage = "« \(selectedSession.name) » injectée ✓" }
        }
    }
}

#Preview {
    WorkoutBuilderView()
}
