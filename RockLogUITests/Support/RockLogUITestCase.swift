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
        var arguments = extra
        if !arguments.contains("-RockLogMassUnit") {
            arguments = ["-RockLogMassUnit", "lb"] + arguments
        }
        app.launchArguments = ["-RockLogUITesting", "-RockLogPreset", preset] + arguments
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

    /// Log set lives under the sets list. It must exist and sit on screen.
    /// A nested List used to cover the safe-area bar, so this button never appeared.
    @discardableResult
    func waitForLogSet(timeout: TimeInterval = 12) -> XCUIElement {
        let log = waitFor(UITestID.focusLogSet, timeout: timeout)
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(log.frame.height, 20, "Log set has no height. frame=\(log.frame)")
        XCTAssertTrue(window.intersects(log.frame), "Log set is outside the window. frame=\(log.frame) window=\(window)")
        XCTAssertTrue(log.isHittable, "Log set is not hittable. frame=\(log.frame) window=\(window)")
        return log
    }

    /// Accessibility identifiers SwiftUI gives each tab button (its SF Symbol).
    /// Used only when the tabs are not inside a tab bar (e.g. the side rail on
    /// wide iPhones such as iPhone Duo).
    static let tabIdentifiers: [String: String] = [
        "Workout": "dumbbell",
        "History": "clock",
        "Progress": "chart.line.uptrend.xyaxis",
        "Exercises": "list.bullet",
        "Settings": "gear",
    ]

    func tapTab(_ name: String) {
        let barTab = app.tabBars.buttons[name]
        if barTab.waitForExistence(timeout: 4) {
            barTab.tap()
            return
        }
        guard let identifier = Self.tabIdentifiers[name] else {
            XCTFail("Missing tab \(name) (no tab bar, no known identifier)")
            return
        }
        let matches = app.buttons.matching(identifier: identifier)
        _ = matches.firstMatch.waitForExistence(timeout: 4)
        let hittable = matches.allElementsBoundByIndex.filter { $0.exists && $0.isHittable }
        XCTAssertEqual(hittable.count, 1,
                       "Missing tab \(name): expected exactly one hittable '\(identifier)' button, found \(hittable.count)")
        guard hittable.count == 1 else { return }
        hittable[0].tap()
    }

    func dismissAlert(button title: String, timeout: TimeInterval = 8) {
        let button = app.buttons[title]
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "Missing alert button \(title)")
        button.tap()
    }

    /// Long-press, then tap a context-menu item by identifier or label.
    func pressForMenu(_ row: XCUIElement) {
        XCTAssertTrue(row.waitForExistence(timeout: 6))
        scrollUntilHittable(row)
        row.press(forDuration: 1.0)
    }

    func tapMenuItem(identifier: String, label: String) {
        let byID = element(identifier)
        if byID.waitForExistence(timeout: 2) {
            byID.tap()
            return
        }
        let button = app.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 3), "Missing menu item \(label)")
        button.tap()
    }

    /// Settings is a lazy List. On iOS 26 that List is often a collection
    /// view, so a swipe on `tables.firstMatch` can hit an empty table and
    /// never move the list. Slow swipes so a short row is not skipped.
    func scrollUntilExists(_ identifier: String, maxSwipes: Int = 8) {
        scrollUntilExists(element: element(identifier), maxSwipes: maxSwipes)
    }

    /// Same as `scrollUntilExists`, for a control that has a label but no identifier.
    /// The first label is `element` so this does not share an Objective-C selector
    /// with `scrollUntilExists(_:maxSwipes:)`. Existence is not enough: the match
    /// must be hittable before the helper returns.
    func scrollUntilExists(element match: XCUIElement, maxSwipes: Int = 8) {
        if match.waitForExistence(timeout: 2), match.isHittable { return }
        for _ in 0..<maxSwipes {
            swipeUpInScrollable()
            if match.exists, match.isHittable { return }
        }
        scrollUntilHittable(match, maxSwipes: 2)
    }

    /// Scroll until the element is on screen. Existence is not enough: a
    /// VStack inside a ScrollView keeps off-screen rows in the tree, and a
    /// drag from there scrolls the page instead of reordering.
    func scrollUntilHittable(
        _ match: XCUIElement,
        maxSwipes: Int = 8,
        existenceTimeout: TimeInterval = 4,
        afterExistenceProbe: (() -> Void)? = nil
    ) {
        let found = match.waitForExistence(timeout: existenceTimeout)
        afterExistenceProbe?()
        if found, match.isHittable { return }
        for _ in 0..<maxSwipes {
            swipeUpInScrollable()
            if match.isHittable { return }
        }
        XCTAssertTrue(match.isHittable, "Not hittable after scrolling: \(match)")
    }

    /// Swipes down in the largest scrollable until `anchor` is hittable (back at the top).
    func scrollToTop(showing anchor: XCUIElement, maxSwipes: Int = 8) {
        for _ in 0..<maxSwipes {
            if anchor.exists, anchor.isHittable { return }
            let candidates = [
                app.collectionViews.firstMatch,
                app.tables.firstMatch,
                app.scrollViews.firstMatch,
            ].filter(\.exists)
            if let target = candidates.max(by: { $0.frame.height < $1.frame.height }) {
                target.swipeDown(velocity: .fast)
            } else {
                app.swipeDown(velocity: .fast)
            }
        }
        XCTAssertTrue(anchor.isHittable, "Could not scroll back to the top: \(anchor)")
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
