//
//  GymAccessUITests.swift
//  RockLogUITests
//
//  Add one synthetic gym in Settings, then tap the existing Today button.
//

import XCTest

final class GymAccessUITests: RockLogUITestCase {
    func test_addGymInSettings_thenTodayButtonShowsTheCode() {
        launch(preset: "typical")
        tapTab("Settings")
        scrollUntilHittable(element(UITestID.settingsGymAccess))
        element(UITestID.settingsGymAccess).tap()
        let add = waitFor(UITestID.gymAccessAdd)
        add.tap()
        let name = waitFor(UITestID.gymAccessName)
        name.tap()
        name.typeText("UI Gym")
        let code = waitFor(UITestID.gymAccessBarcode)
        code.tap()
        code.typeText("12345")
        waitFor(UITestID.gymAccessSave).tap()
        XCTAssertTrue(element(UITestID.gymAccessRow("UI Gym")).waitForExistence(timeout: 4))

        tapTab("Workout")
        waitFor(UITestID.todayGymPass).tap()
        let shown = waitFor(UITestID.gymPassCode)
        XCTAssertTrue(shown.label.contains("12345"))
        waitFor(UITestID.gymPassClose).tap()
    }
}
