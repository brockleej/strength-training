//
//  ListRowInteractionUITests.swift
//  RockLogUITests
//
//  Regression for the 18 Pro Max dead row center (9a28cb0, 20/20 failures):
//  a CENTER tap (XCUIElement.tap) on each split row and on a day plan row must
//  open exactly one editor. Also: mid-screen variant, swipe delete, context
//  menu, and reorder (split: Move up/down buttons; day plan: number-handle
//  long-press drag). Synthetic "typical" preset only.
//

import XCTest

final class ListRowInteractionUITests: RockLogUITestCase {

    private let days = ["Push", "Pull", "Legs"]

    // MARK: Split rows

    func test_splitRows_eachTapOpensExactlyOneEditor_twice() {
        openSplitEditor()
        for name in days {
            for attempt in 1...2 {
                let row = waitFor(UITestID.splitDay(name))
                scrollUntilHittable(row)
                row.tap()
                assertSingleEditDaySheet(context: "\(name) tap \(attempt)")
                cancelEditDay()
            }
        }
    }

    /// Taps whichever split row is already hittable when the screen opens,
    /// with no scrolling first (the 18 Pro Max case).
    func test_splitRow_tapWithoutScrolling_opensEditor() throws {
        openSplitEditor()
        _ = waitFor(UITestID.splitDay("Push"))
        guard let name = days.first(where: { element(UITestID.splitDay($0)).isHittable }) else {
            throw XCTSkip("Explicit skip: no split row is on screen before scrolling on this device (e.g. iPhone SE); the center-tap tests cover it after scrolling")
        }
        element(UITestID.splitDay(name)).tap()
        assertSingleEditDaySheet(context: "\(name) no-scroll tap")
        cancelEditDay()
    }

