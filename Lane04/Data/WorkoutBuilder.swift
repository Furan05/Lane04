//
//  WorkoutBuilder.swift
//  Lane04
//
//  Génération WorkoutKit — PORT à l'identique de l'ancien RunSession.customWorkout.
//  Comportement protégé : mêmes objectifs, mêmes SpeedRangeAlert (±2.5 % VMA via
//  VMACalculator), warmup/cooldown en WorkoutStep, corps en IntervalBlock.
//  Seules les ENTRÉES changent : on lit désormais un RunProtocol (SwiftData).
//
//  Convention de mapping : un bloc à pas unique de rôle .warmup / .cooldown
//  alimente les slots warmup/cooldown du CustomWorkout ; tous les autres blocs
//  deviennent des IntervalBlock. La sortie est identique à l'ancien builder.
//

import Foundation
import WorkoutKit
import HealthKit

enum WorkoutBuilder {

    /// Construit la séance WorkoutKit d'un protocole pour une VMA donnée.
    static func customWorkout(for proto: RunProtocol, vma: Double) -> CustomWorkout {
        let ordered = proto.blocks.sorted { $0.order < $1.order }

        let warmupStep = ordered.first.flatMap { wrappedStep($0, role: .warmup) }
        let cooldownStep = ordered.last.flatMap { wrappedStep($0, role: .cooldown) }
        let body = ordered.filter { !isWrapper($0, role: .warmup) && !isWrapper($0, role: .cooldown) }

        return CustomWorkout(
            activity: .running,
            location: .outdoor,
            displayName: proto.name,
            warmup: warmupStep.map { workoutStep($0, vma: vma) },
            blocks: body.map { intervalBlock($0, vma: vma) },
            cooldown: cooldownStep.map { workoutStep($0, vma: vma) }
        )
    }

    /// Distance (m) et durée (s) estimées du protocole pour la VMA donnée.
    static func totals(for proto: RunProtocol, vma: Double) -> (distance: Double, duration: TimeInterval) {
        var distance = 0.0, duration = 0.0
        for block in proto.blocks {
            for step in block.steps {
                let v = VMACalculator.speed(vma: vma, percent: step.percentVMA)
                for _ in 0..<block.iterations {
                    switch step.goalKind {
                    case .time:
                        duration += step.goalValue
                        distance += v * step.goalValue
                    case .distance:
                        distance += step.goalValue
                        duration += v > 0 ? step.goalValue / v : 0
                    }
                }
            }
        }
        return (distance, duration)
    }

    // MARK: - Mapping bas niveau (identique à l'ancien builder)

    private static func isWrapper(_ block: ProtocolBlock, role: StepRole) -> Bool {
        block.iterations == 1 && block.steps.count == 1 && block.steps.first?.role == role
    }

    private static func wrappedStep(_ block: ProtocolBlock, role: StepRole) -> ProtocolStep? {
        isWrapper(block, role: role) ? block.steps.first : nil
    }

    private static func goal(_ step: ProtocolStep) -> WorkoutGoal {
        switch step.goalKind {
        case .time:     return .time(step.goalValue, .seconds)
        case .distance: return .distance(step.goalValue, .meters)
        }
    }

    private static func speedAlert(_ step: ProtocolStep, vma: Double) -> SpeedRangeAlert? {
        guard step.targetsPace else { return nil }
        return SpeedRangeAlert(
            target: VMACalculator.targetSpeedRange(vma: vma, percent: step.percentVMA),
            metric: .current
        )
    }

    private static func intervalStep(_ step: ProtocolStep, vma: Double) -> IntervalStep {
        IntervalStep(step.role.isEffort ? .work : .recovery,
                     goal: goal(step),
                     alert: speedAlert(step, vma: vma))
    }

    private static func workoutStep(_ step: ProtocolStep, vma: Double) -> WorkoutStep {
        WorkoutStep(goal: goal(step), alert: speedAlert(step, vma: vma))
    }

    private static func intervalBlock(_ block: ProtocolBlock, vma: Double) -> IntervalBlock {
        let steps = block.steps.sorted { $0.order < $1.order }.map { intervalStep($0, vma: vma) }
        return IntervalBlock(steps: steps, iterations: block.iterations)
    }
}
