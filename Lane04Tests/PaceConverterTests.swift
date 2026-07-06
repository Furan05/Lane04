//
//  PaceConverterTests.swift
//  Lane04Tests
//
//  Created by François.Dubois on 03/07/2026.
//

import Testing
import Foundation
@testable import Lane04

struct PaceConverterTests {

    /// Tolérance de comparaison sur les vitesses (m/s).
    private static let epsilon = 1e-6

    // MARK: - Conversion allure -> vitesse

    @Test func speedFromComponents_fiveMinPerKm() {
        // 5:00/km = 300 s/km -> 1000/300 ≈ 3.3333 m/s
        let speed = PaceConverter.speed(minutes: 5, seconds: 0)
        #expect(speed != nil)
        #expect(abs(speed! - (1000.0 / 300.0)) < Self.epsilon)
    }

    @Test func speedFromComponents_withSeconds() {
        // 4:30/km = 270 s/km -> 1000/270 ≈ 3.7037 m/s
        let speed = PaceConverter.speed(minutes: 4, seconds: 30)
        #expect(abs((speed ?? 0) - (1000.0 / 270.0)) < Self.epsilon)
    }

    @Test func speedFromComponents_zeroPaceIsNil() {
        #expect(PaceConverter.speed(minutes: 0, seconds: 0) == nil)
    }

    // MARK: - Parsing de chaîne "m:ss"

    @Test func speedFromString_valid() {
        let speed = PaceConverter.speed(fromPace: "4:30")
        #expect(abs((speed ?? 0) - (1000.0 / 270.0)) < Self.epsilon)
    }

    @Test func speedFromString_toleratesWhitespace() {
        let speed = PaceConverter.speed(fromPace: " 5 : 00 ")
        #expect(abs((speed ?? 0) - (1000.0 / 300.0)) < Self.epsilon)
    }

    @Test(arguments: ["abc", "4:60", "4", "4:30:00", "", ":"])
    func speedFromString_invalidReturnsNil(_ pace: String) {
        #expect(PaceConverter.speed(fromPace: pace) == nil)
    }

    // MARK: - Plage de vitesse cible (marge ±5 s/km)

    @Test func targetSpeedRange_appliesFiveSecondMargin() throws {
        // Allure cible 4:30 = 270 s/km, marge ±5 s.
        //  - borne basse de vitesse = allure la plus lente (275 s) -> 1000/275
        //  - borne haute de vitesse = allure la plus rapide (265 s) -> 1000/265
        let range = try #require(PaceConverter.targetSpeedRange(minutes: 4, seconds: 30))

        let lower = range.lowerBound.converted(to: .metersPerSecond).value
        let upper = range.upperBound.converted(to: .metersPerSecond).value

        #expect(abs(lower - (1000.0 / 275.0)) < Self.epsilon)
        #expect(abs(upper - (1000.0 / 265.0)) < Self.epsilon)
        #expect(lower < upper)
    }

    @Test func targetSpeedRange_isCenteredOnTargetPace() throws {
        // La vitesse cible doit tomber à l'intérieur de la plage.
        let target = try #require(PaceConverter.speed(minutes: 4, seconds: 30))
        let range = try #require(PaceConverter.targetSpeedRange(minutes: 4, seconds: 30))

        let lower = range.lowerBound.converted(to: .metersPerSecond).value
        let upper = range.upperBound.converted(to: .metersPerSecond).value

        #expect(target > lower)
        #expect(target < upper)
    }

    @Test func targetSpeedRange_nilWhenPaceWithinTolerance() {
        // 0:03 <= 5 s de marge -> la borne rapide serait <= 0, donc nil.
        #expect(PaceConverter.targetSpeedRange(minutes: 0, seconds: 3) == nil)
        #expect(PaceConverter.targetSpeedRange(minutes: 0, seconds: 5) == nil)
    }

    @Test func targetSpeedRange_fromStringMatchesComponents() throws {
        let fromString = try #require(PaceConverter.targetSpeedRange(fromPace: "4:30"))
        let fromComponents = try #require(PaceConverter.targetSpeedRange(minutes: 4, seconds: 30))
        #expect(fromString.lowerBound == fromComponents.lowerBound)
        #expect(fromString.upperBound == fromComponents.upperBound)
    }
}
