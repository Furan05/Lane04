//
//  RunSession.swift
//  Lane04
//
//  Created by François.Dubois on 03/07/2026.
//

import Foundation
import WorkoutKit
import HealthKit

// MARK: - Famille de séance

/// Classement des séances par filière, pour éviter de surcharger l'écran.
enum SessionCategory: String, CaseIterable, Identifiable {
    case recovery = "Récup"
    case endurance = "Endurance"
    case threshold = "Seuil"
    case vo2max = "VMA"
    case race = "Spécifique"
    case hills = "Côtes"

    var id: String { rawValue }

    var label: String { rawValue }

    var systemImage: String {
        switch self {
        case .recovery:  return "leaf"
        case .endurance: return "figure.run"
        case .threshold: return "gauge.medium"
        case .vo2max:    return "bolt"
        case .race:      return "flag.checkered"
        case .hills:     return "mountain.2"
        }
    }
}

// MARK: - Objectif d'un pas

/// Objectif d'un pas de séance : soit une durée, soit une distance.
enum StepGoal: Hashable {
    case time(minutes: Double)
    case distance(meters: Double)

    /// Traduction vers l'objectif WorkoutKit.
    var workoutGoal: WorkoutGoal {
        switch self {
        case .time(let minutes):    return .time(minutes * 60, .seconds)
        case .distance(let meters): return .distance(meters, .meters)
        }
    }

    /// Libellé court lisible (« 30 s », « 400 m », « 10 min »).
    var label: String {
        switch self {
        case .time(let minutes):
            let seconds = Int((minutes * 60).rounded())
            return seconds < 60 ? "\(seconds) s" : "\(seconds / 60) min"
        case .distance(let meters):
            return meters < 1000
                ? "\(Int(meters)) m"
                : String(format: "%.1f km", meters / 1000)
        }
    }
}

// MARK: - Pas de séance

/// Un pas élémentaire, exprimé relativement à la VMA.
struct SessionStep: Identifiable {
    enum Role { case warmup, work, recovery, cooldown }

    let id = UUID()
    let role: Role
    let goal: StepGoal
    /// Intensité, en pourcentage de la VMA.
    let percentVMA: Double
    /// Si vrai, un objectif d'allure (`SpeedRangeAlert`) est posé sur le pas.
    var targetsPace: Bool = false

    var purpose: IntervalStep.Purpose {
        role == .work ? .work : .recovery
    }

    /// Vitesse cible du pas pour la VMA donnée (m/s).
    func speed(vma: Double) -> Double {
        VMACalculator.speed(vma: vma, percent: percentVMA)
    }

    /// Alerte d'allure WorkoutKit, uniquement pour les pas ciblés.
    func speedAlert(vma: Double) -> SpeedRangeAlert? {
        guard targetsPace else { return nil }
        return SpeedRangeAlert(
            target: VMACalculator.targetSpeedRange(vma: vma, percent: percentVMA),
            metric: .current
        )
    }

    /// Pas d'intervalle (corps de séance).
    func intervalStep(vma: Double) -> IntervalStep {
        IntervalStep(purpose, goal: goal.workoutGoal, alert: speedAlert(vma: vma))
    }

    /// Pas simple (échauffement / retour au calme).
    func workoutStep(vma: Double) -> WorkoutStep {
        WorkoutStep(goal: goal.workoutGoal, alert: speedAlert(vma: vma))
    }
}

// MARK: - Bloc répété

/// Un bloc répété N fois (ex. 8 × (30 s effort / 30 s récup)).
struct SessionBlock: Identifiable {
    let id = UUID()
    /// Intitulé lisible du bloc (ex. « Série 1 · 8 × 30/30 »).
    let title: String
    /// Pas répétés à chaque itération.
    let steps: [SessionStep]
    let iterations: Int

    func intervalBlock(vma: Double) -> IntervalBlock {
        IntervalBlock(steps: steps.map { $0.intervalStep(vma: vma) }, iterations: iterations)
    }
}

// MARK: - Séance

/// Une séance de course structurée, matérialisable pour une VMA donnée.
struct RunSession: Identifiable {
    let id: String
    let name: String
    let category: SessionCategory
    /// Filière précise affichée en pastille (« VO2max », « SEMI »…).
    let focus: String
    /// Résumé court affiché sur la carte.
    let summary: String
    let warmup: SessionStep?
    let blocks: [SessionBlock]
    let cooldown: SessionStep?

