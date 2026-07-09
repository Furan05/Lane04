//
//  CalendarUITests.swift
//  Lane04UITests
//
//  Onglet CALENDAR : navigation vers le calendrier, planification d'une séance
//  (PLAN A TRAINING → choix d'un template → apparaît dans l'agenda du jour).
//

import XCTest

final class CalendarUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-skip-onboarding"]
        app.launch()
        return app
    }

    @MainActor
    func testCalendarTabAndPlanASession() {
        let app = launch()

        // 4e onglet CALENDAR (identifiant = mot brut).
        let calendarTab = app.buttons["CALENDAR"]
        XCTAssertTrue(calendarTab.waitForExistence(timeout: 5), "Onglet CALENDAR absent")
        calendarTab.tap()

        // L'écran calendrier est là (état vide du jour).
        XCTAssertTrue(app.staticTexts["NO SESSION PLANNED"].waitForExistence(timeout: 5),
                      "État vide du calendrier absent")

        let shotEmpty = XCTAttachment(screenshot: app.screenshot())
        shotEmpty.name = "CALENDAR_EMPTY"; shotEmpty.lifetime = .keepAlways
        add(shotEmpty)

        // Planifier : PLAN A TRAINING → un template.
        app.buttons["PLAN A TRAINING"].tap()
        XCTAssertTrue(app.staticTexts["TEMPLATES"].waitForExistence(timeout: 5),
                      "Sélecteur de protocole absent")
        // Premier protocole planifiable de la sheet (rangée identifiée).
        let firstPick = app.buttons.matching(identifier: "plan-pick-row").firstMatch
        XCTAssertTrue(firstPick.waitForExistence(timeout: 5), "Aucun protocole à planifier")
        firstPick.tap()

        // La séance apparaît dans l'agenda (badge [PLANNED]).
        XCTAssertTrue(app.staticTexts["[PLANNED]"].waitForExistence(timeout: 5),
                      "La séance planifiée n'apparaît pas dans l'agenda")

        let shotPlanned = XCTAttachment(screenshot: app.screenshot())
        shotPlanned.name = "CALENDAR_PLANNED"; shotPlanned.lifetime = .keepAlways
        add(shotPlanned)

        // Vue À VENIR : la séance doit s'y retrouver aussi (toutes les séances à traiter).
        app.buttons["À VENIR"].tap()
        XCTAssertTrue(app.staticTexts["[PLANNED]"].waitForExistence(timeout: 5),
                      "La séance n'apparaît pas dans la liste À VENIR")
        let shotUpcoming = XCTAttachment(screenshot: app.screenshot())
        shotUpcoming.name = "CALENDAR_UPCOMING"; shotUpcoming.lifetime = .keepAlways
        add(shotUpcoming)

        // Tap sur la séance → retour à la vue SEMAINE sur son jour.
        app.staticTexts["[PLANNED]"].firstMatch.tap()
        XCTAssertTrue(app.buttons["PLAN A TRAINING"].waitForExistence(timeout: 5),
                      "Le tap n'a pas ramené à la vue SEMAINE")
    }
}
