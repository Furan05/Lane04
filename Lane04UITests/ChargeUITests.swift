//
//  ChargeUITests.swift
//  Lane04UITests
//
//  Validation visuelle de la CHARGE (TRIMP) sur ses 3 emplacements, sans
//  montre : (1) tuile CHARGE de l'éditeur, (2) bandeau CHARGE · 7 J / TOTAL
//  de LOGS (via le seam -uitest-seed-logs), (3) ligne CHARGE · SEMAINE du
//  CALENDAR. Captures exportables via `xcresulttool export attachments`.
//

import XCTest

final class ChargeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testChargeRendersInEditorLogsAndCalendar() {
        let app = XCUIApplication()
        // Store vierge + logs déterministes (le bandeau LOGS n'existe pas sans log).
        app.launchArguments += ["-uitest-skip-onboarding", "-uitest-reset-store", "-uitest-seed-logs"]
        app.launch()

        // 1 — ÉDITEUR : compiler un template VMA (protocole avec du contenu →
        // CHARGE > 0) puis ouvrir le [DRAFT] pour voir la tuile CHARGE.
        app.buttons["COMPILE FROM TEMPLATE"].tap()
        let vmaFolder = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH 'Style VMA'")).firstMatch
        XCTAssertTrue(vmaFolder.waitForExistence(timeout: 5), "Dossier de style VMA absent")
        vmaFolder.tap()
        let firstTemplate = app.scrollViews.buttons.firstMatch
        XCTAssertTrue(firstTemplate.waitForExistence(timeout: 5), "Aucun template dans le dossier")
        firstTemplate.tap()

        let draftBadge = app.staticTexts["[DRAFT]"].firstMatch
        XCTAssertTrue(draftBadge.waitForExistence(timeout: 5), "Aucun [DRAFT] compilé dans PROTOCOLS")
        draftBadge.tap()

        let chargeTile = app.staticTexts["CHARGE"].firstMatch
        XCTAssertTrue(chargeTile.waitForExistence(timeout: 5), "Tuile CHARGE absente de l'éditeur")
        attach(app, "CHARGE_EDITOR")

        // 2 — LOGS : le bandeau de cumul rend 7 J et TOTAL (valeurs seedées
        // distinctes : 45 dans la fenêtre, 105 au total).
        app.buttons["LOGS"].tap()
        XCTAssertTrue(app.staticTexts["CHARGE · 7 J"].waitForExistence(timeout: 5),
                      "Bandeau CHARGE · 7 J absent de LOGS")
        XCTAssertTrue(app.staticTexts["CHARGE · TOTAL"].exists, "Tuile CHARGE · TOTAL absente")
        XCTAssertTrue(app.staticTexts["45"].exists, "CHARGE · 7 J ≠ 45 (fenêtre glissante fausse)")
        XCTAssertTrue(app.staticTexts["105"].exists, "CHARGE · TOTAL ≠ 105 (cumul faux)")
        attach(app, "CHARGE_LOGS")

        // 3 — CALENDAR (vue SEMAINE) : la ligne CHARGE · SEMAINE est rendue,
        // séance planifiée ou pas (le zéro est une donnée).
        app.buttons["CALENDAR"].tap()
        XCTAssertTrue(app.staticTexts["CHARGE · SEMAINE"].waitForExistence(timeout: 5),
                      "Ligne CHARGE · SEMAINE absente du CALENDAR")
        attach(app, "CHARGE_CALENDAR")
    }
}
