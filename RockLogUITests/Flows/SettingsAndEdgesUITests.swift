//
//  SettingsAndEdgesUITests.swift
//  RockLogUITests
//

import XCTest

final class SettingsAndEdgesUITests: RockLogUITestCase {

    func test_settingsOpensWithLongHistory_withoutFreezing() {
        launch(preset: "longHistory")
        tapTab("Settings")
        XCTAssertTrue(element(UITestID.settingsDataBackup).waitForExistence(timeout: 20))
        element(UITestID.settingsDataBackup).tap()
        let restore = element(UITestID.settingsRestore)
        scrollUntilHittable(restore)
        XCTAssertTrue(element(UITestID.settingsExport).exists)
        app.navigationBars.buttons["Settings"].tap()
        tapTab("Workout")
        waitFor(UITestID.workoutPrograms).tap()
        XCTAssertTrue(element(UITestID.settingsEditSplit).waitForExistence(timeout: 8))
        XCTAssertTrue(element(UITestID.settingsAddPlanned).exists)
        // On iPhone SE the Import split row sits below the fold of the lazy List.
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Programs hierarchy before scroll"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        let importSplit = element(UITestID.settingsImportSplit)
        // The 5s bound starts after the existence probe: swipes + hittable check only.
        var scrollStart = Date()
        scrollUntilHittable(importSplit, maxSwipes: 4, existenceTimeout: 0.5,
                            afterExistenceProbe: { scrollStart = Date() })
        XCTAssertLessThan(Date().timeIntervalSince(scrollStart), 5,
                          "Swiping to Import split took over 5s; Programs may be unresponsive")
        XCTAssertTrue(importSplit.isHittable,
                      "Import split is not hittable after 4 swipes on Programs")
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
        waitForLogSet().tap()
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
