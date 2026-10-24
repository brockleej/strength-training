//
//  PlannedTodayUITests.swift
//  RockLogUITests
//

import XCTest

final class PlannedTodayUITests: RockLogUITestCase {

    func test_planWaiting_showsQueueInsteadOfAMissedWeek() {
        launch(preset: "planWaiting")
        XCTAssertTrue(app.staticTexts["What's next"].waitForExistence(timeout: 12))
        let row = waitFor(UITestID.plannedRow("Push"))
        XCTAssertTrue(row.label.localizedCaseInsensitiveContains("Next up"))
        XCTAssertFalse(row.label.localizedCaseInsensitiveContains("missed"))

        let start = waitFor(UITestID.todayStart)
        XCTAssertFalse(start.label.localizedCaseInsensitiveContains("A week"))
        XCTAssertTrue(start.label.contains("Push"))
    }
}
