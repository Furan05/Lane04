//
//  PaceConverter.swift
//  Lane04
//
//  Created by François.Dubois on 03/07/2026.
//

import Foundation

/// Service statique de conversion d'allure course à pied.
///
/// Convertit une allure exprimée en `minutes:secondes/km` vers une vitesse
/// exploitable par WorkoutKit (mètres par seconde) et construit une plage
/// cible tolérante utilisée pour les objectifs d'entraînement.
enum PaceConverter {

    /// Marge de tolérance appliquée à l'allure, en secondes par kilomètre.
    static let toleranceSeconds: Double = 5

    /// Nombre de mètres dans un kilomètre.
    private static let metersPerKilometer: Double = 1000

    /// Convertit une allure `minutes:secondes` par km en vitesse (m/s).
    ///
    /// - Parameters:
    ///   - minutes: La composante minutes de l'allure.
    ///   - seconds: La composante secondes de l'allure.
    /// - Returns: La vitesse en mètres par seconde, ou `nil` si l'allure est nulle.
    static func speed(minutes: Int, seconds: Int) -> Double? {
        let totalSeconds = Double(minutes * 60 + seconds)
        guard totalSeconds > 0 else { return nil }
        return metersPerKilometer / totalSeconds
    }

    /// Convertit une allure au format `"m:ss"` (ex. `"4:30"`) en vitesse (m/s).
    ///
    /// - Parameter pace: Une chaîne au format `minutes:secondes`.
    /// - Returns: La vitesse en mètres par seconde, ou `nil` si le format est invalide.
    static func speed(fromPace pace: String) -> Double? {
        let components = pace.split(separator: ":")
        guard components.count == 2,
              let minutes = Int(components[0].trimmingCharacters(in: .whitespaces)),
              let seconds = Int(components[1].trimmingCharacters(in: .whitespaces)),
              seconds >= 0, seconds < 60 else {
            return nil
        }
        return speed(minutes: minutes, seconds: seconds)
    }

    /// Retourne une plage de vitesse cible centrée sur l'allure demandée.
    ///
    /// La marge de ±5 secondes par kilomètre est appliquée sur l'allure
    /// (le domaine « temps »), puis convertie en vitesse. Une allure plus
    /// rapide correspondant à une vitesse plus élevée, la borne basse de la
    /// plage provient de l'allure la plus lente et inversement.
    ///
    /// - Parameters:
    ///   - minutes: La composante minutes de l'allure cible.
    ///   - seconds: La composante secondes de l'allure cible.
    /// - Returns: Une plage fermée de vitesse (`Measurement<UnitSpeed>`, m/s),
    ///   directement exploitable par `SpeedRangeAlert` de WorkoutKit, ou `nil`
    ///   si l'allure est invalide.
    static func targetSpeedRange(minutes: Int, seconds: Int) -> ClosedRange<Measurement<UnitSpeed>>? {
        let targetSeconds = Double(minutes * 60 + seconds)
        guard targetSeconds > toleranceSeconds else { return nil }

        // Allure plus lente (borne haute en temps) -> vitesse minimale.
        let slowestSeconds = targetSeconds + toleranceSeconds
        // Allure plus rapide (borne basse en temps) -> vitesse maximale.
        let fastestSeconds = targetSeconds - toleranceSeconds

        let minSpeed = metersPerKilometer / slowestSeconds
        let maxSpeed = metersPerKilometer / fastestSeconds

        let lowerBound = Measurement(value: minSpeed, unit: UnitSpeed.metersPerSecond)
        let upperBound = Measurement(value: maxSpeed, unit: UnitSpeed.metersPerSecond)

        return lowerBound...upperBound
    }

    /// Variante acceptant une allure au format `"m:ss"`.
    static func targetSpeedRange(fromPace pace: String) -> ClosedRange<Measurement<UnitSpeed>>? {
        let components = pace.split(separator: ":")
        guard components.count == 2,
              let minutes = Int(components[0].trimmingCharacters(in: .whitespaces)),
              let seconds = Int(components[1].trimmingCharacters(in: .whitespaces)),
              seconds >= 0, seconds < 60 else {
            return nil
        }
        return targetSpeedRange(minutes: minutes, seconds: seconds)
    }
}
