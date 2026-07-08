//
//  BuilderUITests.swift
//  Lane04UITests
//
//  Création manuelle « from scratch » : le recours NEW FROM SCRATCH (contour)
//  ouvre l'éditeur d'un [DRAFT] pré-monté, avec les affordances du builder
//  (ajouter un bloc, éditer nom/tag/objectif).
//

import XCTest

final class BuilderUITests: XCTestCase {

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

    /// NEW FROM SCRATCH → éditeur d'un protocole vierge, puis ajout d'un bloc.
    @MainActor
    func testCreateBlankOpensBuilder() {
        let app = launch()

        let newButton = app.buttons["NEW FROM SCRATCH"]
        XCTAssertTrue(newButton.waitForExistence(timeout: 5), "Recours NEW FROM SCRATCH absent")
        newButton.tap()

        // L'éditeur s'ouvre (titre système PROTOCOL du scaffold).
        XCTAssertTrue(app.staticTexts["PROTOCOL"].firstMatch.waitForExistence(timeout: 5),
                      "L'éditeur ne s'est pas ouvert")

        // Affordance du builder : ajouter un bloc.
        let addBlock = app.buttons["+ AJOUTER UN BLOC"]
        XCTAssertTrue(addBlock.waitForExistence(timeout: 5), "Bouton d'ajout de bloc absent")
        addBlock.tap()

        // Capture pour vérification visuelle du builder.
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "BUILDER_FROM_SCRATCH"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