    /// Scrolls Pull into the middle third of the window, then taps it.
    func test_splitRow_tapAtMidScreen_opensEditor() {
        openSplitEditor()
        let pull = element(UITestID.splitDay("Pull"))
        scrollUntilHittable(pull)
        let window = app.windows.firstMatch.frame
        let low = window.minY + window.height * 0.3
        let high = window.minY + window.height * 0.7
        let list = app.scrollViews.firstMatch
        for _ in 0..<8 where pull.frame.midY > high {
            list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                .press(forDuration: 0.1, thenDragTo: list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)))
        }
        XCTAssertTrue(pull.isHittable, "Pull is not hittable at mid-screen. frame=\(pull.frame)")
        XCTAssertTrue((low...high).contains(pull.frame.midY), "Pull is not mid-screen. midY=\(pull.frame.midY)")
        pull.tap()
        assertSingleEditDaySheet(context: "Pull mid-screen tap")
        cancelEditDay()
    }

    func test_splitRow_swipeDelete_contextMenu_andReorder_stillWork() {
        openSplitEditor()
        // Reorder: Reorder on, Legs Move up twice -> 1., Reorder off.
        // Split reorder is driven by Move up/down (XCUITest cannot reliably
        // drive the number-handle drag here; it raises the row menu).
        let reorder = waitFor(UITestID.splitReorder)
        scrollUntilHittable(reorder)
        reorder.tap()
        let legs = waitFor(UITestID.splitDay("Legs"))
        XCTAssertTrue(legs.label.hasPrefix("3."))
        for _ in 0..<2 {
            let up = waitFor(UITestID.splitDayMoveUp("Legs"))
            scrollUntilHittable(up)
            up.tap()
        }
        wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH '1.'"), object: element(UITestID.splitDay("Legs")))], timeout: 10)
        waitFor(UITestID.splitReorder).tap()

        // Context menu delete (confirm).
        let pull = waitFor(UITestID.splitDay("Pull"))
        pressForMenu(pull)
        tapMenuItem(identifier: UITestID.splitDelete, label: "Delete")
        XCTAssertTrue(app.buttons["Delete day"].waitForExistence(timeout: 4))
        app.buttons["Delete day"].tap()
        XCTAssertFalse(element(UITestID.splitDay("Pull")).waitForExistence(timeout: 2))

        // Swipe delete (confirm).
        let remaining = waitFor(UITestID.splitDay("Push"))
        scrollUntilHittable(remaining)
        remaining.swipeLeft()
        if !app.buttons["Delete day"].waitForExistence(timeout: 2) {
            tapMenuItem(identifier: UITestID.splitDelete, label: "Delete")
        }
        XCTAssertTrue(app.buttons["Delete day"].waitForExistence(timeout: 4))
        app.buttons["Delete day"].tap()
        XCTAssertFalse(element(UITestID.splitDay("Push")).waitForExistence(timeout: 2))
    }

    // MARK: Day plan rows

    func test_dayPlanRow_centerTap_handleDrag_andMenu_stillWork() {
        launch(preset: "typical")
        selectPushIfNeeded()
        waitFor(UITestID.todayEditDay).tap()

        var rows = dayPlanRows()
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 8))
        XCTAssertGreaterThanOrEqual(rows.count, 2, "typical Push needs 2+ lifts")

        // Tap opens the exercise editor once.
        let first = rows.element(boundBy: 0)
        first.tap()
        let save = app.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 6), "Center tap did not open the exercise editor")
        XCTAssertEqual(app.buttons.matching(identifier: "Save").count, 1, "expected exactly one exercise editor")
        app.buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 4), "Exercise editor did not close")

        // Reorder: long-press the number handle of row 2, drag it above row 1.
        rows = dayPlanRows()
        let second = rows.element(boundBy: 1)
        let secondID = second.identifier
        let firstRow = rows.element(boundBy: 0)
        scrollUntilHittable(second)
        XCTAssertTrue(second.label.hasPrefix("2."))
        let handle = second.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: 14 + 22, dy: second.frame.height / 2))
        let target = firstRow.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: 14 + 22, dy: 2))
        handle.press(forDuration: 0.6, thenDragTo: target, withVelocity: .slow, thenHoldForDuration: 0.3)
        let moved = element(secondID)
        wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH '1.'"), object: moved)], timeout: 10)
        dismissMenuIfShown()

        // Context menu remove.
        let a = dayPlanRows().element(boundBy: 0)
        let aID = a.identifier
        pressForMenu(a)
        tapMenuItem(identifier: "Remove", label: "Remove")
        XCTAssertFalse(element(aID).waitForExistence(timeout: 3))

        // Day plan rows have no swipe action in this design (menu only).
    }

    // MARK: Helpers

    private func openSplitEditor() {
        launch(preset: "typical")
        waitFor(UITestID.workoutPrograms).tap()
        waitFor(UITestID.settingsEditSplit).tap()
        XCTAssertTrue(app.navigationBars["Training Split"].waitForExistence(timeout: 6))
    }

    private func assertSingleEditDaySheet(context: String) {
        XCTAssertTrue(app.navigationBars["Edit day"].waitForExistence(timeout: 6), "\(context): Edit day did not open")
        // Let a second presentation (double fire) land before counting.
        _ = app.navigationBars["Edit day"].waitForNonExistence(timeout: 0.8)
        XCTAssertEqual(app.navigationBars.matching(identifier: "Edit day").count, 1, "\(context): expected exactly one Edit day sheet")
    }

    private func cancelEditDay() {
        let cancel = app.navigationBars["Edit day"].buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 4))
        cancel.tap()
        XCTAssertTrue(app.navigationBars["Edit day"].waitForNonExistence(timeout: 4), "Edit day did not close")
        XCTAssertTrue(app.navigationBars["Training Split"].waitForExistence(timeout: 4))
    }

    private func dayPlanRows() -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'dayPlan.exercise.'"))
    }

    /// A long press may also raise the row's context menu; close it.
    private func dismissMenuIfShown() {
        let menuItem = app.buttons.matching(NSPredicate(format: "label == 'Delete' OR label == 'Remove'")).firstMatch
        if menuItem.waitForExistence(timeout: 1), menuItem.isHittable {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        }
    }
}
