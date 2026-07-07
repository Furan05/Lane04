//
//  TabBarUITests.swift
//  Lane04UITests
//
//  Bottom bar custom LANE 04 (remplace la TabView native). Vérifie : navigation
//  entre les 3 onglets, état sélectionné annoncé à VoiceOver, raccourci OPERATOR
//  → éditeur toujours fonctionnel (la bar suit le router), et barre désactivée
//  pendant une transmission (TX). Captures des états ACTIVE/INACTIVE.
//

import XCTest

final class TabBarUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ extraArgs: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-skip-onboarding"] + extraArgs
        app.launch()
        return app
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Navigation entre les 3 onglets via la bottom bar custom + captures
    /// ACTIVE/INACTIVE (PROTOCOLS actif au démarrage, puis CONSOLE actif).
    @MainActor
    func testNavigatesBetweenThreeTabs() {
        let app = launch()

        // PROTOCOLS actif au démarrage (barre indicatrice sous le mot).
        XCTAssertTrue(app.buttons["COMPILE FROM TEMPLATE"].waitForExistence(timeout: 5),
                      "Écran PROTOCOLS absent au démarrage")
        attach(app, "TAB_PROTOCOLS_ACTIVE")

        // → LOGS
        app.buttons["LOGS"].tap()
        XCTAssertTrue(app.staticTexts["LOGS"].waitForExistence(timeout: 5),
                      "Écran LOGS non affiché après tap LOGS")

        // → CONSOLE
        app.buttons["CONSOLE"].tap()
        XCTAssertTrue(app.staticTexts["OPERATOR"].waitForExistence(timeout: 5),
                      "Écran CONSOLE non affiché après tap CONSOLE")
        attach(app, "TAB_CONSOLE_ACTIVE")

        // → retour PROTOCOLS (l'onglet reste pilotable dans les deux sens).
        app.buttons["PROTOCOLS"].tap()
        XCTAssertTrue(app.buttons["COMPILE FROM TEMPLATE"].waitForExistence(timeout: 5),
                      "Retour sur PROTOCOLS échoué")
    }

    /// L'état sélectionné est annoncé (trait `.isSelected`) — la perte de la
    /// TabView native ne doit rien coûter à VoiceOver.
    @MainActor
    func testSelectedStateIsAnnounced() {
        let app = launch()

        XCTAssertTrue(app.buttons["PROTOCOLS"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["PROTOCOLS"].isSelected,
                      "PROTOCOLS devrait être l'onglet sélectionné au démarrage")

        app.buttons["LOGS"].tap()
        XCTAssertTrue(app.buttons["LOGS"].isSelected,
                      "LOGS devrait être sélectionné après le tap")
        XCTAssertFalse(app.buttons["PROTOCOLS"].isSelected,
                       "PROTOCOLS ne devrait plus être sélectionné")
    }

    /// Le raccourci OPERATOR → éditeur (chemin nominal via router) marche toujours
    /// avec la bar custom, et la bar reflète le basculement sur PROTOCOLS.
    @MainActor
    func testOperatorShortcutStillReachesEditor() {
        let app = launch()

        app.buttons["CONSOLE"].tap()
        let operatorRow = app.staticTexts["OPERATOR"].firstMatch
        XCTAssertTrue(operatorRow.waitForExistence(timeout: 5), "OPERATOR introuvable")
        operatorRow.tap()

        let recours = app.buttons["Préparer le protocole de test VMA"]
        XCTAssertTrue(recours.waitForExistence(timeout: 5), "Recours OPERATOR absent")
        recours.tap()

        // Chemin nominal : l'éditeur s'ouvre ET la bar bascule sur PROTOCOLS.
        XCTAssertTrue(app.staticTexts["PROTOCOL"].firstMatch.waitForExistence(timeout: 5),
                      "L'éditeur PROTOCOL ne s'est pas ouvert via le raccourci")
        XCTAssertTrue(app.buttons["PROTOCOLS"].isSelected,
                      "L'onglet PROTOCOLS devrait être sélectionné après le raccourci")
    }

    /// Pendant une transmission, la bottom bar chute à 40 % et ignore les taps
    /// (cohérent avec l'écran qui chute à 40 % pendant ARM).
    @MainActor
    func testBarDisabledDuringTransmission() {
        let app = launch(["-uitest-simulate-tx"])

        XCTAssertTrue(app.buttons["COMPILE FROM TEMPLATE"].waitForExistence(timeout: 5),
                      "Écran PROTOCOLS absent")
        attach(app, "TAB_DISABLED_TX")   // bar à 40 %

        // La bar ignore les taps (allowsHitTesting(false)) : taper CONSOLE ne
        // doit pas naviguer — on reste sur PROTOCOLS.
        app.buttons["CONSOLE"].tap()
        XCTAssertFalse(app.staticTexts["OPERATOR"].waitForExistence(timeout: 2),
                       "La bar ne devrait pas naviguer vers CONSOLE pendant TX")
        XCTAssertTrue(app.buttons["COMPILE FROM TEMPLATE"].exists,
                      "On devrait rester sur PROTOCOLS pendant TX")
    }
}
