//
//  CalendarScreen.swift
//  Lane04
//
//  Écran CALENDAR — planifier des séances à l'avance. Bande SEMAINE (lundi→dimanche)
//  + AGENDA du jour sélectionné. « Planifier puis injecter » : une séance PLANNED
//  vit offline dans l'app ; COMMIT la transmet réellement sur la montre pour SA
//  date (WorkoutKit `schedule(_:at:)`) → SCHEDULED. Le verrou de vérité tient :
//  PLANNED ≠ sur la montre.
//

import SwiftUI
import SwiftData

struct CalendarScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LinkController.self) private var link

    @Query private var plans: [PlannedSession]
    @Query private var profiles: [OperatorProfile]
    private var vma: Double { profiles.first?.vma ?? 16.0 }

    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var showingPicker = false
    @State private var committing: Set<PersistentIdentifier> = []
    @State private var mode: CalMode = .week

    /// Vue temporelle : la semaine (bande + agenda du jour) ou la liste de TOUTES
    /// les séances à traiter (à venir + passé non transmis).
    private enum CalMode { case week, upcoming }

    private var weekDays: [Date] { PlanActions.weekDays(containing: selectedDay) }
    private var daySessions: [PlannedSession] { PlanActions.sessions(on: selectedDay, in: plans) }

    private var status: String {
        let n = mode == .week
            ? PlanActions.sessions(inWeekOf: selectedDay, in: plans).count
            : upcomingSessions.count
        return n == 0 ? "NO PLAN" : "\(n) PLANNED"
    }

    var body: some View {
        ScreenScaffold(title: "CALENDAR", status: status) {
            VStack(spacing: Spacing.l) {
                modeSelector
                if mode == .week {
                    weekHeader
                    weekStrip
                    agenda
                } else {
                    upcomingList
                }
            }
        }
        .sheet(isPresented: $showingPicker) {
            PlanPickerSheet(day: selectedDay) { proto in
                PlanActions.plan(proto, on: selectedDay, in: modelContext)
                showingPicker = false
            }
        }
    }

    // MARK: - Bascule SEMAINE / À VENIR (sélecteur neutre, jamais d'aplat)

    private var modeSelector: some View {
        HStack(spacing: 0) {
            modeSegment("SEMAINE", .week)
            modeSegment("À VENIR", .upcoming)
        }
        .background(Color.carbon1, in: RoundedRectangle(cornerRadius: Radius.control))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.control).strokeBorder(Surface.hairline, lineWidth: 1)
        }
    }

    private func modeSegment(_ title: String, _ value: CalMode) -> some View {
        let selected = mode == value
        return Button {
            Haptic.selection()
            withAnimation(.master(Duration.micro)) { mode = value }
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

    // MARK: - À VENIR : toutes les séances à traiter, groupées par jour

    /// Futur (aujourd'hui inclus, tous états) + passé **non transmis** (états ≠
    /// SCHEDULED : oubliées ou en faute). Une SCHEDULED passée = déjà sur la montre
    /// → masquée (ce n'est plus « à traiter »).
    private var upcomingSessions: [PlannedSession] {
        let startToday = Calendar.current.startOfDay(for: Date())
        return plans
            .filter { $0.date >= startToday || $0.state != .scheduled }
            .sorted { $0.date < $1.date }
    }

    private var upcomingGrouped: [(day: Date, sessions: [PlannedSession])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: upcomingSessions) { cal.startOfDay(for: $0.date) }
        return groups.keys.sorted().map { key in
            (day: key, sessions: groups[key]!.sorted { $0.date < $1.date })
        }
    }

    @ViewBuilder
    private var upcomingList: some View {
        if upcomingGrouped.isEmpty {
            EmptyStateView(
                headline: "NO SESSION PLANNED",
                metric: "0 PLANNED",
                note: "Planifie une séance depuis la vue SEMAINE pour la retrouver ici."
            )
        } else {
            ForEach(upcomingGrouped, id: \.day) { group in
                VStack(alignment: .leading, spacing: Spacing.s) {
                    dayGroupHeader(group.day)
                    ForEach(group.sessions) { session in
                        sessionCard(session, onJump: { jumpTo(session.date) })
                    }
                }
            }
        }
    }

    // En-tête de groupe de jour ; un jour passé non transmis = alerte EMBER (à traiter).
    private func dayGroupHeader(_ day: Date) -> some View {
        let overdue = day < Calendar.current.startOfDay(for: Date())
        return HStack(spacing: Spacing.s) {
            Text(Self.dayLabel(day)).font(.label).tracking(1.5)
                .foregroundStyle(overdue ? Color.ember : Color.steelHi)
            if overdue {
                Text("· EN RETARD").font(.label).tracking(1.5).foregroundStyle(Color.ember)
            }
        }
    }

    private func jumpTo(_ date: Date) {
        selectedDay = Calendar.current.startOfDay(for: date)
        withAnimation(.master(Duration.micro)) { mode = .week }
    }

    // MARK: - Bande semaine

    private var weekHeader: some View {
        HStack {
            weekArrow("chevron.left", "Semaine précédente") { shiftWeek(-1) }
            Spacer()
            Text(Self.weekLabel(weekDays)).font(.label).tracking(1.5).foregroundStyle(Color.steelHi)
            Spacer()
            weekArrow("chevron.right", "Semaine suivante") { shiftWeek(1) }
        }
    }

    private func weekArrow(_ symbol: String, _ a11y: String, _ action: @escaping () -> Void) -> some View {
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

    private var weekStrip: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(Array(weekDays.enumerated()), id: \.offset) { i, day in
                dayCell(day, weekdayIndex: i)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.s)
        .glassCard()
    }

    private static let weekdayAbbr = ["LUN", "MAR", "MER", "JEU", "VEN", "SAM", "DIM"]

    private func dayCell(_ day: Date, weekdayIndex: Int) -> some View {
        let cal = Calendar.current
        let isSelected = cal.isDate(day, inSameDayAs: selectedDay)
        let isToday = cal.isDateInToday(day)
        let sessions = PlanActions.sessions(on: day, in: plans)
        return Button {
            Haptic.selection()
            withAnimation(.master(Duration.micro)) { selectedDay = cal.startOfDay(for: day) }
        } label: {
            VStack(spacing: Spacing.xs) {
                Text(Self.weekdayAbbr[weekdayIndex])
                    .font(.label).tracking(1)
                    .foregroundStyle(isToday ? Color.laneWhite : Color.steelHi)
                Text("\(cal.component(.day, from: day))")
                    .font(.data).metricDigits()
                    .foregroundStyle(isSelected ? Color.laneWhite : Color.steel)
                dots(sessions)
                Rectangle()   // soulignement du jour sélectionné (idiome QUAD)
                    .fill(Color.laneWhite)
                    .frame(height: 2)
                    .opacity(isSelected ? 1 : 0)
            }
            .frame(maxWidth: .infinity, minHeight: Touch.min)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.a11yDay(day, count: sessions.count))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // Points thermiques (teinte = filière) : jusqu'à 3, puis « + ».
    private func dots(_ sessions: [PlannedSession]) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(sessions.prefix(3).enumerated()), id: \.offset) { _, s in
                Circle().fill(s.proto?.discipline.tint ?? Color.steelDim).frame(width: 4, height: 4)
            }
            if sessions.count > 3 {
                Text("+").font(.system(size: 8)).foregroundStyle(Color.steel)
            }
        }
        .frame(height: 5)
    }

    // MARK: - Agenda du jour

    private var agenda: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(Self.dayLabel(selectedDay)).font(.label).tracking(1.5).foregroundStyle(Color.steelHi)

            if daySessions.isEmpty {
                EmptyStateView(
                    headline: "NO SESSION PLANNED",
                    metric: "0 PLANNED",
                    note: "Planifie une séance sur ce jour pour la préparer à l'avance."
                )
            } else {
                ForEach(daySessions) { session in
                    sessionCard(session)
                }
            }

            PrimaryActionButton(title: "PLAN A TRAINING") { showingPicker = true }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func sessionCard(_ session: PlannedSession, onJump: (() -> Void)? = nil) -> some View {
        let isCommitting = committing.contains(session.persistentModelID)
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                if let proto = session.proto { TagBadge(discipline: proto.discipline) }
                Spacer()
                PlannedStateBadge(state: session.state)
            }
            Text(session.proto?.name ?? "— PROTOCOLE SUPPRIMÉ —")
                .font(.bodyBrand).foregroundStyle(Color.laneWhite)
            HStack(spacing: Spacing.m) {
                Text(Self.timeLabel(session.date)).font(.data).foregroundStyle(Color.steel).metricDigits()
                Spacer()
                commitControl(session, isCommitting: isCommitting)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .glassCard()
        .opacity(isCommitting ? 0.6 : 1)
        .contentShape(Rectangle())
        .onTapGesture { onJump?() }   // À VENIR : tap → saute au jour dans la vue SEMAINE
        .contextMenu {
            Button(role: .destructive) {
                PlanActions.remove(session, in: modelContext)
            } label: { Label("RETIRER DU CALENDRIER", systemImage: "trash") }
        }
    }

    // COMMIT = transmettre à la montre pour la date. Aplat réservé au hero éditeur :
    // ici un bouton contour (recours de structure), teinté selon l'état.
    @ViewBuilder
    private func commitControl(_ session: PlannedSession, isCommitting: Bool) -> some View {
        switch session.state {
        case .scheduled:
            Text("SUR LA MONTRE").font(.label).tracking(1.5).foregroundStyle(Color.cryo)
        case .planned, .fault:
            if isCommitting {
                Text("TX…").font(.label).tracking(1.5).foregroundStyle(Color.ember).metricDigits()
            } else if link.isReady, session.proto != nil {
                Button { commit(session) } label: {
                    Text(session.state == .fault ? "RETRY COMMIT" : "COMMIT")
                        .font(.label).tracking(1.5)
                        .foregroundStyle(session.state == .fault ? Color.ember : Color.laneWhite)
                        .padding(.horizontal, Spacing.m).frame(minHeight: Touch.min)
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.control)
                                .strokeBorder(session.state == .fault ? Color.ember : Surface.hairline, lineWidth: 1)
                        }
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Transmettre la séance à la montre")
            } else {
                Text("NO LINK").font(.label).tracking(1.5).foregroundStyle(Color.steelHi)
            }
        }
    }

    // MARK: - Transmission réelle (WorkoutKit à la date du plan)

    private func commit(_ session: PlannedSession) {
        guard let proto = session.proto, link.isReady else { return }
        let id = session.persistentModelID
        committing.insert(id)
        Haptic.arm()
        let workout = WorkoutBuilder.customWorkout(for: proto, vma: vma)
        let when = session.date
        Task {
            do {
                try await InjectionService.schedule(workout, at: when)
                session.state = .scheduled
                Haptic.done()
            } catch {
                session.state = .fault
            }
            try? modelContext.save()
            committing.remove(id)
        }
    }

    private func shiftWeek(_ direction: Int) {
        let cal = Calendar.current
        if let d = cal.date(byAdding: .day, value: 7 * direction, to: selectedDay) {
            selectedDay = cal.startOfDay(for: d)
        }
    }

    // MARK: - Formatage

    private static func weekLabel(_ days: [Date]) -> String {
        guard let first = days.first, let last = days.last else { return "" }
        let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR"); f.dateFormat = "d"
        let m = DateFormatter(); m.locale = Locale(identifier: "fr_FR"); m.dateFormat = "MMM"
        return "\(f.string(from: first)) – \(f.string(from: last)) \(m.string(from: last).uppercased())"
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR"); f.dateFormat = "EEEE d MMMM"
        return f
    }()
    private static func dayLabel(_ date: Date) -> String { dayFormatter.string(from: date).uppercased() }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()
    private static func timeLabel(_ date: Date) -> String { timeFormatter.string(from: date) }

    private static func a11yDay(_ date: Date, count: Int) -> String {
        let base = dayFormatter.string(from: date)
        return count == 0 ? base : "\(base), \(count) séance\(count > 1 ? "s" : "")"
    }
}

