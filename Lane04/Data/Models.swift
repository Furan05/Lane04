//
//  Models.swift
//  Lane04
//
//  Couche de persistance SwiftData : protocoles (templates + [DRAFT] éditables),
//  profil OPERATOR, logs. Réglages CONSOLE simples → @AppStorage (voir Settings.swift).
//  Référence : docs/data-model.md, nomenclature stricte du case study.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Nomenclature (STRICTE — 5 tags, aucune 6e sans accord)

/// Filière physiologique d'un protocole. Tag `[BRACKET]`, contour thermique.
enum Discipline: String, Codable, CaseIterable, Identifiable {
    case vma = "VMA"
    case seuil = "SEUIL"
    case tempo = "TEMPO"
    case fartlek = "FARTLEK"
    case recup = "RECUP"

    var id: String { rawValue }
    /// Rendu du tag, crochets inclus (les crochets font partie du glyphe, §06).
    var tag: String { "[\(rawValue)]" }
    /// Contour thermique : spectre EMBER (VMA) → CRYO (RECUP), §06.
    var tint: Color {
        let spectrum: [Discipline] = [.vma, .seuil, .tempo, .fartlek, .recup]
        let i = spectrum.firstIndex(of: self) ?? 0
        return Color.ember.blended(with: .cryo, t: Double(i) / Double(spectrum.count - 1))
    }
}

/// Rôle d'un pas. Le vocabulaire système reste anglais (§02).
enum StepRole: String, Codable {
    case warmup = "WARM-UP"
    case work = "WORK"
    case recovery = "RECOVERY"
    case cooldown = "COOL-DOWN"

    var isEffort: Bool { self == .work }
}

/// Nature de l'objectif d'un pas.
enum GoalKind: String, Codable {
    case time      // goalValue en secondes
    case distance  // goalValue en mètres
}

/// État système d'un protocole → statut `[BRACKET]`.
enum ProtocolState: String, Codable {
    case draft = "DRAFT"
    case ready = "PAYLOAD READY"
    case synced = "SYNCED"
    case fault = "SYNC FAULT"
}

// MARK: - Modèles

/// Un protocole compilé : template réutilisable ou copie `[DRAFT]` éditable.
@Model
final class RunProtocol {
    var id: UUID
    var name: String
    var discipline: Discipline
    /// Vrai = template de départ (clonable via COMPILE FROM TEMPLATE), non figé.
    var isTemplate: Bool
    var state: ProtocolState
    var createdAt: Date
    /// Résumé éditorial (français, langue de lecture).
    var summary: String

    @Relationship(deleteRule: .cascade, inverse: \ProtocolBlock.owner)
    var blocks: [ProtocolBlock]

    init(
        id: UUID = UUID(),
        name: String,
        discipline: Discipline,
        isTemplate: Bool = false,
        state: ProtocolState = .draft,
        createdAt: Date = .now,
        summary: String = "",
        blocks: [ProtocolBlock] = []
    ) {
        self.id = id
        self.name = name
        self.discipline = discipline
        self.isTemplate = isTemplate
        self.state = state
        self.createdAt = createdAt
        self.summary = summary
        self.blocks = blocks
    }
}

/// Un bloc répété N fois (ex. 8 × (30 s effort / 30 s récup)).
@Model
final class ProtocolBlock {
    var id: UUID
    var title: String
    var iterations: Int
    var order: Int
    var owner: RunProtocol?

    @Relationship(deleteRule: .cascade, inverse: \ProtocolStep.block)
    var steps: [ProtocolStep]

    init(
        id: UUID = UUID(),
        title: String,
        iterations: Int = 1,
        order: Int = 0,
        steps: [ProtocolStep] = []
    ) {
        self.id = id
        self.title = title
        self.iterations = iterations
        self.order = order
        self.steps = steps
    }
}

/// Un pas élémentaire, intensité exprimée en % de la VMA.
@Model
final class ProtocolStep {
    var id: UUID
    var role: StepRole
    var goalKind: GoalKind
    /// Secondes si `.time`, mètres si `.distance`.
    var goalValue: Double
    var percentVMA: Double
    /// Si vrai, un objectif d'allure (SpeedRangeAlert) est posé sur le pas.
    var targetsPace: Bool
    var order: Int
    var block: ProtocolBlock?

    init(
        id: UUID = UUID(),
        role: StepRole,
        goalKind: GoalKind,
        goalValue: Double,
        percentVMA: Double,
        targetsPace: Bool = false,
        order: Int = 0
    ) {
        self.id = id
        self.role = role
        self.goalKind = goalKind
        self.goalValue = goalValue
        self.percentVMA = percentVMA
        self.targetsPace = targetsPace
        self.order = order
    }
}

/// Profil physiologique de l'OPERATOR : VMA saisie, zones dérivées.
@Model
final class OperatorProfile {
    var id: UUID
    /// VMA en km/h.
    var vma: Double
    var updatedAt: Date

    init(id: UUID = UUID(), vma: Double = 16.0, updatedAt: Date = .now) {
        self.id = id
        self.vma = vma
        self.updatedAt = updatedAt
    }
}

/// Une entrée de LOGS : séance exécutée (données brutes, tabulaires).
@Model
final class RunLog {
    var id: UUID
    var date: Date
    var discipline: Discipline
    var distanceMeters: Double
    var durationSeconds: Double

    init(
        id: UUID = UUID(),
        date: Date = .now,
        discipline: Discipline,
        distanceMeters: Double,
        durationSeconds: Double
    ) {
        self.id = id
        self.date = date
        self.discipline = discipline
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
    }
}

// MARK: - Schéma

enum LaneSchema {
    static let models: [any PersistentModel.Type] = [
        RunProtocol.self,
        ProtocolBlock.self,
        ProtocolStep.self,
        OperatorProfile.self,
        RunLog.self
    ]
}
