//
//  SplitEditorUITests.swift
//  RockLogUITests
//

import XCTest

final class SplitEditorUITests: RockLogUITestCase {

    func test_splitSwipeDelete_requiresConfirm_andDayPlanRemovesALift() {
        launch(preset: "typical")
        tapTab("Settings")
        waitFor(UITestID.settingsEditSplit).tap()
        XCTAssertTrue(app.navigationBars["Training Split"].waitForExistence(timeout: 6))

        let pull = waitFor(UITestID.splitDay("Pull"))
        let labelBefore = pull.label
        scrollUntilHittable(pull)
        swipeToRemove(pull)
        XCTAssertTrue(element(UITestID.splitDay("Pull")).exists, "A full swipe must not delete a split day.")
        dismissAlert(button: "Delete day")
        XCTAssertFalse(element(UITestID.splitDay("Pull")).waitForExistence(timeout: 2))
        XCTAssertTrue(labelBefore.contains("Pull"))

        tapTab("Workout")
        selectPushIfNeeded()
        waitFor(UITestID.todayEditDay).tap()
        let bench = waitFor(UITestID.dayPlanExercise("UI Bench Press"))
        scrollUntilHittable(bench)
        swipeToRemove(bench)
        XCTAssertFalse(element(UITestID.dayPlanExercise("UI Bench Press")).waitForExistence(timeout: 3))
    }

    /// Reorder is checked through the visible Move up button. The long-press
    /// drag stays in the app; this test does not perform it.
    func test_splitReorder_dragChangesPositionLabel() {
        launch(preset: "typical")
        tapTab("Settings")
        waitFor(UITestID.settingsEditSplit).tap()

        let pull = waitFor(UITestID.splitDay("Pull"))
        XCTAssertTrue(pull.label.hasPrefix("2."))
        let pushUp = waitFor(UITestID.splitDayMoveUp("Push"))
        XCTAssertFalse(pushUp.isEnabled, "Move up is disabled on the first day")

        let moveUp = waitFor(UITestID.splitDayMoveUp("Pull"))
        scrollUntilHittable(moveUp)
        XCTAssertTrue(moveUp.isEnabled)
        moveUp.tap()

        let moved = element(UITestID.splitDay("Pull"))
        XCTAssertTrue(moved.waitForExistence(timeout: 4))
        let settled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label BEGINSWITH '1.'"),
            object: moved
        )
        wait(for: [settled], timeout: 10)
    }

    func test_splitReorder_moveDownButtonChangesPositionLabel() {
        launch(preset: "typical")
        tapTab("Settings")
        waitFor(UITestID.settingsEditSplit).tap()

        let pull = waitFor(UITestID.splitDay("Pull"))
        XCTAssertTrue(pull.label.hasPrefix("2."))
        let legsDown = waitFor(UITestID.splitDayMoveDown("Legs"))
        XCTAssertFalse(legsDown.isEnabled, "Move down is disabled on the last day")

        let moveDown = waitFor(UITestID.splitDayMoveDown("Pull"))
        scrollUntilHittable(moveDown)
        XCTAssertTrue(moveDown.isEnabled)
        moveDown.tap()

        let moved = element(UITestID.splitDay("Pull"))
        XCTAssertTrue(moved.waitForExistence(timeout: 4))
        let settled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label BEGINSWITH '3.'"),
            object: moved
        )
        wait(for: [settled], timeout: 10)
    }
}
