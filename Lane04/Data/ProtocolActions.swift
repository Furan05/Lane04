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

    // MARK: - Défauts de construction manuelle
    //
    // %VMA calés sur la même grammaire que le catalogue (échauffement 65 /
    // récup 55 / retour 60 / effort = Z5). Un pas neuf démarre en durée (secondes).

    private enum Blank {
        static let warmupPercent = 65.0
        static let workPercent = 100.0     // Z5 / VMA — l'effort par défaut
        static let recovPercent = 55.0
        static let cooldownPercent = 60.0
        static let warmupSeconds = 15.0 * 60
        static let cooldownSeconds = 10.0 * 60
        static let workSeconds = 60.0
        static let recovSeconds = 60.0
        static let maxIterations = 20
    }

    // MARK: - Création vierge (« from scratch », comme un builder Nolio)

    /// Crée un protocole vierge `[DRAFT]` pré-monté : WARM-UP + 1 bloc d'effort
    /// (1× · un pas WORK) + COOL-DOWN. Le tag/nom/contenu sont ensuite éditables
    /// dans l'éditeur (chemin nominal, aucun flux parallèle). Inséré + sauvé.
    @discardableResult
    static func createBlank(in context: ModelContext) -> RunProtocol {
        let warmup = ProtocolBlock(title: "WARM-UP", iterations: 1, order: 0, steps: [
            ProtocolStep(role: .warmup, goalKind: .time, goalValue: Blank.warmupSeconds,
                         percentVMA: Blank.warmupPercent, order: 0)
        ])
        let work = ProtocolBlock(title: workBlockTitle(1), iterations: 1, order: 1, steps: [
            ProtocolStep(role: .work, goalKind: .time, goalValue: Blank.workSeconds,
                         percentVMA: Blank.workPercent, targetsPace: true, order: 0)
        ])
        let cooldown = ProtocolBlock(title: "COOL-DOWN", iterations: 1, order: 2, steps: [
            ProtocolStep(role: .cooldown, goalKind: .time, goalValue: Blank.cooldownSeconds,
                         percentVMA: Blank.cooldownPercent, order: 0)
        ])
        let proto = RunProtocol(name: "NEW PROTOCOL", discipline: .vma, state: .draft,
                                summary: "", blocks: [warmup, work, cooldown])
        context.insert(proto)
        try? context.save()
        return proto
    }

    // MARK: - Blocs

    /// Ajoute un bloc d'effort vierge (1× · un pas WORK) **avant le COOL-DOWN**
    /// s'il existe, sinon en fin. Renvoie le bloc créé.
    @discardableResult
    static func addWorkBlock(to proto: RunProtocol, in context: ModelContext) -> ProtocolBlock {
        var ordered = proto.blocks.sorted { $0.order < $1.order }
        let block = ProtocolBlock(title: workBlockTitle(workBlockCount(proto) + 1), iterations: 1, steps: [
            ProtocolStep(role: .work, goalKind: .time, goalValue: Blank.workSeconds,
                         percentVMA: Blank.workPercent, targetsPace: true, order: 0)
        ])
        block.owner = proto
        proto.blocks.append(block)
        if let cdIndex = ordered.firstIndex(where: isCooldownWrapper) {
            ordered.insert(block, at: cdIndex)
        } else {
            ordered.append(block)
        }
        renumber(ordered)
        try? context.save()
        return block
    }

    /// Supprime un bloc (et ses pas en cascade) puis renumérote. On garde toujours
    /// au moins un bloc dans le protocole.
    static func deleteBlock(_ block: ProtocolBlock, from proto: RunProtocol, in context: ModelContext) {
        guard proto.blocks.count > 1 else { return }
        let remaining = proto.blocks.sorted { $0.order < $1.order }.filter { $0.id != block.id }
        proto.blocks.removeAll { $0.id == block.id }
        context.delete(block)
        renumber(remaining)
        try? context.save()
    }

    /// Déplace un bloc d'un cran (−1 = vers le haut, +1 = vers le bas) en échangeant
    /// son ordre avec le voisin. No-op aux extrémités.
    static func moveBlock(_ block: ProtocolBlock, by delta: Int, in proto: RunProtocol, context: ModelContext) {
        let ordered = proto.blocks.sorted { $0.order < $1.order }
        guard let i = ordered.firstIndex(where: { $0.id == block.id }) else { return }
        let j = i + delta
        guard ordered.indices.contains(j) else { return }
        var reordered = ordered
        reordered.swapAt(i, j)
        renumber(reordered)
        try? context.save()
    }

    // MARK: - Pas

    /// Ajoute un pas (effort ou récup) à un bloc, en fin, puis renumérote les pas.
    @discardableResult
    static func addStep(to block: ProtocolBlock, role: StepRole, in context: ModelContext) -> ProtocolStep {
        let isEffort = role.isEffort
        let step = ProtocolStep(
            role: role, goalKind: .time,
            goalValue: isEffort ? Blank.workSeconds : Blank.recovSeconds,
            percentVMA: isEffort ? Blank.workPercent : Blank.recovPercent,
            targetsPace: isEffort, order: block.steps.count
        )
        step.block = block
        block.steps.append(step)
        renumberSteps(block)
        try? context.save()
        return step
    }

    /// Un protocole transmis puis modifié devient **périmé sur la montre**. On le
    /// marque `OUT OF SYNC` et on signale ses occurrences déjà programmées ; on ne
    /// réinjecte **jamais** automatiquement — réinjecter est la décision de l'athlète.
    /// L'occurrence reste `SCHEDULED` : la montre détient bien une séance, seulement
    /// ce n'est plus celle-ci.
    static func invalidateInjection(_ proto: RunProtocol, in context: ModelContext) {
        if proto.state == .synced { proto.state = .desynced }
        for plan in proto.plans where plan.state == .scheduled {
            plan.watchCopyStale = true
        }
        try? context.save()
    }

    /// Réordonne les pas **à l'intérieur d'un bloc** (glisser-déposer vertical).
    /// Sémantique de `Array.move(fromOffsets:toOffset:)` : `destination` est l'index
    /// d'insertion calculé AVANT retrait — c'est celle que fournit `onMove`.
    /// Les `order` redeviennent contigus 0…n et la persistance est immédiate.
    ///
    /// Le déplacement reste **intra-bloc** : un bloc « wrapper » (WARM-UP / COOL-DOWN)
    /// est défini par « 1 itération, 1 pas du bon rôle » (`isWrapper`) — y déposer un
    /// pas le ferait cesser d'être un wrapper et changerait la structure du protocole.
    static func moveStep(in block: ProtocolBlock, from source: IndexSet, to destination: Int,
                         context: ModelContext) {
        var ordered = block.steps.sorted { $0.order < $1.order }
        guard !ordered.isEmpty else { return }

        // Sémantique de `Array.move(fromOffsets:toOffset:)` réimplémentée à la main :
        // elle vient de SwiftUI, et la couche données ne dépend pas de l'UI.
        let moving = source.sorted().compactMap { ordered.indices.contains($0) ? ordered[$0] : nil }
        guard !moving.isEmpty else { return }
        let movingIDs = Set(moving.map(\.id))
        // Le pas devant lequel on insère, capturé AVANT retrait (d'où `toOffset`).
        let anchorID = destination < ordered.count ? ordered[destination].id : nil
        ordered.removeAll { movingIDs.contains($0.id) }
        let insertAt = anchorID.flatMap { id in ordered.firstIndex { $0.id == id } } ?? ordered.count
        ordered.insert(contentsOf: moving, at: insertAt)

        for (i, s) in ordered.enumerated() { s.order = i }
        if let proto = block.owner { invalidateInjection(proto, in: context) }
        try? context.save()
    }

    /// Variante glisser-déposer : place `step` **à** l'index `target` dans la séquence
    /// finale (0 = en tête). Contrairement à `onMove`, `target` s'entend APRÈS retrait
    /// — c'est ce que produit un dépôt sur une position visible. No-op si le pas
    /// n'appartient pas au bloc ou s'il ne bouge pas.
    @discardableResult
    static func moveStep(_ step: ProtocolStep, to target: Int, in block: ProtocolBlock,
                         context: ModelContext) -> Bool {
        var ordered = block.steps.sorted { $0.order < $1.order }
        guard let from = ordered.firstIndex(where: { $0.id == step.id }) else { return false }
        let to = min(max(target, 0), ordered.count - 1)
        guard to != from else { return false }
        let moved = ordered.remove(at: from)
        ordered.insert(moved, at: to)
        for (i, s) in ordered.enumerated() { s.order = i }
        // Invalidation portée par le déplacement lui-même : un appelant ne peut pas
        // réordonner en oubliant de périmer la copie de la montre.
        if let proto = block.owner { invalidateInjection(proto, in: context) }
        try? context.save()
        return true
    }

    /// Supprime un pas d'un bloc puis renumérote. Un bloc conserve toujours **au
    /// moins un pas** (un bloc vide n'a pas de sens à injecter).
    static func deleteStep(_ step: ProtocolStep, from block: ProtocolBlock, in context: ModelContext) {
        guard block.steps.count > 1 else { return }
        block.steps.removeAll { $0.id == step.id }
        context.delete(step)
        renumberSteps(block)
        try? context.save()
    }

    // MARK: - Helpers d'ordre (contigus 0…n, comme le catalogue)

    /// Un bloc « wrapper » = 1× et un seul pas d'échauffement/retour (convention modèle).
    static func isWarmupWrapper(_ b: ProtocolBlock) -> Bool { isWrapper(b, .warmup) }
    static func isCooldownWrapper(_ b: ProtocolBlock) -> Bool { isWrapper(b, .cooldown) }

    private static func isWrapper(_ b: ProtocolBlock, _ role: StepRole) -> Bool {
        b.iterations == 1 && b.steps.count == 1 && b.steps.first?.role == role
    }

    private static func workBlockCount(_ proto: RunProtocol) -> Int {
        proto.blocks.filter { !isWarmupWrapper($0) && !isCooldownWrapper($0) }.count
    }

    private static func workBlockTitle(_ n: Int) -> String {
        String(format: "BLOC %02d", n)
    }

    private static func renumber(_ blocks: [ProtocolBlock]) {
        for (i, b) in blocks.enumerated() { b.order = i }
    }

    private static func renumberSteps(_ block: ProtocolBlock) {
        for (i, s) in block.steps.sorted(by: { $0.order < $1.order }).enumerated() { s.order = i }
    }

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

    /// Un protocole portant une séance déjà programmée reste localement disponible :
    /// le supprimer ferait disparaître la référence alors que la séance existe encore
    /// sur la montre.
    static func canDelete(_ proto: RunProtocol) -> Bool {
        !proto.plans.contains { $0.state == .scheduled }
    }

    /// Supprime un protocole (et ses blocs/pas en cascade). **Ne touche jamais les
    /// `RunLog`** : la trace de transmission est de l'historique, elle survit.
    @discardableResult
    static func delete(_ proto: RunProtocol, in context: ModelContext) -> Bool {
        guard canDelete(proto) else { return false }
        context.delete(proto)
        try? context.save()
        return true
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
