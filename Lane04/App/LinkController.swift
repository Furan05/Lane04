//
//  LinkController.swift
//  Lane04
//
//  Statut de liaison montre + HealthKit. Détenu par RootView (comme l'injection).
//  Détection réelle limitée par l'API : WorkoutScheduler expose l'autorisation, pas
//  l'appairage physique ; HealthKit expose le partage écriture. On mappe ces deux
//  vérités sur les fautes 09 (NO LINK) / 10 (ACCESS DENIED). L'instrument ne
//  prétend rien qu'il ne sache.
//

import SwiftUI
import HealthKit
import WorkoutKit

@MainActor
@Observable
final class LinkController {

    enum Status: Equatable {
        case unknown
        case ready
        case unpaired        // WorkoutScheduler non autorisé (proxy liaison montre)
        case healthKitDenied // partage écriture HealthKit refusé
    }

    private(set) var status: Status = .unknown
    private(set) var isPairing = false

    private let store = HKHealthStore()

    var isReady: Bool { status == .ready }

    /// Une faute système de liaison est active (NO LINK / ACCESS DENIED) : la
    /// bottom bar teinte alors le mot CONSOLE en EMBER (signal en texte, pas
    /// d'aplat) pour pointer vers l'écran qui porte la faute.
    var hasFault: Bool { status == .unpaired || status == .healthKitDenied }

    /// Statut système `[BRACKET]` pour l'en-tête selon la liaison.
    var bracket: String {
        switch status {
        case .unknown:         return "SEARCHING"
        case .ready:           return "PAIRED"
        case .unpaired:        return "NO LINK"
        case .healthKitDenied: return "ACCESS DENIED"
        }
    }

    func refresh() async {
        if HKHealthStore.isHealthDataAvailable(),
           store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingDenied {
            status = .healthKitDenied
            return
        }
        let auth = await WorkoutScheduler.shared.authorizationState
        status = (auth == .authorized) ? .ready : .unpaired
    }

    /// Tente d'établir la liaison : demande les autorisations, puis rafraîchit.
    func pair() async {
        isPairing = true
        defer { isPairing = false }
        if HKHealthStore.isHealthDataAvailable() {
            try? await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [])
        }
        _ = await WorkoutScheduler.shared.requestAuthorization()
        await refresh()
    }
}
