//
//  ProtocolValidator.swift
//  Lane04
//
//  Dernière ligne de défense avant de convertir des données persistées en une
//  séance WorkoutKit. Les bornes de l'UI sont une aide, pas une frontière de
//  confiance : une migration ou un store corrompu ne doit jamais programmer une
//  séance invalide sur la montre.
//

import Foundation

enum ProtocolValidationError: LocalizedError {
    case invalidVMA
    case invalidName
    case invalidBlockCount
    case invalidIterationCount
    case invalidStepCount
    case invalidGoal
    case invalidIntensity

    var errorDescription: String? {
        switch self {
        case .invalidVMA:            return "VMA HORS PLAGE SÛRE"
        case .invalidName:           return "NOM DE PROTOCOLE INVALIDE"
        case .invalidBlockCount:     return "STRUCTURE DE PROTOCOLE INVALIDE"
        case .invalidIterationCount: return "NOMBRE DE RÉPÉTITIONS INVALIDE"
        case .invalidStepCount:      return "NOMBRE DE PAS INVALIDE"
        case .invalidGoal:           return "OBJECTIF DE PAS INVALIDE"
        case .invalidIntensity:      return "INTENSITÉ HORS PLAGE SÛRE"
        }
    }
}

enum ProtocolValidator {
    static let vmaRange = 8.0...25.0
    static let intensityRange = 40.0...150.0
    static let maxBlocks = 16
    static let maxStepsPerBlock = 16
    static let iterationRange = 1...20
    static let timeGoalRange = 5.0...3_600.0
    static let distanceGoalRange = 50.0...20_000.0
    static let maxNameLength = 80

    static func validate(_ proto: RunProtocol, vma: Double) throws {
        guard vma.isFinite, vmaRange.contains(vma) else {
            throw ProtocolValidationError.invalidVMA
        }

        let name = proto.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasControlCharacter = proto.name.unicodeScalars.contains {
            CharacterSet.controlCharacters.contains($0)
        }
        guard !name.isEmpty, name.count <= maxNameLength, !hasControlCharacter else {
            throw ProtocolValidationError.invalidName
        }

        guard !proto.blocks.isEmpty, proto.blocks.count <= maxBlocks else {
            throw ProtocolValidationError.invalidBlockCount
        }

        for block in proto.blocks {
            guard iterationRange.contains(block.iterations) else {
                throw ProtocolValidationError.invalidIterationCount
            }
            guard !block.steps.isEmpty, block.steps.count <= maxStepsPerBlock else {
                throw ProtocolValidationError.invalidStepCount
            }

            for step in block.steps {
                guard step.goalValue.isFinite else {
                    throw ProtocolValidationError.invalidGoal
                }
                let goalRange = step.goalKind == .time ? timeGoalRange : distanceGoalRange
                guard goalRange.contains(step.goalValue) else {
                    throw ProtocolValidationError.invalidGoal
                }
                guard step.percentVMA.isFinite, intensityRange.contains(step.percentVMA) else {
                    throw ProtocolValidationError.invalidIntensity
                }
            }
        }
    }
}
