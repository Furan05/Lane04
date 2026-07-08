//
//  StepGoalSheet.swift
//  Lane04
//
//  Édition de l'OBJECTIF d'un pas dans le builder manuel : DURÉE ou DISTANCE
//  (mutuellement exclusif — un seul sélecteur neutre, donc pas de second aplat)
//  + valeur réglée par crans. Même grammaire que la sheet d'allure (§12).
//

import SwiftUI

struct StepGoalSheet: View {
    @Bindable var step: ProtocolStep
    @Environment(\.dismiss) private var dismiss

    // États locaux par unité : basculer TIME/DISTANCE ne perd pas la valeur saisie.
    @State private var kind: GoalKind
    @State private var seconds: Int
    @State private var meters: Int

    init(step: ProtocolStep) {
        self._step = Bindable(wrappedValue: step)
        self._kind = State(initialValue: step.goalKind)
        self._seconds = State(initialValue: step.goalKind == .time ? Int(step.goalValue) : 60)
        self._meters = State(initialValue: step.goalKind == .distance ? Int(step.goalValue) : 400)
    }

    var body: some View {
        ZStack {
            Color.void.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.xl) {
                HStack {
                    Text("STEP GOAL").font(.label).tracking(1.5).foregroundStyle(Color.steelHi)
                    Spacer()
                    Text(step.role.rawValue).font(.label).tracking(1.5)
                        .foregroundStyle(step.role.isEffort ? Color.ember : Color.steel)
                }

                unitSelector

                // Readout DATA-XL de la valeur courante.
                Text(readout)
                    .font(.dataXL).foregroundStyle(Color.laneWhite)
                    .metricDigits().contentTransition(.numericText())

                crans

                PrimaryActionButton(title: "COMMIT") {
                    step.goalKind = kind
                    step.goalValue = kind == .time ? Double(seconds) : Double(meters)
                    dismiss()
                }
            }
            .padding(.horizontal, Grid.margin)
            .padding(.top, Spacing.xl)
        }
        .presentationBackground(Color.void)
        .presentationCornerRadius(Radius.sheet)
        .presentationDetents([.medium])
    }

    // Sélecteur neutre TIME / DISTANCE (jamais d'aplat d'accent — geste de structure).
    private var unitSelector: some View {
        HStack(spacing: 0) {
            unitSegment("DURÉE", .time)
            unitSegment("DISTANCE", .distance)
        }
        .background(Color.carbon1, in: RoundedRectangle(cornerRadius: Radius.control))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.control).strokeBorder(Surface.hairline, lineWidth: 1)
        }
    }

    private func unitSegment(_ title: String, _ value: GoalKind) -> some View {
        let selected = kind == value
        return Button {
            Haptic.selection()
            withAnimation(.master(Duration.micro)) { kind = value }
        } label: {
            Text(title)
                .font(.label).tracking(1.5)
                .foregroundStyle(selected ? Color.laneWhite : Color.steel)
                .frame(maxWidth: .infinity, minHeight: Touch.min)
                .background(selected ? Color.carbon2 : Color.clear,
                            in: RoundedRectangle(cornerRadius: Radius.control))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var readout: String {
        kind == .time ? Format.goalTime(seconds) : Format.goalDistance(meters)
    }

    // Crans adaptés à l'unité : ±15 S / ±1 MIN, ou ±100 M / ±1 KM.
    @ViewBuilder
    private var crans: some View {
        if kind == .time {
            HStack(spacing: Spacing.s) {
                cranButton("−1 MIN") { adjustTime(-60) }
                cranButton("−15 S") { adjustTime(-15) }
                cranButton("+15 S") { adjustTime(15) }
                cranButton("+1 MIN") { adjustTime(60) }
            }
        } else {
            HStack(spacing: Spacing.s) {
                cranButton("−1 KM") { adjustDist(-1000) }
                cranButton("−100 M") { adjustDist(-100) }
                cranButton("+100 M") { adjustDist(100) }
                cranButton("+1 KM") { adjustDist(1000) }
            }
        }
    }

    private func cranButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button {
            Haptic.selection()
            withAnimation(.master(Duration.micro)) { action() }
        } label: {
            Text(title)
                .font(.label).tracking(1.5).foregroundStyle(Color.laneWhite).metricDigits()
                .frame(maxWidth: .infinity, minHeight: Touch.min)
                .background(Color.carbon2, in: RoundedRectangle(cornerRadius: Radius.control))
        }
        .buttonStyle(PressableStyle())
    }

    private func adjustTime(_ d: Int) { seconds = max(5, min(3600, seconds + d)) }     // 5 s … 60 min
    private func adjustDist(_ d: Int) { meters = max(50, min(20_000, meters + d)) }     // 50 m … 20 km
}
