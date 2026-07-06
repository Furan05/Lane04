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
}
