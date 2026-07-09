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

    /// Retire une séance planifiée. (Ne « désinjecte » pas la montre en V1 — voir notes.)
    static func remove(_ session: PlannedSession, in context: ModelContext) {
        context.delete(session)
        try? context.save()
    }

    /// Déplace une séance sur un autre jour (garde l'heure). Repasse en `[PLANNED]` :
    /// la montre ne connaît plus la nouvelle date → un COMMIT est nécessaire.
    static func reschedule(_ session: PlannedSession, to day: Date, in context: ModelContext) {
        session.date = atTime(day, keepingTimeOf: session.date)
        session.state = .planned
        try? context.save()
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

    // MARK: - Semaine (lundi en tête, langue FR)

    static var weekCalendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // lundi
        return cal
    }

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
