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

    /// Settings is a lazy List. On iOS 26 that List is often a collection
    /// view, so a swipe on `tables.firstMatch` can hit an empty table and
    /// never move the list. Slow swipes so a short row is not skipped.
    func scrollUntilExists(_ identifier: String, maxSwipes: Int = 8) {
        let match = element(identifier)
        if match.waitForExistence(timeout: 2) { return }
        for _ in 0..<maxSwipes {
            swipeUpInScrollable()
            if match.waitForExistence(timeout: 1) { return }
        }
        XCTAssertTrue(match.waitForExistence(timeout: 2), "Timed out scrolling to \(identifier)")
    }

    /// Same as `scrollUntilExists`, for a control that has a label but no identifier.
    /// The first label is `element` so this does not share an Objective-C selector
    /// with `scrollUntilExists(_:maxSwipes:)`.
    func scrollUntilExists(element match: XCUIElement, maxSwipes: Int = 8) {
        if match.waitForExistence(timeout: 2) { return }
        for _ in 0..<maxSwipes {
            swipeUpInScrollable()
            if match.waitForExistence(timeout: 1) { return }
        }
        XCTAssertTrue(match.waitForExistence(timeout: 2), "Timed out scrolling to \(match)")
    }

    /// Scroll until the element is on screen. Existence is not enough: a
    /// VStack inside a ScrollView keeps off-screen rows in the tree, and a
    /// drag from there scrolls the page instead of reordering.
    func scrollUntilHittable(_ match: XCUIElement, maxSwipes: Int = 8) {
        if match.waitForExistence(timeout: 4), match.isHittable { return }
        for _ in 0..<maxSwipes {
            swipeUpInScrollable()
            if match.isHittable { return }
        }
        XCTAssertTrue(match.isHittable, "Not hittable after scrolling: \(match)")
    }

    private func swipeUpInScrollable() {
        let candidates = [
            app.collectionViews.firstMatch,
            app.tables.firstMatch,
            app.scrollViews.firstMatch,
        ].filter(\.exists)
        if let target = candidates.max(by: { $0.frame.height < $1.frame.height }) {
            target.swipeUp(velocity: .slow)
        } else {
            app.swipeUp(velocity: .slow)
        }
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
