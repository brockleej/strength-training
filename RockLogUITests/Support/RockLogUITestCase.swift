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
    /// `-RockLogUITesting` opens a fresh in-memory store with CloudKit off.
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
    /// A full swipe already removes the row, so the trailing tap is skipped
    /// when the element is gone.
    func swipeToRemove(_ row: XCUIElement) {
        XCTAssertTrue(row.waitForExistence(timeout: 6))
        row.swipeLeft()
        let trash = element(UITestID.swipeTrash)
        if trash.waitForExistence(timeout: 2), trash.isHittable {
            trash.tap()
            return
        }
        guard row.exists else { return }
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    }

    /// Settings is a lazy List. Rows below the first screen are not in the
    /// tree until scrolled into view.
    func scrollUntilExists(_ identifier: String, maxSwipes: Int = 8) {
        let match = element(identifier)
        if match.waitForExistence(timeout: 2) { return }
        for _ in 0..<maxSwipes {
            if app.tables.firstMatch.exists {
                app.tables.firstMatch.swipeUp()
            } else {
                app.swipeUp()
            }
            if match.waitForExistence(timeout: 1) { return }
        }
        XCTAssertTrue(match.waitForExistence(timeout: 2), "Timed out scrolling to \(identifier)")
    }

    /// Same as `scrollUntilExists`, for a control that has a label but no identifier.
    func scrollUntilExists(_ match: XCUIElement, maxSwipes: Int = 8) {
        if match.waitForExistence(timeout: 2) { return }
        for _ in 0..<maxSwipes {
            if app.tables.firstMatch.exists {
                app.tables.firstMatch.swipeUp()
            } else {
                app.swipeUp()
            }
            if match.waitForExistence(timeout: 1) { return }
        }
        XCTAssertTrue(match.waitForExistence(timeout: 2), "Timed out scrolling to \(match)")
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