    /// Construit la séance WorkoutKit adaptée à la VMA.
    func customWorkout(vma: Double) -> CustomWorkout {
        CustomWorkout(
            activity: .running,
            location: .outdoor,
            displayName: name,
            warmup: warmup?.workoutStep(vma: vma),
            blocks: blocks.map { $0.intervalBlock(vma: vma) },
            cooldown: cooldown?.workoutStep(vma: vma)
        )
    }

    /// Distance et durée estimées de la séance pour la VMA donnée.
    func totals(vma: Double) -> (distance: Double, duration: TimeInterval) {
        var distance = 0.0
        var duration = 0.0

        func accumulate(_ step: SessionStep, times: Int) {
            let v = step.speed(vma: vma)
            for _ in 0..<times {
                switch step.goal {
                case .time(let minutes):
                    let seconds = minutes * 60
                    duration += seconds
                    distance += v * seconds
                case .distance(let meters):
                    distance += meters
                    duration += v > 0 ? meters / v : 0
                }
            }
        }

        if let warmup { accumulate(warmup, times: 1) }
        for block in blocks {
            for step in block.steps { accumulate(step, times: block.iterations) }
        }
        if let cooldown { accumulate(cooldown, times: 1) }

        return (distance, duration)
    }
}

// MARK: - Catalogue

extension RunSession {

    /// Séances d'une famille donnée, dans l'ordre du catalogue.
    static func sessions(in category: SessionCategory) -> [RunSession] {
        catalog.filter { $0.category == category }
    }

    // Intensités de référence (% VMA), d'après la méthodologie VMA des coachs.
    private enum Zone {
        static let recovery = 55.0     // récup active entre fractions
        static let decrease = 60.0     // décrassage / retour au calme
        static let endurance = 65.0    // endurance fondamentale / échauffement
        static let longRun = 70.0      // sortie longue
        static let active = 75.0       // endurance active
        static let marathon = 80.0     // allure marathon
        static let semi = 85.0         // allure semi / seuil
        static let tenK = 89.0         // allure 10 km
        static let thresholdInt = 88.0 // seuil fractionné
        static let vmaLong = 92.0      // VMA longue (VO2max)
        static let vmaLong2 = 95.0     // VMA longue 3 min
        static let vmaMid = 100.0      // VMA moyenne / côtes longues
        static let vmaMidUp = 103.0    // VMA moyenne courte / côtes moyennes
        static let vmaShort = 105.0    // VMA courte
        static let vmaTop = 108.0      // 30/15
    }

    private static func warmup(_ minutes: Double = 15) -> SessionStep {
        SessionStep(role: .warmup, goal: .time(minutes: minutes), percentVMA: Zone.endurance)
    }

    private static func cooldown(_ minutes: Double = 10) -> SessionStep {
        SessionStep(role: .cooldown, goal: .time(minutes: minutes), percentVMA: Zone.decrease)
    }

    /// Un pas d'effort ciblé (allure surveillée).
    private static func work(_ goal: StepGoal, _ percent: Double) -> SessionStep {
        SessionStep(role: .work, goal: goal, percentVMA: percent, targetsPace: true)
    }

    /// Un pas de récupération (allure libre).
    private static func rest(_ goal: StepGoal, _ percent: Double = Zone.recovery) -> SessionStep {
        SessionStep(role: .recovery, goal: goal, percentVMA: percent)
    }

