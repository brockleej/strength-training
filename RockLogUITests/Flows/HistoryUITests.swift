//
//  HistoryUITests.swift
//  RockLogUITests
//

import XCTest

final class HistoryUITests: RockLogUITestCase {

    func test_typicalHistory_listsPastDays() {
        launch(preset: "typical")
        tapTab("History")
        XCTAssertFalse(element(UITestID.historyEmpty).waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Legs"].waitForExistence(timeout: 8))
    }

    func test_longHistory_historyOpens() {
        launch(preset: "longHistory")
        tapTab("History")
        XCTAssertTrue(app.staticTexts["Legs"].waitForExistence(timeout: 12))
        XCTAssertFalse(element(UITestID.historyEmpty).exists)
    }
}
