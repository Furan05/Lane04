//
//  GarminPayloadTests.swift
//  Lane04Tests
//
//  Le payload Garmin est le contrat JSON entre l'app et le relais (backend/) :
//  ordre des blocs/pas, unités natives, jour calendaire local. Le relais
//  re-valide et traduit ensuite vers la Training API — ici on fige ce que
//  le téléphone émet.
//

import Foundation
import Testing
@testable import Lane04

struct GarminPayloadTests {

    private func makeProto() -> RunProtocol {
        // Ordres volontairement mélangés : le payload doit trier par `order`.
        let recovery = ProtocolStep(role: .recovery, goalKind: .time, goalValue: 30,
                                    percentVMA: 55, order: 1)
        let work = ProtocolStep(role: .work, goalKind: .time, goalValue: 30,
                                percentVMA: 105, targetsPace: true, order: 0)
        let body = ProtocolBlock(title: "CORPS", iterations: 8, order: 1,
                                 steps: [recovery, work])
        let warmup = ProtocolBlock(title: "WARM-UP", iterations: 1, order: 0, steps: [
            ProtocolStep(role: .warmup, goalKind: .distance, goalValue: 2000, percentVMA: 60, order: 0)
        ])
        return RunProtocol(name: "8 × 30/30", discipline: .vma, blocks: [body, warmup])
    }

    @Test func payloadSortsBlocksAndStepsByOrder() {
        let payload = GarminWorkoutPayload(proto: makeProto(), vma: 16, at: .now)

        #expect(payload.blocks.map(\.title) == ["WARM-UP", "CORPS"])
        #expect(payload.blocks[1].steps.map(\.role) == ["WORK", "RECOVERY"])
    }

    @Test func payloadCarriesSystemVocabulary() {
        let payload = GarminWorkoutPayload(proto: makeProto(), vma: 16, at: .now)

        #expect(payload.name == "8 × 30/30")
        #expect(payload.discipline == "VMA")
        #expect(payload.vma == 16)

        let warmupStep = payload.blocks[0].steps[0]
        #expect(warmupStep.role == "WARM-UP")
        #expect(warmupStep.goalKind == "DISTANCE")
        #expect(warmupStep.goalValue == 2000)

        let workStep = payload.blocks[1].steps[0]
        #expect(workStep.goalKind == "TIME")
        #expect(workStep.percentVMA == 105)
        #expect(workStep.targetsPace)
    }

    @Test func scheduledDateIsLocalCalendarDay() {
        // Le schedule Garmin est un jour, pas un instant : le payload porte le
        // jour calendaire LOCAL, formaté côté client pour éviter toute dérive
        // de fuseau entre le téléphone et le relais.
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 20
        components.hour = 7
        let date = Calendar.current.date(from: components)!

        let payload = GarminWorkoutPayload(proto: makeProto(), vma: 16, at: date)
        #expect(payload.scheduledDate == "2026-07-20")
    }

    @Test func payloadEncodesToStableJSONKeys() throws {
        let payload = GarminWorkoutPayload(proto: makeProto(), vma: 16, at: .now)
        let data = try JSONEncoder().encode(payload)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        // Clés du contrat consommé par backend/src/mapper.mjs.
        #expect(Set(object.keys) == ["name", "scheduledDate", "vma", "discipline", "blocks"])
        let blocks = try #require(object["blocks"] as? [[String: Any]])
        let firstStep = try #require((blocks[0]["steps"] as? [[String: Any]])?.first)
        #expect(Set(firstStep.keys) == ["role", "goalKind", "goalValue", "percentVMA", "targetsPace"])
    }
}
