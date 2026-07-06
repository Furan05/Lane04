//
//  CalibrationShortcutUITests.swift
//  Lane04UITests
//
//  Pont CALIBRATION → TEST_VMA : le raccourci de la voie MESURE (OPERATOR) doit
//  ouvrir l'éditeur du test par le chemin nominal (hero INJECT PAYLOAD), et
//  laisser l'aplat unique de l'écran sur CALIBRATE (le recours est un contour).
//

import XCTest

final class CalibrationShortcutUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Navigue CONSOLE → OPERATOR ; renvoie l'app prête sur l'écran OPERATOR.
    @MainActor
    private func launchToOperator() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-skip-onboarding"]
        app.launch()

        app.buttons["CONSOLE"].firstMatch.tap()
        let operatorRow = app.staticTexts["OPERATOR"].firstMatch
        XCTAssertTrue(operatorRow.waitForExistence(timeout: 5), "OPERATOR introuvable")
        operatorRow.tap()
        return app
    }

    @MainActor
    func testShortcutOpensTestEditorViaNominalPath() throws {
        let app = launchToOperator()

        // La voie MESURE est active par défaut : le recours doit être présent.
        let recours = app.buttons["Préparer le protocole de test VMA"]
        XCTAssertTrue(recours.waitForExistence(timeout: 5), "Recours TEST_VMA absent en MESURE")

        recours.tap()

        // Chemin nominal : on arrive sur l'éditeur (titre PROTOCOL) — pas de flux parallèle.
        XCTAssertTrue(app.staticTexts["PROTOCOL"].firstMatch.waitForExistence(timeout: 5),
                      "L'éditeur PROTOCOL ne s'est pas ouvert")
    }

    @MainActor
    func testOperatorCalibrationScreenshot() throws {
        let app = launchToOperator()
        XCTAssertTrue(app.buttons["Préparer le protocole de test VMA"].waitForExistence(timeout: 5))

        // Capture pour vérification visuelle de l'aplat unique (VALIDATE ember,
        // recours en contour).
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "OPERATOR_CALIBRATION"
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testOnboardingCalibrationHasSameRecours() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-force-onboarding"]
        app.launch()

        // Écran 01 → CALIBRATION (écran 02).
        app.buttons["INITIALIZE"].firstMatch.tap()

        // Le recours doit exister aussi dans l'onboarding (voie MESURE par défaut).
        let recours = app.buttons["Préparer le protocole de test VMA"]
        XCTAssertTrue(recours.waitForExistence(timeout: 5), "Recours TEST_VMA absent en onboarding")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "ONBOARDING_CALIBRATION"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