    /// Catalogue complet, regroupé par famille.
    static let catalog: [RunSession] = [

        // ───────────────────────── RÉCUPÉRATION ─────────────────────────
        RunSession(
            id: "decrassage",
            name: "Décrassage 20 min",
            category: .recovery, focus: "Récup",
            summary: "20 min très souple pour éliminer après une séance dure.",
            warmup: nil,
            blocks: [SessionBlock(title: "Footing souple · 20 min",
                                  steps: [work(.time(minutes: 20), Zone.decrease)], iterations: 1)],
            cooldown: nil
        ),
        RunSession(
            id: "footing-recup",
            name: "Footing récupération 30 min",
            category: .recovery, focus: "Récup",
            summary: "30 min faciles, respiration nasale, pour régénérer.",
            warmup: nil,
            blocks: [SessionBlock(title: "Footing facile · 30 min",
                                  steps: [work(.time(minutes: 30), 62)], iterations: 1)],
            cooldown: nil
        ),

        // ───────────────────────── ENDURANCE ─────────────────────────
        RunSession(
            id: "endurance",
            name: "Endurance fondamentale",
            category: .endurance, focus: "Aérobie",
            summary: "45 min en continu à allure facile pour développer le foncier.",
            warmup: nil,
            blocks: [SessionBlock(title: "Footing continu · 45 min",
                                  steps: [work(.time(minutes: 45), Zone.endurance)], iterations: 1)],
            cooldown: nil
        ),
        RunSession(
            id: "sortie-longue",
            name: "Sortie longue 1 h 15",
            category: .endurance, focus: "Foncier",
            summary: "75 min à allure d'endurance pour le volume et l'économie.",
            warmup: nil,
            blocks: [SessionBlock(title: "Sortie longue · 75 min",
                                  steps: [work(.time(minutes: 75), Zone.longRun)], iterations: 1)],
            cooldown: nil
        ),
        RunSession(
            id: "endurance-active",
            name: "Endurance active 40 min",
            category: .endurance, focus: "Aérobie",
            summary: "40 min soutenues, haut de l'endurance fondamentale.",
            warmup: nil,
            blocks: [SessionBlock(title: "Footing actif · 40 min",
                                  steps: [work(.time(minutes: 40), Zone.active)], iterations: 1)],
            cooldown: nil
        ),
        RunSession(
            id: "footing-progressif",
            name: "Footing progressif 40 min",
            category: .endurance, focus: "Progressif",
            summary: "Trois paliers de 15/15/10 min de plus en plus rapides.",
            warmup: nil,
            blocks: [SessionBlock(title: "Progressif · 65 → 78 % VMA", steps: [
                work(.time(minutes: 15), Zone.endurance),
                work(.time(minutes: 15), 72),
                work(.time(minutes: 10), Zone.active)
            ], iterations: 1)],
            cooldown: nil
        ),

        // ───────────────────────── SEUIL ─────────────────────────
        RunSession(
            id: "seuil-continu",
            name: "Seuil continu 20 min",
            category: .threshold, focus: "Seuil",
            summary: "20 min d'une traite au seuil, tenue d'allure.",
            warmup: warmup(),
            blocks: [SessionBlock(title: "Seuil continu · 20 min",
                                  steps: [work(.time(minutes: 20), Zone.semi)], iterations: 1)],
            cooldown: cooldown()
        ),
        RunSession(
            id: "seuil",
            name: "Seuil 2 × 10 min",
            category: .threshold, focus: "Seuil",
            summary: "Deux blocs de 10 min soutenus, récup 3 min.",
            warmup: warmup(),
            blocks: [SessionBlock(title: "2 × 10 min au seuil · récup 3 min", steps: [
                work(.time(minutes: 10), Zone.semi),
                rest(.time(minutes: 3), Zone.decrease)
            ], iterations: 2)],
            cooldown: cooldown()
        ),
        RunSession(
            id: "seuil-3x8",
            name: "Seuil 3 × 8 min",
            category: .threshold, focus: "Seuil",
            summary: "Trois blocs de 8 min, récup 2 min. Volume au seuil.",
            warmup: warmup(),
            blocks: [SessionBlock(title: "3 × 8 min au seuil · récup 2 min", steps: [
                work(.time(minutes: 8), 86),
                rest(.time(minutes: 2), Zone.decrease)
            ], iterations: 3)],
            cooldown: cooldown()
        ),
        RunSession(
            id: "seuil-6x1000",
            name: "Seuil 6 × 1000 m",
            category: .threshold, focus: "Seuil",
            summary: "Six kilomètres au seuil, récup courte 1 min.",
            warmup: warmup(),
            blocks: [SessionBlock(title: "6 × 1000 m au seuil · récup 1 min", steps: [
                work(.distance(meters: 1000), Zone.thresholdInt),
                rest(.time(minutes: 1), Zone.decrease)
            ], iterations: 6)],
            cooldown: cooldown()
        ),

        // ───────────────────────── VMA / VO2max ─────────────────────────
        RunSession(
            id: "vma-courte",
            name: "VMA courte 2 × 8 × 30/30",
            category: .vo2max, focus: "VO2max",
            summary: "Deux séries de 8 fractions 30 s vite / 30 s trot, récup 3 min.",
            warmup: warmup(),
            blocks: [
                SessionBlock(title: "Série 1 · 8 × 30/30", steps: [
                    work(.time(minutes: 0.5), Zone.vmaShort),
                    rest(.time(minutes: 0.5))
                ], iterations: 8),
                SessionBlock(title: "Récupération inter-série · 3 min",
                             steps: [rest(.time(minutes: 3), Zone.decrease)], iterations: 1),
                SessionBlock(title: "Série 2 · 8 × 30/30", steps: [
                    work(.time(minutes: 0.5), Zone.vmaShort),
                    rest(.time(minutes: 0.5))
                ], iterations: 8)
            ],
            cooldown: cooldown()
        ),
        RunSession(
            id: "vma-30-15",
            name: "VMA 2 × 9 × 30/15",
            category: .vo2max, focus: "VO2max",
            summary: "Fractions courtes très intenses, récup 15 s seulement.",
            warmup: warmup(),
            blocks: [
                SessionBlock(title: "Série 1 · 9 × 30/15", steps: [
                    work(.time(minutes: 0.5), Zone.vmaTop),
                    rest(.time(minutes: 0.25))
                ], iterations: 9),
                SessionBlock(title: "Récupération inter-série · 3 min",
                             steps: [rest(.time(minutes: 3), Zone.decrease)], iterations: 1),
                SessionBlock(title: "Série 2 · 9 × 30/15", steps: [
                    work(.time(minutes: 0.5), Zone.vmaTop),
                    rest(.time(minutes: 0.25))
                ], iterations: 9)
            ],
            cooldown: cooldown()
        ),
        RunSession(
            id: "vma-moyenne",
            name: "VMA moyenne 8 × 400 m",
            category: .vo2max, focus: "VO2max",
            summary: "Huit fois 400 m à VMA, récup 2 min. Puissance aérobie.",
            warmup: warmup(),
            blocks: [SessionBlock(title: "8 × 400 m · récup 2 min", steps: [
                work(.distance(meters: 400), Zone.vmaMid),
                rest(.time(minutes: 2))
            ], iterations: 8)],
            cooldown: cooldown()
        ),
        RunSession(
            id: "vma-10x300",
            name: "VMA 10 × 300 m",
            category: .vo2max, focus: "VO2max",
            summary: "Dix fractions vives de 300 m, récup 1 min.",
            warmup: warmup(),
            blocks: [SessionBlock(title: "10 × 300 m · récup 1 min", steps: [
                work(.distance(meters: 300), Zone.vmaMidUp),
                rest(.time(minutes: 1))
            ], iterations: 10)],
            cooldown: cooldown()
        ),
        RunSession(
            id: "vma-longue",
            name: "VMA longue 5 × 1000 m",
            category: .vo2max, focus: "VO2max",
            summary: "Cinq mille mètres à 92 % VMA, récup 2 min 30.",
            warmup: warmup(),
            blocks: [SessionBlock(title: "5 × 1000 m · récup 2 min 30", steps: [
                work(.distance(meters: 1000), Zone.vmaLong),
                rest(.time(minutes: 2.5))
            ], iterations: 5)],
            cooldown: cooldown()
        ),
        RunSession(
            id: "vma-6x3min",
            name: "VMA longue 6 × 3 min",
            category: .vo2max, focus: "VO2max",
            summary: "Six efforts de 3 min à 95 % VMA, récup 1 min 30.",
            warmup: warmup(),
            blocks: [SessionBlock(title: "6 × 3 min · récup 1 min 30", steps: [
                work(.time(minutes: 3), Zone.vmaLong2),
                rest(.time(minutes: 1.5))
            ], iterations: 6)],
            cooldown: cooldown()
        ),
        RunSession(
            id: "vma-pyramide",
            name: "VMA pyramidale 200→800→200",
            category: .vo2max, focus: "VO2max",
            summary: "Pyramide 200/400/600/800/600/400/200, récup dégressive.",
            warmup: warmup(),
            blocks: [SessionBlock(title: "Pyramide · récup ≈ moitié de l'effort", steps: [
                work(.distance(meters: 200), Zone.vmaShort), rest(.time(minutes: 0.75)),
                work(.distance(meters: 400), Zone.vmaMidUp), rest(.time(minutes: 1)),
                work(.distance(meters: 600), Zone.vmaMid),   rest(.time(minutes: 1.25)),
                work(.distance(meters: 800), 98),            rest(.time(minutes: 1.5)),
                work(.distance(meters: 600), Zone.vmaMid),   rest(.time(minutes: 1.25)),
                work(.distance(meters: 400), Zone.vmaMidUp), rest(.time(minutes: 1)),
                work(.distance(meters: 200), Zone.vmaShort)
            ], iterations: 1)],
            cooldown: cooldown()
        ),

        // ───────────────────────── SPÉCIFIQUE COURSE ─────────────────────────
        RunSession(
            id: "allure-10k",
            name: "Allure 10 km 3 × 2000 m",
            category: .race, focus: "10 KM",
            summary: "Trois blocs de 2 km à allure 10 km, récup 2 min.",
            warmup: warmup(),
            blocks: [SessionBlock(title: "3 × 2000 m allure 10 km · récup 2 min", steps: [
                work(.distance(meters: 2000), Zone.tenK),
                rest(.time(minutes: 2), Zone.decrease)
            ], iterations: 3)],
            cooldown: cooldown()
        ),
        RunSession(
            id: "allure-semi",
            name: "Allure semi 2 × 20 min",
            category: .race, focus: "SEMI",
            summary: "Deux blocs de 20 min à allure semi-marathon, récup 3 min.",
            warmup: warmup(),
            blocks: [SessionBlock(title: "2 × 20 min allure semi · récup 3 min", steps: [
                work(.time(minutes: 20), Zone.semi),
                rest(.time(minutes: 3), Zone.decrease)
            ], iterations: 2)],
            cooldown: cooldown()
        ),
        RunSession(
            id: "allure-marathon",
            name: "Allure marathon 40 min",
            category: .race, focus: "MARATHON",
            summary: "40 min en continu à l'allure cible marathon.",
            warmup: warmup(),
            blocks: [SessionBlock(title: "40 min allure marathon",
                                  steps: [work(.time(minutes: 40), Zone.marathon)], iterations: 1)],
            cooldown: cooldown()
        ),
        RunSession(
            id: "mixte-objectif",
            name: "Mixte seuil + allure 10 km",
            category: .race, focus: "SPÉCIFIQUE",
            summary: "20 min au seuil puis 3 × 1000 m à allure 10 km.",
            warmup: warmup(),
            blocks: [
                SessionBlock(title: "Bloc seuil · 20 min", steps: [
                    work(.time(minutes: 20), Zone.semi),
                    rest(.time(minutes: 3), Zone.decrease)
                ], iterations: 1),
                SessionBlock(title: "3 × 1000 m allure 10 km · récup 2 min", steps: [
                    work(.distance(meters: 1000), Zone.tenK),
                    rest(.time(minutes: 2), Zone.decrease)
                ], iterations: 3)
            ],
            cooldown: cooldown()
        ),

        // ───────────────────────── CÔTES ─────────────────────────
        RunSession(
            id: "cotes-courtes",
            name: "Côtes courtes 10 × 30 s",
            category: .hills, focus: "Côtes",
            summary: "Dix montées de 30 s explosives, récup descente 1 min.",
            warmup: warmup(),
            blocks: [SessionBlock(title: "10 × 30 s en côte · récup 1 min", steps: [
                work(.time(minutes: 0.5), Zone.vmaShort),
                rest(.time(minutes: 1), Zone.decrease)
            ], iterations: 10)],
            cooldown: cooldown()
        ),
        RunSession(
            id: "cotes-moyennes",
            name: "Côtes moyennes 8 × 45 s",
            category: .hills, focus: "Côtes",
            summary: "Huit montées de 45 s puissantes, récup descente 1 min 15.",
            warmup: warmup(),
            blocks: [SessionBlock(title: "8 × 45 s en côte · récup 1 min 15", steps: [
                work(.time(minutes: 0.75), Zone.vmaMidUp),
                rest(.time(minutes: 1.25), Zone.decrease)
            ], iterations: 8)],
            cooldown: cooldown()
        ),
        RunSession(
            id: "cotes-longues",
            name: "Côtes longues 6 × 1 min",
            category: .hills, focus: "Côtes",
            summary: "Six montées d'une minute, force et VO2max, récup 2 min.",
            warmup: warmup(),
            blocks: [SessionBlock(title: "6 × 1 min en côte · récup 2 min", steps: [
                work(.time(minutes: 1), Zone.vmaMid),
                rest(.time(minutes: 2), Zone.decrease)
            ], iterations: 6)],
            cooldown: cooldown()
        )
    ]
}
