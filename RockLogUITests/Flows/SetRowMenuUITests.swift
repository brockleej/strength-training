//
//  SetRowMenuUITests.swift
//  RockLogUITests
//
//  Native swipe deletes a logged set. A tap still edits. A long-press
//  opens the same Delete and does not edit.
//

import XCTest

final class SetRowMenuUITests: RockLogUITestCase {

    func test_tap_entersEditMode() {
        let row = openFreshSet()
        row.tap()
        waitUntilEditing(row)
        XCTAssertTrue(element(UITestID.focusUpdateSet).waitForExistence(timeout: 4))
    }

    func test_longPress_doesNotEnterEditMode() {
        let row = openFreshSet()
        pressForMenu(row)
        XCTAssertTrue(element(UITestID.setDelete).waitForExistence(timeout: 3), "Delete was not in the menu")
        XCTAssertFalse(element(UITestID.focusUpdateSet).exists, "Long-press entered edit mode")
        let value = (row.value as? String) ?? ""
        XCTAssertFalse(row.label.contains("editing") || value.contains("editing"))
    }

    func test_swipeLeft_thenTapDelete_removesTheSet() {
        let row = openFreshSet()
        row.swipeLeft()
        if element(UITestID.focusSet(1)).exists {
            tapMenuItem(identifier: UITestID.setDelete, label: "Delete")
        }
        XCTAssertFalse(element(UITestID.focusSet(1)).waitForExistence(timeout: 2))
    }

    func test_fullSwipe_deletesTheSet() {
        let row = openFreshSet()
        let start = row.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        let end = row.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertFalse(element(UITestID.focusSet(1)).waitForExistence(timeout: 2))
        XCTAssertFalse(element(UITestID.focusUpdateSet).exists)
    }

    func test_swipeDelete_undoRestoresTheSet() {
        let row = openFreshSet()
        row.swipeLeft()
        if element(UITestID.focusSet(1)).exists {
            tapMenuItem(identifier: UITestID.setDelete, label: "Delete")
        }
        let undo = waitFor(UITestID.setUndo)
        undo.tap()
        XCTAssertTrue(element(UITestID.focusSet(1)).waitForExistence(timeout: 4))
    }

    func test_longPressDelete_removesTheSet() {
        let row = openFreshSet()
        pressForMenu(row)
        tapMenuItem(identifier: UITestID.setDelete, label: "Delete")
        XCTAssertFalse(element(UITestID.focusSet(1)).waitForExistence(timeout: 2))
    }

    private func openFreshSet() -> XCUIElement {
        launch(preset: "typical", extra: [UITestID.diagControlArgument])
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()
        waitFor(UITestID.workoutExercise("UI Fresh Lift")).tap()
        waitForLogSet().tap()
        let row = waitFor(UITestID.focusSet(1))
        scrollUntilHittable(row)
        return row
    }

    private func waitUntilEditing(_ row: XCUIElement) {
        let editing = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "editing", "editing"),
            object: row
        )
        let result = XCTWaiter.wait(for: [editing], timeout: 6)
        guard result == .completed else {
            let seenValue = (row.value as? String) ?? String(describing: row.value ?? "nil")
            XCTFail("focus.set did not show editing. label=\(row.label) value=\(seenValue)")
            return
        }
    }
}
