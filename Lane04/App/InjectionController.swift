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
import WorkoutKit

@MainActor
@Observable
final class InjectionController {

    enum Phase: Equatable {
        case idle
        case arming
        case transferring(Double)   // 0…1
        case flashing
        case delivered
        /// La montre a reçu la séance, mais l'historique local reste à enregistrer.
        /// Ce n'est surtout pas une faute de transmission : réinjecter créerait un doublon.
        case deliveryWarning(String)
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
        case .deliveryWarning:        return "DELIVERED — LOCAL FAULT"
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

        // Builder = territoire protégé : validation + capture de sa sortie
        // (Sendable) avant l'async. Les valeurs SwiftData ne sont jamais fiables
        // juste parce que l'UI les a initialement créées.
        let workout: CustomWorkout
        do {
            workout = try WorkoutBuilder.validatedCustomWorkout(for: proto, vma: vma)
        } catch {
            return fault(error, at: 0, proto: proto)
        }
        let totals = WorkoutBuilder.totals(for: proto, vma: vma)
        let load = WorkoutBuilder.trimp(for: proto, vma: vma)
        let effectiveMode: TXMode = reduceMotion ? .fast : mode
        let duration = effectiveMode == .fast ? Duration.fast : Duration.ritual

        // ARM (T+0)
        phase = .arming
        proto.state = .ready
        Haptic.arm()

        if let failure = await runTransfer(duration: duration, reduceMotion: reduceMotion,
                                           work: { try await InjectionService.schedule(workout) }) {
            return fault(failure.error, at: failure.progress, proto: proto)
        }

        // CONFIRM — TRAINING DELIVERED = la vérité.
        proto.state = .synced
        do {
            try recordSuccess(proto: proto, totals: totals, load: load, context: context)
            phase = .delivered
            Haptic.done()
        } catch {
            // La programmation a déjà réussi : ne jamais proposer un RETRY INJECT.
            phase = .deliveryWarning("TRAINING DELIVERED — LOCAL SAVE FAILED")
            return
        }

        try? await Task.sleep(for: .seconds(0.6))
        if case .delivered = phase { reset() }
    }

    // MARK: - Replanification (retrait D'ABORD, puis réinjection)

    /// Déplace une séance déjà transmise. L'ordre n'est pas négociable :
    /// **retrait de l'occurrence sur la montre → vérification → réinjection**. Un
    /// retrait en échec abandonne la replanification ; la séance reste `SCHEDULED`
    /// à son ANCIENNE date, parce que c'est ce que la montre détient réellement.
    /// Jamais deux occurrences de la même séance.
    func reschedule(session: PlannedSession, to day: Date, vma: Double, mode: TXMode,
                    reduceMotion: Bool, context: ModelContext) async {
        guard case .idle = phase else { return }
        guard let proto = session.proto else { return }
        activeID = proto.persistentModelID

        // Validation avant retrait : ne jamais désarmer la montre pour découvrir
        // ensuite qu'on ne sait pas reconstruire la séance.
        let workout: CustomWorkout
        do {
            workout = try WorkoutBuilder.validatedCustomWorkout(for: proto, vma: vma)
        } catch {
            return fault(error, at: 0, proto: proto)
        }
        let effectiveMode: TXMode = reduceMotion ? .fast : mode
        let duration = effectiveMode == .fast ? Duration.fast : Duration.ritual

        phase = .arming
        Haptic.arm()

        // 1 — RETRAIT, avant toute chose.
        if session.state == .scheduled {
            guard let planID = session.scheduledPlanID else {
                // Séance transmise par un build antérieur : pas de poignée de retrait.
                // Refuser est la seule issue honnête (déplacer créerait un doublon).
                phase = .fault("RESCHEDULE UNAVAILABLE — NO WATCH HANDLE")
                return
            }
            do {
                try await InjectionService.remove(planID: planID)
            } catch {
                // La montre détient TOUJOURS l'ancienne occurrence : on n'injecte pas
                // et on ne touche ni à la date ni à l'état — mentir serait pire.
                let cause = (error as? LocalizedError)?.errorDescription ?? "REMOVAL FAULT"
                phase = .fault("RESCHEDULE ABORTED — \(cause)")
                return
            }
            // Retrait confirmé : la montre ne détient plus rien pour cette séance.
            PlanActions.clearSchedule(session, in: context)
        }

        // 2 — Nouvelle date, puis la chorégraphie d'injection existante (verrou 90 %).
        PlanActions.applyNewDate(session, to: day, in: context)
        let when = session.date
        let planID = UUID()

        if let failure = await runTransfer(duration: duration, reduceMotion: reduceMotion,
                                           work: { try await InjectionService.schedule(workout, at: when, planID: planID) }) {
            // Retirée de la montre mais pas reprogrammée : SCHEDULE FAULT à la
            // nouvelle date → RETRY COMMIT depuis CALENDAR. Aucun doublon.
            session.state = .fault
            try? context.save()
            return fault(failure.error, at: failure.progress, proto: proto)
        }

        // Pas de RunLog : LOGS reste la trace des injections immédiates.
        PlanActions.markScheduled(session, planID: planID, at: when, in: context)
        phase = .delivered
        Haptic.done()
        try? await Task.sleep(for: .seconds(0.6))
        if case .delivered = phase { reset() }
    }

    // MARK: - Faisceau + VERROU de vérité (partagé injection / replanification)

    /// TRANSFER 0 → 90 % sur ~72 % de la timeline, puis maintien à 90 % jusqu'à la
    /// résolution réelle de `work` — la seule vérité. Rend `nil` en cas de succès,
    /// sinon la faute et le % auquel le faisceau s'est interrompu.
    private func runTransfer(duration: Double, reduceMotion: Bool,
                             work: @escaping () async throws -> Void) async -> (error: Error, progress: Double)? {
        let truth = Truth()
        Task { @MainActor in
            do { try await work(); truth.finished = true }
            catch { truth.error = error; truth.finished = true }
        }

        try? await Task.sleep(for: .seconds(0.05 * duration / Duration.ritual))

        let steps = 36
        let dt = (duration * 0.72) / Double(steps)
        let tickEvery = max(1, Int((0.4 / dt).rounded()))
        var progress = 0.0
        for i in 1...steps {
            if let error = truth.error { return (error, progress) }
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
        if let error = truth.error { return (error, 0.90) }

        // Vérité = succès : 90 → 100 %, FLASH (sauf Reduce Motion).
        for i in 1...6 {
            phase = .transferring(0.90 + 0.10 * Double(i) / 6)
            try? await Task.sleep(for: .seconds(0.02))
        }
        if !reduceMotion {
            phase = .flashing
            try? await Task.sleep(for: .seconds(0.080)) // obturateur du chronométreur
        }
        return nil
    }

    private func fault(_ error: Error, at progress: Double, proto: RunProtocol) {
        let cause = (error as? LocalizedError)?.errorDescription ?? "SYNC FAULT"
        phase = .fault("TRANSFER INTERRUPTED AT \(Int(progress * 100))% — \(cause)")
        proto.state = .fault
    }

    private func recordSuccess(proto: RunProtocol, totals: (distance: Double, duration: TimeInterval), load: Int, context: ModelContext) throws {
        context.insert(RunLog(discipline: proto.discipline,
                              protocolName: proto.name,
                              distanceMeters: totals.distance,
                              durationSeconds: totals.duration,
                              load: load))
        try context.save()
        let count = UserDefaults.standard.integer(forKey: SettingsKey.successfulInjections)
        UserDefaults.standard.set(count + 1, forKey: SettingsKey.successfulInjections)
    }
}
