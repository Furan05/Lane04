//
//  ConsoleSettings.swift
//  Lane04
//
//  Réglages CONSOLE simples, persistés en @AppStorage (pas SwiftData).
//  Référence : écran 07 — CONSOLE.
//

import Foundation

/// Mode de chorégraphie d'injection (§07). Bascule auto RITUAL→FAST dès la 10ᵉ.
enum TXMode: String, CaseIterable, Identifiable {
    case ritual = "RITUAL"
    case fast = "FAST"
    var id: String { rawValue }
}

/// Unité d'affichage des allures.
enum PaceUnit: String, CaseIterable, Identifiable {
    case minPerKm = "MIN/KM"
    case kmPerH = "KM/H"
    var id: String { rawValue }
}

/// Cible de transmission WorkoutKit.
enum WatchTarget: String, CaseIterable, Identifiable {
    case ultra2 = "ULTRA 2"
    case series = "SERIES"
    case se = "SE"
    var id: String { rawValue }
}

/// Clés @AppStorage centralisées.
enum SettingsKey {
    static let txMode = "console.txMode"
    static let paceUnit = "console.paceUnit"
    static let haptics = "console.haptics"
    static let watchTarget = "console.watchTarget"
    /// Compteur d'injections réussies — bascule RITUAL→FAST à 10 (§07).
    static let successfulInjections = "tx.successfulInjections"
    /// URL du relais Garmin auto-hébergé (fallback si absente d'Info.plist).
    static let garminBackendURL = "garmin.backendURL"
}
