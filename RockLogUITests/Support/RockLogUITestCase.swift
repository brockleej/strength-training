//
//  RockLogUITestCase.swift
//  RockLogUITests
//

import XCTest

class RockLogUITestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// Replaces launch arguments. Do not append across launches.
    func launch(
        preset: String,
        extra: [String] = [],
        environment: [String: String] = [:]
    ) {
        app.launchArguments = ["-RockLogUITesting", "-RockLogPreset", preset] + extra
        app.launchEnvironment = environment
        app.launch()
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @discardableResult
    func waitFor(_ identifier: String, timeout: TimeInterval = 12) -> XCUIElement {
        let match = element(identifier)
        XCTAssertTrue(match.waitForExistence(timeout: timeout), "Timed out waiting for \(identifier)")
        return match
    }

    func tapTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 8), "Missing tab \(name)")
        tab.tap()
    }

    func dismissAlert(button title: String, timeout: TimeInterval = 8) {
        let button = app.buttons[title]
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "Missing alert button \(title)")
        button.tap()
    }

    /// Soft remove: swipe, then tap the trailing trash strip.
    /// Set rows allow a full swipe to delete; split rows must not.
    func swipeToRemove(_ row: XCUIElement) {
        XCTAssertTrue(row.waitForExistence(timeout: 6))
        row.swipeLeft()
        let trash = element(UITestID.swipeTrash)
        if trash.waitForExistence(timeout: 2), trash.isHittable {
            trash.tap()
            return
        }
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    }

    /// Finish confirmation shares its label with the bar button. Prefer the sheet.
    func confirmFinishWorkout() {
        let sheetButton = app.sheets.buttons["Finish Workout"]
        if sheetButton.waitForExistence(timeout: 3) {
            sheetButton.tap()
            return
        }
        let alertButton = app.alerts.buttons["Finish Workout"]
        XCTAssertTrue(alertButton.waitForExistence(timeout: 3))
        alertButton.tap()
    }

    func selectPushIfNeeded() {
        let start = element(UITestID.todayStart)
        if start.waitForExistence(timeout: 8), start.label.contains("Push") {
            return
        }
        let push = element(UITestID.todayDay("Push"))
        if push.waitForExistence(timeout: 4) {
            push.tap()
        }
    }
}
