//
//  UnitsUITests.swift
//  RockLogUITests
//
//  Switching Settings → Units changes the weight label on the lift screen.
//

import XCTest

final class UnitsUITests: RockLogUITestCase {
    func test_unitsToggle_showsKilogramsOnTheStepper() {
        launch(preset: "typical")
        tapTab("Settings")
        scrollUntilHittable(element(UITestID.settingsUnits))
        element(UITestID.settingsUnits).tap()
        let kilograms = app.buttons["Kilograms"]
        XCTAssertTrue(kilograms.waitForExistence(timeout: 6))
        kilograms.tap()
        XCTAssertTrue(element(UITestID.settingsMassUnit).waitForExistence(timeout: 4))

        tapTab("Workout")
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()
        waitFor(UITestID.workoutExercise("UI Fresh Lift")).tap()
        XCTAssertTrue(app.staticTexts["WEIGHT (KG)"].waitForExistence(timeout: 8))
        let step = app.buttons["Weight step 2.5 kilograms, tap to change step"]
        XCTAssertTrue(step.waitForExistence(timeout: 4))
        XCTAssertTrue(step.label.contains("kilograms"))
    }
}
