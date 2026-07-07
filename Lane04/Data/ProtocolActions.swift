//
//  ProtocolActions.swift
//  Lane04
//
//  Actions sur les protocoles de l'utilisateur (hors UI, testables).
//  Les templates ne passent jamais par ici : le catalogue est le socle.
//

import Foundation
import SwiftData

enum ProtocolActions {

    /// Duplique un protocole en un nouveau `[DRAFT]` « NOM_COPY » — geste d'itération,
    /// non destructif : l'original est intact, les blocs/pas sont copiés en profondeur.
    @discardableResult
    static func duplicate(_ proto: RunProtocol, in context: ModelContext) -> RunProtocol {
        let copy = Seeder.clone(proto)   // isTemplate = false, state = .draft, copie profonde
        copy.name = "\(proto.name)_COPY"
        context.insert(copy)
        try? context.save()
        return copy
    }

    /// Supprime un protocole (et ses blocs/pas en cascade). **Ne touche jamais les
    /// `RunLog`** : la trace de transmission est de l'historique, elle survit.
    static func delete(_ proto: RunProtocol, in context: ModelContext) {
        context.delete(proto)
        try? context.save()
    }

    /// Prépare le protocole de test VMA pour injection via le chemin nominal
    /// (éditeur → hero INJECT TRAINING). **Idempotent** : réutilise un `TEST_VMA`
    /// déjà cloné ([DRAFT] ou [SYNCED], pas encore couru) s'il en existe un —
    /// jamais d'accumulation de tests fantômes. Sinon clone le template.
    /// Réutilise `Seeder.clone`, aucune logique d'injection nouvelle.
    @discardableResult
    static func prepareTestVMA(in context: ModelContext) -> RunProtocol? {
        // 1. Un test déjà cloné par l'utilisateur ? (le plus récent d'abord)
        let existing = FetchDescriptor<RunProtocol>(
            predicate: #Predicate { !$0.isTemplate && $0.isTest },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        if let found = try? context.fetch(existing), let test = found.first {
            return test
        }
        // 2. Sinon, cloner le template TEST_VMA en [DRAFT].
        let templateFetch = FetchDescriptor<RunProtocol>(
            predicate: #Predicate { $0.isTemplate && $0.isTest }
        )
        guard let template = (try? context.fetch(templateFetch))?.first else { return nil }
        let draft = Seeder.clone(template)
        context.insert(draft)
        try? context.save()
        return draft
    }
}
