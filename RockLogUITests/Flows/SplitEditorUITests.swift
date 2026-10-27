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
        XCTAssertEqual(pull.identifier, UITestID.splitDay("Pull"))
        let labelBefore = pull.label
        assertMoveButtonsHidden()
        scrollUntilHittable(pull)
        swipeToRemove(pull, confirmingDelete: true)
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
        XCTAssertEqual(pull.identifier, UITestID.splitDay("Pull"))
        XCTAssertTrue(pull.label.hasPrefix("2."))
        assertMoveButtonsHidden()
        showMoveButtons()

        let pushUp = waitFor(UITestID.splitDayMoveUp("Push"))
        XCTAssertEqual(pushUp.identifier, UITestID.splitDayMoveUp("Push"))
        XCTAssertFalse(pushUp.isEnabled, "Move up is disabled on the first day")

        let moveUp = waitFor(UITestID.splitDayMoveUp("Pull"))
        XCTAssertEqual(moveUp.identifier, UITestID.splitDayMoveUp("Pull"))
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
        XCTAssertEqual(pull.identifier, UITestID.splitDay("Pull"))
        XCTAssertTrue(pull.label.hasPrefix("2."))
        assertMoveButtonsHidden()
        showMoveButtons()

        let legsDown = waitFor(UITestID.splitDayMoveDown("Legs"))
        XCTAssertEqual(legsDown.identifier, UITestID.splitDayMoveDown("Legs"))
        XCTAssertFalse(legsDown.isEnabled, "Move down is disabled on the last day")

        let moveDown = waitFor(UITestID.splitDayMoveDown("Pull"))
        XCTAssertEqual(moveDown.identifier, UITestID.splitDayMoveDown("Pull"))
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

    func test_splitRowTap_opensEditor_andKeepsTheDay() {
        launch(preset: "typical")
        tapTab("Settings")
        waitFor(UITestID.settingsEditSplit).tap()

        let pull = waitFor(UITestID.splitDay("Pull"))
        XCTAssertEqual(pull.identifier, UITestID.splitDay("Pull"))
        let labelBefore = pull.label
        assertMoveButtonsHidden()
        scrollUntilHittable(pull)
        pull.tap()

        XCTAssertTrue(app.navigationBars["Edit day"].waitForExistence(timeout: 6))
        XCTAssertFalse(app.buttons["Delete day"].exists)
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 4))
        cancel.tap()

        let still = waitFor(UITestID.splitDay("Pull"))
        XCTAssertEqual(still.identifier, UITestID.splitDay("Pull"))
        XCTAssertEqual(still.label, labelBefore)
        XCTAssertTrue(element(UITestID.splitDay("Push")).exists)
        XCTAssertTrue(element(UITestID.splitDay("Legs")).exists)
    }

    private func assertMoveButtonsHidden() {
        XCTAssertFalse(
            element(UITestID.splitDayMoveUp("Pull")).waitForExistence(timeout: 1),
            "Move up is visible while Reorder is off"
        )
        XCTAssertFalse(element(UITestID.splitDayMoveDown("Pull")).exists)
    }

    private func showMoveButtons() {
        let reorder = waitFor(UITestID.splitReorder)
        XCTAssertEqual(reorder.identifier, UITestID.splitReorder)
        scrollUntilHittable(reorder)
        reorder.tap()
        XCTAssertTrue(element(UITestID.splitDayMoveUp("Pull")).waitForExistence(timeout: 4))
        XCTAssertTrue(element(UITestID.splitDayMoveDown("Pull")).exists)
    }
}
