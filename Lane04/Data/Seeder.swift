//
//  Seeder.swift
//  Lane04
//
//  Amorçage idempotent de la base + clonage de templates.
//  Règle : un template n'est JAMAIS modifié — on le clone en [DRAFT] éditable.
//

import Foundation
import SwiftData

enum Seeder {

    /// Insère les templates une seule fois, si la base est vide.
    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<RunProtocol>())) ?? 0
        guard existing == 0 else { return }
        for template in TemplateCatalog.templates() {
            context.insert(template)
        }
        try? context.save()
    }

    /// Garantit l'existence d'un unique profil OPERATOR (idempotent).
    @MainActor
    static func ensureOperatorProfile(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<OperatorProfile>())) ?? 0
        guard count == 0 else { return }
        context.insert(OperatorProfile()) // vma 14.0, provenance .uncalibrated
        try? context.save()
    }

    #if DEBUG
    /// Seam de test UI (`-uitest-seed-logs`) : deux traces de transmission
    /// déterministes — une dans la fenêtre 7 J glissants, une hors fenêtre —
    /// pour rendre le bandeau CHARGE de LOGS (7 J ≠ TOTAL) sans montre.
    @MainActor
    static func seedUITestLogs(_ context: ModelContext) {
        let calendar = Calendar.current
        context.insert(RunLog(
            date: calendar.date(byAdding: .day, value: -1, to: .now) ?? .now,
            discipline: .vma, protocolName: "8 × 30/30",
            distanceMeters: 6200, durationSeconds: 2160, load: 45))
        context.insert(RunLog(
            date: calendar.date(byAdding: .day, value: -30, to: .now) ?? .now,
            discipline: .seuil, protocolName: "SEUIL 2 × 15",
            distanceMeters: 9800, durationSeconds: 3300, load: 60))
        try? context.save()
    }
    #endif

    /// Copie profonde d'un template vers un nouveau protocole `[DRAFT]` éditable.
    /// Le template source reste intact. L'objet retourné n'est pas inséré.
    static func clone(_ template: RunProtocol) -> RunProtocol {
        let copy = RunProtocol(
            name: template.name,
            discipline: template.discipline,
            isTemplate: false,
            isTest: template.isTest,
            state: .draft,
            summary: template.summary,
            blocks: template.blocks
                .sorted { $0.order < $1.order }
                .map { block in
                    ProtocolBlock(
                        title: block.title,
                        iterations: block.iterations,
                        order: block.order,
                        steps: block.steps
                            .sorted { $0.order < $1.order }
                            .map { step in
                                ProtocolStep(
                                    role: step.role,
                                    goalKind: step.goalKind,
                                    goalValue: step.goalValue,
                                    percentVMA: step.percentVMA,
                                    targetsPace: step.targetsPace,
                                    order: step.order
                                )
                            }
                    )
                }
        )
        return copy
    }
}
