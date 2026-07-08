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
    /// Descripteur français (langue de lecture, §02) — sous-titre du dossier de style.
    var subtitle: String {
        switch self {
        case .vma:     return "Vitesse maximale aérobie"
        case .seuil:   return "Allure seuil"
        case .tempo:   return "Endurance active"
        case .fartlek: return "Jeu d'allures"
        case .recup:   return "Récupération"
        }
    }
    /// Contour thermique sur la rampe curatée (§06) : VMA=Z5 (EMBER) → RECUP=Z1 (CRYO).
    var tint: Color {
        switch self {
        case .vma:     return .zoneZ5
        case .seuil:   return .zoneZ4
        case .tempo:   return .zoneZ3
        case .fartlek: return .zoneZ2
        case .recup:   return .zoneZ1
        }
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
    case ready = "TRAINING READY"
    case synced = "SYNCED"
    case fault = "SYNC FAULT"
}

/// Provenance de la VMA → l'instrument distingue la mesure de l'estimation.
enum VMAProvenance: String, Codable {
    case calibrated    // test 6 min (demi-Cooper) saisi
    case estimated     // dérivée d'une course récente
    case uncalibrated  // jamais renseignée (valeur par défaut)
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
    /// Vrai = protocole de test VMA (effort maximal sans cible d'allure) → badge [TEST].
    var isTest: Bool = false
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
        isTest: Bool = false,
        state: ProtocolState = .draft,
        createdAt: Date = .now,
        summary: String = "",
        blocks: [ProtocolBlock] = []
    ) {
        self.id = id
        self.name = name
        self.discipline = discipline
        self.isTemplate = isTemplate
        self.isTest = isTest
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
    /// VMA en km/h. Défaut 14.0 (coureur médian ; un défaut flatteur fausserait
    /// la première lecture des zones).
    var vma: Double
    /// D'où vient la VMA : test mesuré, estimation course, ou jamais renseignée.
    var provenance: VMAProvenance = VMAProvenance.uncalibrated
    var updatedAt: Date

    init(id: UUID = UUID(), vma: Double = 14.0, provenance: VMAProvenance = .uncalibrated, updatedAt: Date = .now) {
        self.id = id
        self.vma = vma
        self.provenance = provenance
        self.updatedAt = updatedAt
    }
}

/// Une entrée de LOGS = **trace de transmission** (injection réussie), PAS une séance
/// courue. On n'affiche que ce qu'on sait : tag + nom du protocole + horodatage.
/// Les distances/durées sont celles du protocole *prévu* — ne jamais les présenter
/// comme exécutées (voir docs/session-notes.md ; lecture HealthKit réelle = V2).
@Model
final class RunLog {
    var id: UUID
    var date: Date
    var discipline: Discipline
    var protocolName: String
    var distanceMeters: Double
    var durationSeconds: Double

    init(
        id: UUID = UUID(),
        date: Date = .now,
        discipline: Discipline,
        protocolName: String = "",
        distanceMeters: Double,
        durationSeconds: Double
    ) {
        self.id = id
        self.date = date
        self.discipline = discipline
        self.protocolName = protocolName
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
