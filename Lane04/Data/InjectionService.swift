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

    var errorDescription: String? {
        switch self {
        case .authorizationDenied: return "AUTORISATION REFUSÉE"
        case .unpaired:            return "MONTRE NON APPAIRÉE"
        }
    }
}

enum InjectionService {
    /// Planifie réellement la séance sur l'Apple Watch. Lève une erreur si
    /// l'autorisation n'est pas accordée. `schedule` lui-même est non-throwing.
    static func schedule(_ workout: CustomWorkout) async throws {
        let auth = await WorkoutScheduler.shared.requestAuthorization()
        guard auth == .authorized else { throw InjectionError.authorizationDenied }

        let plan = WorkoutPlan(.custom(workout))
        let when = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: Date().addingTimeInterval(60)
        )
        await WorkoutScheduler.shared.schedule(plan, at: when)
    }
}
