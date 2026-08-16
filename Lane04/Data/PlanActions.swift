//
//  PlanActions.swift
//  Lane04
//
//  Actions de PLANIFICATION (calendrier), hors UI et testables. Les mutations
//  pures (créer / supprimer / replanifier) vivent ici ; la transmission réelle
//  vers la montre (WorkoutKit) est portée par la vue via InjectionService.
//

import Foundation
import SwiftData

enum PlanActions {
    /// Heure par défaut d'une séance planifiée (matin). Réglage fin de l'heure = V2.
    static let defaultHour = 7

    /// Planifie un protocole sur un jour → séance `[PLANNED]` (offline, pas encore
    /// sur la montre). Insérée + sauvée.
    @discardableResult
    static func plan(_ proto: RunProtocol, on day: Date, in context: ModelContext) -> PlannedSession {
        let session = PlannedSession(date: atDefaultTime(day), state: .planned, proto: proto)
        context.insert(session)
        try? context.save()
        return session
    }

    /// Une séance déjà programmée sur la montre est immuable **localement** : la
    /// déplacer sans prévenir la montre créerait une séance fantôme/dupliquée.
    /// Elle reste replanifiable, mais uniquement par le flux qui retire d'abord
    /// l'occurrence de la montre (`InjectionController.reschedule`).
    static func canModify(_ session: PlannedSession) -> Bool {
        session.state != .scheduled
    }

    /// Vrai si la séance est réellement sur la montre ET qu'on détient la poignée de
    /// retrait. Une séance `SCHEDULED` sans `scheduledPlanID` vient d'un build
    /// antérieur à la replanification : on ne sait pas la retirer → on ne la déplace
    /// pas (mentir sur l'état de la montre est pire que refuser).
    static func canReschedule(_ session: PlannedSession) -> Bool {
        session.state != .scheduled || session.scheduledPlanID != nil
    }

    /// Enregistre ce que la montre détient réellement, après un `schedule` réussi.
    static func markScheduled(_ session: PlannedSession, planID: UUID, at date: Date,
                              in context: ModelContext) {
        session.state = .scheduled
        session.scheduledPlanID = planID
        session.scheduledAt = date
        session.watchCopyStale = false   // ce qui vient d'être transmis est à jour
        try? context.save()
    }

    /// La montre ne détient plus rien pour cette séance (retrait confirmé) : on
    /// redescend en `PLANNED` et on lâche la poignée. Appelé **après** la vérification
    /// de disparition, jamais avant.
    static func clearSchedule(_ session: PlannedSession, in context: ModelContext) {
        session.state = .planned
        session.scheduledPlanID = nil
        session.scheduledAt = nil
        try? context.save()
    }

    /// Déplace une séance dont la montre ne détient plus l'occurrence. Ne touche pas
    /// à l'état : réservé au flux de replanification, qui a déjà retiré et vérifié.
    static func applyNewDate(_ session: PlannedSession, to day: Date, in context: ModelContext) {
        session.date = atTime(day, keepingTimeOf: session.date)
        try? context.save()
    }

    /// Retire une séance qui n'a pas encore été programmée sur la montre.
    @discardableResult
    static func remove(_ session: PlannedSession, in context: ModelContext) -> Bool {
        guard canModify(session) else { return false }
        context.delete(session)
        try? context.save()
        return true
    }

    /// Déplace une séance sur un autre jour (garde l'heure). Repasse en `[PLANNED]` :
    /// la montre ne connaît plus la nouvelle date → un COMMIT est nécessaire.
    @discardableResult
    static func reschedule(_ session: PlannedSession, to day: Date, in context: ModelContext) -> Bool {
        guard canModify(session) else { return false }
        session.date = atTime(day, keepingTimeOf: session.date)
        session.state = .planned
        try? context.save()
        return true
    }

    /// Séances d'un jour donné, triées par heure (fonction pure).
    static func sessions(on day: Date, in all: [PlannedSession]) -> [PlannedSession] {
        let cal = Calendar.current
        return all.filter { cal.isDate($0.date, inSameDayAs: day) }
                  .sorted { $0.date < $1.date }
    }

