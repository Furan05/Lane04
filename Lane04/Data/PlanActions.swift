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

    /// Une séance déjà programmée sur la montre est immuable localement : WorkoutKit
    /// ne nous donne pas ici de primitive d'annulation fiable. La supprimer ou la
    /// déplacer puis la re-commiter créerait une séance fantôme/dupliquée sur la montre.
    static func canModify(_ session: PlannedSession) -> Bool {
        session.state != .scheduled
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
