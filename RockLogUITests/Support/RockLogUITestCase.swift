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
    /// A disappeared row counts only when the matching identifier count
    /// drops by exactly 1. "Delete day" leaves the split row in place.
    func swipeToRemove(_ row: XCUIElement) {
        XCTAssertTrue(row.waitForExistence(timeout: 6))
        let identifier = row.identifier
        let query = app.descendants(matching: .any).matching(identifier: identifier)
        let before = query.count
        XCTAssertGreaterThan(before, 0, "No row for \(identifier)")
        row.swipeLeft()

        if query.count >= before {
            let trash = element(UITestID.swipeTrash)
            if trash.waitForExistence(timeout: 2), trash.isHittable {
                trash.tap()
            } else if row.exists {
                row.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
            }
        }

        if query.count == before, app.buttons["Delete day"].waitForExistence(timeout: 2) {
            XCTAssertEqual(query.count, before, "Delete day must leave \(identifier) until the confirm is tapped")
            return
        }

        let dropped = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count == %d", before - 1),
            object: query
        )
        dropped.expectationDescription = "\(identifier) count should drop from \(before) to \(before - 1)"
        wait(for: [dropped], timeout: 4)
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
