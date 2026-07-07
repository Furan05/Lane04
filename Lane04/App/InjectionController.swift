//
//  InjectionController.swift
//  Lane04
//
//  Machine à états de l'injection + chorégraphie (§07). Vit HORS de la vue
//  (détenue par RootView) → survit à la disparition de l'éditeur : le statut
//  [TX…] et l'issue [SYNCED]/[SYNC FAULT] persistent.
//
//  Verrou de vérité : FLASH et CONFIRM ne partent JAMAIS avant la résolution
//  réelle de schedule(). Le faisceau tient à 90 % (en respirant) tant que la
//  vérité n'est pas connue ; une erreur interrompt le faisceau au % courant.
//

import SwiftUI
import SwiftData

@MainActor
@Observable
final class InjectionController {

    enum Phase: Equatable {
        case idle
        case arming
        case transferring(Double)   // 0…1
        case flashing
        case delivered
        case fault(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var activeID: PersistentIdentifier?

    /// Une injection est en cours (états transitoires), quel que soit le protocole.
    /// La bottom bar passe à 40 % et ignore les taps tant que c'est vrai
    /// (cohérent avec l'écran qui chute à 40 % pendant ARM).
    var isTransmitting: Bool {
        switch phase {
        case .arming, .transferring, .flashing: return true
        default: return false
        }
    }

    /// Une injection est en cours (états transitoires) pour ce protocole ?
    func isInjecting(_ proto: RunProtocol) -> Bool {
        guard activeID == proto.persistentModelID else { return false }
        switch phase {
        case .arming, .transferring, .flashing: return true
        default: return false
        }
    }

    /// Statut système à afficher dans le header pour ce protocole.
    func status(for proto: RunProtocol) -> String {
        guard activeID == proto.persistentModelID else { return proto.state.rawValue }
        switch phase {
        case .arming:                 return "TX…"
        case .transferring(let p):    return "TX \(Int(p * 100))%"
        case .flashing:               return "TX 100%"
        case .delivered:              return ProtocolState.synced.rawValue
        case .fault:                  return ProtocolState.fault.rawValue
        case .idle:                   return proto.state.rawValue
        }
    }

    func acknowledgeFault() { reset() }

    #if DEBUG
    /// Seam de test UI (DEBUG uniquement) : fige la barre en état TX sans lancer
    /// de vraie injection (le hero est éteint sans montre pairée en simulateur).
    /// Permet de vérifier que la bottom bar passe à 40 % et ignore les taps.
    func simulateTransmittingForUITest() {
        activeID = nil
        phase = .transferring(0.5)
    }
    #endif

    private func reset() {
        phase = .idle
        activeID = nil
    }

    // MARK: - Chorégraphie

    private final class Truth { var finished = false; var error: Error? }

    func inject(proto: RunProtocol, vma: Double, mode: TXMode, reduceMotion: Bool, context: ModelContext) async {
        guard case .idle = phase else { return }
        activeID = proto.persistentModelID

        // Builder = territoire protégé : on capture sa sortie (Sendable) avant l'async.
        let workout = WorkoutBuilder.customWorkout(for: proto, vma: vma)
        let totals = WorkoutBuilder.totals(for: proto, vma: vma)
        let effectiveMode: TXMode = reduceMotion ? .fast : mode
        let duration = effectiveMode == .fast ? Duration.fast : Duration.ritual

        // ARM (T+0)
        phase = .arming
        proto.state = .ready
        Haptic.arm()

        // schedule() lancé en parallèle — la seule vérité.
        let truth = Truth()
        Task { @MainActor in
            do { try await InjectionService.schedule(workout); truth.finished = true }
            catch { truth.error = error; truth.finished = true }
        }

        try? await Task.sleep(for: .seconds(0.05 * duration / Duration.ritual))

        // TRANSFER : 0 → 90 % sur ~72 % de la timeline. Interruption immédiate si erreur.
        let steps = 36
        let dt = (duration * 0.72) / Double(steps)
        let tickEvery = max(1, Int((0.4 / dt).rounded()))
        var progress = 0.0
        for i in 1...steps {
            if let error = truth.error {
                return fault(error, at: progress, proto: proto)
            }
            progress = 0.90 * Double(i) / Double(steps)
            phase = .transferring(progress)
            if !reduceMotion, i % tickEvery == 0 { Haptic.tick() }
            try? await Task.sleep(for: .seconds(dt))
        }
        phase = .transferring(0.90)

        // VERROU : tenir à 90 % (la vue fait respirer le %) jusqu'à la vérité.
        while !truth.finished {
            try? await Task.sleep(for: .seconds(0.1))
        }
        if let error = truth.error {
            return fault(error, at: 0.90, proto: proto)
        }

        // Vérité = succès : 90 → 100 %, FLASH (sauf Reduce Motion), CONFIRM.
        for i in 1...6 {
            phase = .transferring(0.90 + 0.10 * Double(i) / 6)
            try? await Task.sleep(for: .seconds(0.02))
        }
        if !reduceMotion {
            phase = .flashing
            try? await Task.sleep(for: .seconds(0.080)) // obturateur du chronométreur
        }

        // CONFIRM — PAYLOAD DELIVERED = la vérité.
        phase = .delivered
        Haptic.done()
        proto.state = .synced
        recordSuccess(proto: proto, totals: totals, context: context)

        try? await Task.sleep(for: .seconds(0.6))
        if case .delivered = phase { reset() }
    }

    private func fault(_ error: Error, at progress: Double, proto: RunProtocol) {
        let cause = (error as? LocalizedError)?.errorDescription ?? "SYNC FAULT"
        phase = .fault("TRANSFER INTERRUPTED AT \(Int(progress * 100))% — \(cause)")
        proto.state = .fault
    }

    private func recordSuccess(proto: RunProtocol, totals: (distance: Double, duration: TimeInterval), context: ModelContext) {
        let count = UserDefaults.standard.integer(forKey: SettingsKey.successfulInjections)
        UserDefaults.standard.set(count + 1, forKey: SettingsKey.successfulInjections)
        context.insert(RunLog(discipline: proto.discipline,
                              protocolName: proto.name,
                              distanceMeters: totals.distance,
                              durationSeconds: totals.duration))
        try? context.save()
    }
}