// MARK: - Sélecteur de protocole à planifier (sheet)

private struct PlanPickerSheet: View {
    let day: Date
    let onPick: (RunProtocol) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<RunProtocol> { !$0.isTemplate }, sort: \RunProtocol.createdAt, order: .reverse)
    private var mine: [RunProtocol]
    @Query(filter: #Predicate<RunProtocol> { $0.isTemplate }, sort: \RunProtocol.name)
    private var templates: [RunProtocol]

    var body: some View {
        ZStack {
            Color.void.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.l) {
                HStack {
                    Text("PLAN A TRAINING").font(.titleBrand).foregroundStyle(Color.laneWhite)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.headline).foregroundStyle(Color.steel)
                            .frame(minWidth: Touch.min, minHeight: Touch.min)
                    }
                    .buttonStyle(.plain).accessibilityLabel("Fermer")
                }
                .padding(.horizontal, Grid.margin).padding(.top, Spacing.xl)

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.xl) {
                        section("MES PROTOCOLES", mine, emptyNote: "Compile ou crée un protocole d'abord.")
                        section("TEMPLATES", templates, emptyNote: nil)
                    }
                    .padding(.horizontal, Grid.margin).padding(.bottom, Grid.safeBottom)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .presentationBackground(Color.void)
        .presentationCornerRadius(Radius.sheet)
    }

    @ViewBuilder
    private func section(_ title: String, _ items: [RunProtocol], emptyNote: String?) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title).font(.label).tracking(1.5).foregroundStyle(Color.steelHi)
            if items.isEmpty {
                if let emptyNote {
                    Text(emptyNote).font(.bodyBrand).foregroundStyle(Color.steel)
                }
            } else {
                ForEach(items) { proto in
                    Button { onPick(proto) } label: { pickRow(proto) }
                        .buttonStyle(PressableStyle())
                        .accessibilityIdentifier("plan-pick-row")
                        .accessibilityLabel("Planifier \(proto.name)")
                }
            }
        }
    }

    private func pickRow(_ proto: RunProtocol) -> some View {
        HStack(spacing: Spacing.m) {
            TagBadge(discipline: proto.discipline)
            Text(proto.name).font(.bodyBrand).foregroundStyle(Color.laneWhite)
                .lineLimit(1).minimumScaleFactor(0.7)
            if proto.isTest { StatusBadge("TEST") }
            Spacer()
            Image(systemName: "plus").font(.headline).foregroundStyle(Color.ember)
        }
        .frame(maxWidth: .infinity, minHeight: Touch.min, alignment: .leading)
        .padding(Spacing.l)
        .glassCard()
    }
}