    /// Séances d'une semaine (contenant `day`), pour le compte [BRACKET] (pure).
    static func sessions(inWeekOf day: Date, in all: [PlannedSession]) -> [PlannedSession] {
        let cal = weekCalendar
        guard let interval = cal.dateInterval(of: .weekOfYear, for: day) else { return [] }
        return all.filter { interval.contains($0.date) }
    }

    /// CHARGE cumulée de la semaine (contenant `day`) : somme du TRIMP planifié de
    /// chaque séance, pour une VMA donnée. Charge *planifiée* de la semaine — l'outil
    /// pour ne pas monter le volume trop vite. Fonction pure. Une séance dont le
    /// protocole a été supprimé (proto nil) ne compte pas.
    static func weeklyLoad(inWeekOf day: Date, in all: [PlannedSession], vma: Double) -> Int {
        sessions(inWeekOf: day, in: all).reduce(0) { sum, session in
            guard let proto = session.proto else { return sum }
            return sum + WorkoutBuilder.trimp(for: proto, vma: vma)
        }
    }

    // MARK: - Semaine (lundi en tête, langue FR)

    static var weekCalendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // lundi
        return cal
    }

    // MARK: - Mois (grille, navigation, charge)

    /// Séances du mois CALENDAIRE de `day`. Le débordement de la grille sur les mois
    /// voisins ne compte pas ici : la charge d'août est celle d'août.
    static func sessions(inMonthOf day: Date, in all: [PlannedSession]) -> [PlannedSession] {
        let cal = weekCalendar
        guard let interval = cal.dateInterval(of: .month, for: day) else { return [] }
        return all.filter { interval.contains($0.date) }.sorted { $0.date < $1.date }
    }

    /// CHARGE cumulée du mois (somme du TRIMP planifié). Même logique que la semaine :
    /// une séance dont le protocole a été supprimé ne compte pas.
    static func monthlyLoad(inMonthOf day: Date, in all: [PlannedSession], vma: Double) -> Int {
        sessions(inMonthOf: day, in: all).reduce(0) { sum, session in
            guard let proto = session.proto else { return sum }
            return sum + WorkoutBuilder.trimp(for: proto, vma: vma)
        }
    }

    /// La grille du mois contenant `day` : des semaines **complètes** (lundi en tête),
    /// donc débordant sur les mois voisins pour que chaque ligne fasse 7 cases.
    /// Rend 28, 35 ou 42 jours selon le mois.
    static func monthGridDays(containing day: Date) -> [Date] {
        let cal = weekCalendar
        guard let month = cal.dateInterval(of: .month, for: day),
              let firstWeek = cal.dateInterval(of: .weekOfYear, for: month.start)
        else { return [] }

        var days: [Date] = []
        var cursor = firstWeek.start
        while cursor < month.end {
            for offset in 0..<7 {
                if let d = cal.date(byAdding: .day, value: offset, to: cursor) {
                    days.append(cal.startOfDay(for: d))
                }
            }
            guard let next = cal.date(byAdding: .weekOfYear, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    /// Le même jour, `offset` mois plus loin. Foundation borne au dernier jour du mois
    /// cible (31 janvier + 1 mois = 28/29 février, jamais le 2 ou 3 mars).
    static func month(_ day: Date, offset: Int) -> Date {
        weekCalendar.date(byAdding: .month, value: offset, to: day) ?? day
    }

    /// `day` appartient-il au mois calendaire de `reference` ? (grise le débordement)
    static func isSameMonth(_ day: Date, as reference: Date) -> Bool {
        weekCalendar.isDate(day, equalTo: reference, toGranularity: .month)
    }

    // MARK: - Semaine

    /// Les 7 jours de la semaine contenant `day` (lundi → dimanche).
    static func weekDays(containing day: Date) -> [Date] {
        let cal = weekCalendar
        guard let start = cal.dateInterval(of: .weekOfYear, for: day)?.start else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    // MARK: - Heures

    private static func atDefaultTime(_ day: Date) -> Date {
        Calendar.current.date(bySettingHour: defaultHour, minute: 0, second: 0, of: day) ?? day
    }
    private static func atTime(_ day: Date, keepingTimeOf ref: Date) -> Date {
        let cal = Calendar.current
        let t = cal.dateComponents([.hour, .minute], from: ref)
        return cal.date(bySettingHour: t.hour ?? defaultHour, minute: t.minute ?? 0, second: 0, of: day) ?? day
    }
}
