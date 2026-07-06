//
//  TemplateCatalog.swift
//  Lane04
//
//  Les 24 protocoles de départ, exprimés en modèles SwiftData (templates).
//  Nomenclature STRICTE (5 tags) — remap validé :
//    recovery + endurance + sortie longue  → [RECUP]
//    threshold + race                       → [SEUIL]
//    vo2max + côtes                         → [VMA]
//  (TEMPO et FARTLEK restent sans template pour l'instant — à décider.)
//
//  Un template n'est JAMAIS modifié : il se clone en [DRAFT] (voir Seeder.clone).
//

import Foundation

enum TemplateCatalog {

    /// Intensités de référence, en % VMA.
    private enum Pct {
        static let recov = 55.0, decr = 60.0, endur = 65.0, long = 70.0, active = 75.0
        static let mara = 80.0, semi = 85.0, thr = 88.0, tenK = 89.0
        static let vmaLong = 92.0, vmaLong2 = 95.0, vmaMid = 100.0, vmaMidUp = 103.0
        static let vmaShort = 105.0, vmaTop = 108.0
    }

    // MARK: Fabriques de pas / blocs

    private static func work(_ kind: GoalKind, _ value: Double, _ pct: Double) -> ProtocolStep {
        ProtocolStep(role: .work, goalKind: kind, goalValue: value, percentVMA: pct, targetsPace: true)
    }
    private static func rest(_ kind: GoalKind, _ value: Double, _ pct: Double = Pct.recov) -> ProtocolStep {
        ProtocolStep(role: .recovery, goalKind: kind, goalValue: value, percentVMA: pct)
    }
    private static func warmup(_ minutes: Double = 15) -> ProtocolBlock {
        ProtocolBlock(title: "WARM-UP", iterations: 1,
                      steps: [ProtocolStep(role: .warmup, goalKind: .time, goalValue: minutes * 60, percentVMA: Pct.endur)])
    }
    private static func cooldown(_ minutes: Double = 10) -> ProtocolBlock {
        ProtocolBlock(title: "COOL-DOWN", iterations: 1,
                      steps: [ProtocolStep(role: .cooldown, goalKind: .time, goalValue: minutes * 60, percentVMA: Pct.decr)])
    }
    private static func blk(_ title: String, _ iterations: Int, _ steps: [ProtocolStep]) -> ProtocolBlock {
        ProtocolBlock(title: title, iterations: iterations, steps: steps)
    }

    /// Assemble un template et fige l'ordre des blocs/pas.
    private static func make(_ name: String, _ discipline: Discipline, _ summary: String, _ blocks: [ProtocolBlock]) -> RunProtocol {
        for (bi, b) in blocks.enumerated() {
            b.order = bi
            for (si, s) in b.steps.enumerated() { s.order = si }
        }
        return RunProtocol(name: name, discipline: discipline, isTemplate: true, state: .ready, summary: summary, blocks: blocks)
    }

    private static let min = 60.0 // secondes par minute (lisibilité)

    // MARK: Le catalogue

