//
//  SettingsAndEdgesUITests.swift
//  RockLogUITests
//

import XCTest

final class SettingsAndEdgesUITests: RockLogUITestCase {

    func test_settingsOpensWithLongHistory_withoutFreezing() {
        launch(preset: "longHistory")
        tapTab("Settings")
        XCTAssertTrue(element(UITestID.settingsEditSplit).waitForExistence(timeout: 20))
        XCTAssertTrue(element(UITestID.settingsRestore).waitForExistence(timeout: 8))
        XCTAssertTrue(element(UITestID.settingsExport).exists)
        XCTAssertTrue(element(UITestID.settingsAddPlanned).exists)
        XCTAssertTrue(element(UITestID.settingsImportSplit).exists)
    }

    func test_dynamicType_accessibility5_startStaysHittable() {
        launch(preset: "typical", extra: ["-RockLogDynamicType", "accessibility5"])
        let start = waitFor(UITestID.todayStart)
        XCTAssertTrue(start.isHittable)
        XCTAssertTrue(app.tabBars.buttons["Settings"].isHittable)
    }

    func test_primaryControlsStayInsideTheWindow() {
        launch(preset: "typical")
        let start = waitFor(UITestID.todayStart)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 4))
        XCTAssertTrue(start.isHittable)
        XCTAssertGreaterThanOrEqual(start.frame.minX, window.frame.minX - 1)
        XCTAssertLessThanOrEqual(start.frame.maxX, window.frame.maxX + 1)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists)
        XCTAssertLessThanOrEqual(tabBar.frame.maxY, window.frame.maxY + 1)
    }

    func test_relaunchMidWorkout_resumesTheLoggedSet() {
        launch(preset: "typical", extra: ["-RockLogRelaunchStore"])
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()
        waitFor(UITestID.workoutExercise("UI Fresh Lift")).tap()
        waitFor(UITestID.focusLogSet).tap()
        XCTAssertTrue(element(UITestID.focusSet(1)).waitForExistence(timeout: 6))

        app.terminate()
        launch(
            preset: "typical",
            extra: ["-RockLogRelaunchStore", "-RockLogRelaunchKeep"]
        )

        XCTAssertTrue(element(UITestID.workoutExercise("UI Fresh Lift")).waitForExistence(timeout: 12))
        element(UITestID.workoutExercise("UI Fresh Lift")).tap()
        XCTAssertTrue(element(UITestID.focusSet(1)).waitForExistence(timeout: 8))
    }
}
