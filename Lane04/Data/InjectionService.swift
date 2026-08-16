//
//  InjectionService.swift
//  Lane04
//
//  Enveloppe WorkoutKit de l'injection. Territoire protégé : consomme le
//  CustomWorkout produit par WorkoutBuilder (value type Sendable), sans le modifier.
//  C'est la seule source de VÉRITÉ de l'injection — le verrou de la chorégraphie.
//

import Foundation
import WorkoutKit

enum InjectionError: LocalizedError {
    case authorizationDenied
    case unpaired
    /// Le retrait de l'occurrence sur la montre n'a pas pris : elle est TOUJOURS là
    /// après l'appel. Réinjecter à ce stade créerait un doublon → l'appelant doit
    /// abandonner la replanification, pas la poursuivre.
    case removalFailed

    var errorDescription: String? {
        switch self {
        case .authorizationDenied: return "AUTORISATION REFUSÉE"
        case .unpaired:            return "MONTRE NON APPAIRÉE"
        case .removalFailed:       return "RETRAIT MONTRE IMPOSSIBLE"
        }
    }
}

/// La surface WorkoutKit dont dépend l'app, et rien de plus. Une seule
/// implémentation réelle (`LiveWatchScheduler`) ; les tests fournissent un double
/// pour vérifier l'ORDRE des appels (retrait AVANT programmation) sans montre.
@MainActor
protocol WatchScheduling {
    func requestAuthorization() async -> Bool
    /// L'occurrence est-elle réellement présente sur la montre ?
    func isScheduled(_ planID: UUID) async -> Bool
    func schedule(_ workout: CustomWorkout, id: UUID, at date: DateComponents) async
    func remove(_ planID: UUID) async
}

@MainActor
struct LiveWatchScheduler: WatchScheduling {
    func requestAuthorization() async -> Bool {
        await WorkoutScheduler.shared.requestAuthorization() == .authorized
    }

    func isScheduled(_ planID: UUID) async -> Bool {
        await occurrence(planID) != nil
    }

    func schedule(_ workout: CustomWorkout, id: UUID, at date: DateComponents) async {
        await WorkoutScheduler.shared.schedule(WorkoutPlan(.custom(workout), id: id), at: date)
    }

    /// Retire l'occurrence telle que la montre la détient réellement — `remove`
    /// exige le plan ET ses composantes, qu'on relit plutôt que de les reconstruire
    /// (une date locale ayant dérivé ne retirerait rien).
    func remove(_ planID: UUID) async {
        guard let target = await occurrence(planID) else { return }
        await WorkoutScheduler.shared.remove(target.plan, at: target.date)
    }

    private func occurrence(_ planID: UUID) async -> ScheduledWorkoutPlan? {
        await WorkoutScheduler.shared.scheduledWorkouts.first { $0.plan.id == planID }
    }
}

@MainActor
enum InjectionService {
    /// Le backend réel. Remplacé uniquement par les tests (voir `RescheduleTests`),
    /// jamais en production — l'app n'expose aucun chemin pour le changer.
    static var backend: any WatchScheduling = LiveWatchScheduler()

    /// Planifie réellement la séance sur l'Apple Watch **pour la date donnée**.
    /// - Injection immédiate : `date` = maintenant + ~1 min (défaut).
    /// - Planification calendrier : `date` = le jour/heure prévus.
    /// - Returns: l'identité du `WorkoutPlan` transmis. L'appelant DOIT la persister
    ///   (`PlannedSession.scheduledPlanID`) : c'est la seule poignée de retrait.
    @discardableResult
    static func schedule(_ workout: CustomWorkout,
                         at date: Date = Date().addingTimeInterval(60),
                         planID: UUID = UUID()) async throws -> UUID {
        guard await backend.requestAuthorization() else { throw InjectionError.authorizationDenied }
        await backend.schedule(workout, id: planID, at: components(of: date))
        return planID
    }

    /// Retire de la montre l'occurrence portant cette identité, **puis vérifie sa
    /// disparition** — l'instrument ne se croit pas sur parole. Absente au départ =
    /// retrait déjà acquis (idempotent, pas une faute).
    /// - Throws: `.removalFailed` si l'occurrence survit à l'appel. Le contrat de
    ///   l'appelant est alors strict : **ne pas réinjecter**.
    static func remove(planID: UUID) async throws {
        guard await backend.requestAuthorization() else { throw InjectionError.authorizationDenied }
        guard await backend.isScheduled(planID) else { return }

        await backend.remove(planID)

        if await backend.isScheduled(planID) { throw InjectionError.removalFailed }
    }

    /// WorkoutKit programme sur des composantes, pas un instant : une seule
    /// conversion, partagée par la programmation et le retrait.
    static func components(of date: Date) -> DateComponents {
        Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    }
}
