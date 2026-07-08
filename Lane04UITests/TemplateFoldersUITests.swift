//
//  TemplateFoldersUITests.swift
//  Lane04UITests
//
//  COMPILE FROM TEMPLATE ouvre une navigation par DOSSIERS de style (les 5
//  filières) ; on entre dans un style pour voir ses templates, puis un tap
//  compile un [DRAFT] et ferme la sheet.
//

import XCTest

final class TemplateFoldersUITests: XCTestCase {

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
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testFoldersThenTemplateCompiles() {
        let app = launch()

        app.buttons["COMPILE FROM TEMPLATE"].tap()

        // Niveau 1 : les dossiers de style. Le dossier VMA doit exister.
        let vmaFolder = app.buttons["Style VMA, 8 protocoles"].firstMatch
        // Le compte peut varier ; on vise le libellé partiel « Style VMA ».
        let vmaAny = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Style VMA'")).firstMatch
        XCTAssertTrue(vmaAny.waitForExistence(timeout: 5), "Dossier de style VMA absent")
        attach(app, "TEMPLATE_FOLDERS")

        vmaAny.tap()

        // Niveau 2 : les templates de la filière. Le premier template compile.
        let firstTemplate = app.scrollViews.buttons.firstMatch
        XCTAssertTrue(firstTemplate.waitForExistence(timeout: 5), "Aucun template dans le dossier")
        attach(app, "TEMPLATE_FOLDER_DETAIL")

        firstTemplate.tap()

        // Retour sur PROTOCOLS avec un [DRAFT] compilé : le hero d'accueil est là.
        XCTAssertTrue(app.buttons["COMPILE FROM TEMPLATE"].waitForExistence(timeout: 5),
                      "La sheet ne s'est pas fermée après compilation")
        _ = vmaFolder // silence unused warning path
    }
}