    /// Construit une nouvelle instance des 24 templates (objets non insérés).
    static func templates() -> [RunProtocol] {
        [
            // ── RECUP ──────────────────────────────────────────────
            make("Décrassage 20 min", .recup, "20 min très souple pour éliminer après une séance dure.",
                 [blk("FOOTING", 1, [work(.time, 20*min, Pct.decr)])]),
            make("Footing récupération 30 min", .recup, "30 min faciles, respiration nasale, pour régénérer.",
                 [blk("FOOTING", 1, [work(.time, 30*min, 62)])]),
            make("Endurance fondamentale", .recup, "45 min en continu à allure facile pour développer le foncier.",
                 [blk("FOOTING", 1, [work(.time, 45*min, Pct.endur)])]),
            make("Sortie longue 1 h 15", .recup, "75 min à allure d'endurance pour le volume et l'économie.",
                 [blk("SORTIE LONGUE", 1, [work(.time, 75*min, Pct.long)])]),
            make("Endurance active 40 min", .recup, "40 min soutenues, haut de l'endurance fondamentale.",
                 [blk("FOOTING ACTIF", 1, [work(.time, 40*min, Pct.active)])]),
            make("Footing progressif 40 min", .recup, "Trois paliers de 15/15/10 min de plus en plus rapides.",
                 [blk("PROGRESSIF", 1, [work(.time, 15*min, Pct.endur), work(.time, 15*min, 72), work(.time, 10*min, Pct.active)])]),

            // ── SEUIL ──────────────────────────────────────────────
            make("Seuil continu 20 min", .seuil, "20 min d'une traite au seuil, tenue d'allure.",
                 [warmup(), blk("SEUIL CONTINU", 1, [work(.time, 20*min, Pct.semi)]), cooldown()]),
            make("Seuil 2 × 10 min", .seuil, "Deux blocs de 10 min soutenus, récup 3 min.",
                 [warmup(), blk("2 × 10 MIN", 2, [work(.time, 10*min, Pct.semi), rest(.time, 3*min, Pct.decr)]), cooldown()]),
            make("Seuil 3 × 8 min", .seuil, "Trois blocs de 8 min, récup 2 min. Volume au seuil.",
                 [warmup(), blk("3 × 8 MIN", 3, [work(.time, 8*min, 86), rest(.time, 2*min, Pct.decr)]), cooldown()]),
            make("Seuil 6 × 1000 m", .seuil, "Six kilomètres au seuil, récup courte 1 min.",
                 [warmup(), blk("6 × 1000 M", 6, [work(.distance, 1000, Pct.thr), rest(.time, 1*min, Pct.decr)]), cooldown()]),
            make("Allure 10 km 3 × 2000 m", .seuil, "Trois blocs de 2 km à allure 10 km, récup 2 min.",
                 [warmup(), blk("3 × 2000 M", 3, [work(.distance, 2000, Pct.tenK), rest(.time, 2*min, Pct.decr)]), cooldown()]),
            make("Allure semi 2 × 20 min", .seuil, "Deux blocs de 20 min à allure semi-marathon, récup 3 min.",
                 [warmup(), blk("2 × 20 MIN", 2, [work(.time, 20*min, Pct.semi), rest(.time, 3*min, Pct.decr)]), cooldown()]),
            make("Allure marathon 40 min", .seuil, "40 min en continu à l'allure cible marathon.",
                 [warmup(), blk("40 MIN", 1, [work(.time, 40*min, Pct.mara)]), cooldown()]),
            make("Mixte seuil + allure 10 km", .seuil, "20 min au seuil puis 3 × 1000 m à allure 10 km.",
                 [warmup(),
                  blk("BLOC SEUIL", 1, [work(.time, 20*min, Pct.semi), rest(.time, 3*min, Pct.decr)]),
                  blk("3 × 1000 M", 3, [work(.distance, 1000, Pct.tenK), rest(.time, 2*min, Pct.decr)]),
                  cooldown()]),

            // ── VMA ────────────────────────────────────────────────
            make("VMA courte 2 × 8 × 30/30", .vma, "Deux séries de 8 fractions 30 s vite / 30 s trot, récup 3 min.",
                 [warmup(),
                  blk("SÉRIE 1 · 8 × 30/30", 8, [work(.time, 30, Pct.vmaShort), rest(.time, 30)]),
                  blk("RÉCUP INTER-SÉRIE", 1, [rest(.time, 3*min, Pct.decr)]),
                  blk("SÉRIE 2 · 8 × 30/30", 8, [work(.time, 30, Pct.vmaShort), rest(.time, 30)]),
                  cooldown()]),
            make("VMA 2 × 9 × 30/15", .vma, "Fractions courtes très intenses, récup 15 s seulement.",
                 [warmup(),
                  blk("SÉRIE 1 · 9 × 30/15", 9, [work(.time, 30, Pct.vmaTop), rest(.time, 15)]),
                  blk("RÉCUP INTER-SÉRIE", 1, [rest(.time, 3*min, Pct.decr)]),
                  blk("SÉRIE 2 · 9 × 30/15", 9, [work(.time, 30, Pct.vmaTop), rest(.time, 15)]),
                  cooldown()]),
            make("VMA moyenne 8 × 400 m", .vma, "Huit fois 400 m à VMA, récup 2 min. Puissance aérobie.",
                 [warmup(), blk("8 × 400 M", 8, [work(.distance, 400, Pct.vmaMid), rest(.time, 2*min)]), cooldown()]),
            make("VMA 10 × 300 m", .vma, "Dix fractions vives de 300 m, récup 1 min.",
                 [warmup(), blk("10 × 300 M", 10, [work(.distance, 300, Pct.vmaMidUp), rest(.time, 1*min)]), cooldown()]),
            make("VMA longue 5 × 1000 m", .vma, "Cinq mille mètres à 92 % VMA, récup 2 min 30.",
                 [warmup(), blk("5 × 1000 M", 5, [work(.distance, 1000, Pct.vmaLong), rest(.time, 2.5*min)]), cooldown()]),
            make("VMA longue 6 × 3 min", .vma, "Six efforts de 3 min à 95 % VMA, récup 1 min 30.",
                 [warmup(), blk("6 × 3 MIN", 6, [work(.time, 3*min, Pct.vmaLong2), rest(.time, 1.5*min)]), cooldown()]),
            make("VMA pyramidale 200→800→200", .vma, "Pyramide 200/400/600/800/600/400/200, récup dégressive.",
                 [warmup(),
                  blk("PYRAMIDE", 1, [
                    work(.distance, 200, Pct.vmaShort), rest(.time, 45),
                    work(.distance, 400, Pct.vmaMidUp), rest(.time, 60),
                    work(.distance, 600, Pct.vmaMid),   rest(.time, 75),
                    work(.distance, 800, 98),           rest(.time, 90),
                    work(.distance, 600, Pct.vmaMid),   rest(.time, 75),
                    work(.distance, 400, Pct.vmaMidUp), rest(.time, 60),
                    work(.distance, 200, Pct.vmaShort)
                  ]),
                  cooldown()]),
            make("Côtes courtes 10 × 30 s", .vma, "Dix montées de 30 s explosives, récup descente 1 min.",
                 [warmup(), blk("10 × 30 S CÔTE", 10, [work(.time, 30, Pct.vmaShort), rest(.time, 1*min, Pct.decr)]), cooldown()]),
            make("Côtes moyennes 8 × 45 s", .vma, "Huit montées de 45 s puissantes, récup descente 1 min 15.",
                 [warmup(), blk("8 × 45 S CÔTE", 8, [work(.time, 45, Pct.vmaMidUp), rest(.time, 1.25*min, Pct.decr)]), cooldown()]),
            make("Côtes longues 6 × 1 min", .vma, "Six montées d'une minute, force et VO2max, récup 2 min.",
                 [warmup(), blk("6 × 1 MIN CÔTE", 6, [work(.time, 1*min, Pct.vmaMid), rest(.time, 2*min, Pct.decr)]), cooldown()])
        ]
    }
}
