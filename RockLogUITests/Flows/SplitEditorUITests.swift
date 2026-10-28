//
//  SplitEditorUITests.swift
//  RockLogUITests
//

import XCTest

final class SplitEditorUITests: RockLogUITestCase {

    func test_splitSwipeDelete_requiresConfirm_andDayPlanRemovesALift() {
        launch(preset: "typical")
        waitFor(UITestID.workoutPrograms).tap()
        waitFor(UITestID.settingsEditSplit).tap()
        XCTAssertTrue(app.navigationBars["Training Split"].waitForExistence(timeout: 6))

        let pull = waitFor(UITestID.splitDay("Pull"))
        XCTAssertEqual(pull.identifier, UITestID.splitDay("Pull"))
        let labelBefore = pull.label
        assertMoveButtonsHidden()
        scrollUntilHittable(pull)
        pull.swipeLeft()
        if element(UITestID.splitDay("Pull")).exists {
            tapMenuItem(identifier: UITestID.splitDelete, label: "Delete")
        }
        XCTAssertTrue(element(UITestID.splitDay("Pull")).exists, "Swipe must not delete a split day before confirm.")
        let dialog = app.buttons["Delete day"]
        XCTAssertTrue(dialog.waitForExistence(timeout: 4), "Delete day did not appear")
        dialog.tap()
        XCTAssertFalse(element(UITestID.splitDay("Pull")).waitForExistence(timeout: 2))
        XCTAssertTrue(labelBefore.contains("Pull"))

        tapTab("Workout")
        selectPushIfNeeded()
        waitFor(UITestID.todayEditDay).tap()
        let bench = waitFor(UITestID.dayPlanExercise("UI Bench Press"))
        pressForMenu(bench)
        tapMenuItem(identifier: "Remove", label: "Remove")
        XCTAssertFalse(element(UITestID.dayPlanExercise("UI Bench Press")).waitForExistence(timeout: 3))
    }

    func test_splitLongPressDelete_requiresConfirm() {
        launch(preset: "typical")
        waitFor(UITestID.workoutPrograms).tap()
        waitFor(UITestID.settingsEditSplit).tap()
        let legs = waitFor(UITestID.splitDay("Legs"))
        pressForMenu(legs)
        tapMenuItem(identifier: UITestID.splitDelete, label: "Delete")
        XCTAssertTrue(element(UITestID.splitDay("Legs")).exists, "The menu must not delete a split day before confirm.")
        let dialog = app.buttons["Delete day"]
        XCTAssertTrue(dialog.waitForExistence(timeout: 4))
        dialog.tap()
        XCTAssertFalse(element(UITestID.splitDay("Legs")).waitForExistence(timeout: 2))
    }

    /// Reorder is checked through the visible Move up button. The long-press
    /// drag stays in the app; this test does not perform it.
    func test_splitReorder_dragChangesPositionLabel() {
        launch(preset: "typical")
        waitFor(UITestID.workoutPrograms).tap()
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
        waitFor(UITestID.workoutPrograms).tap()
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
        waitFor(UITestID.workoutPrograms).tap()
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

    /// Move up stays outside the swipe host. Pull moves from 2 to 1, Push from 1 to 2.
    func test_reorderMoveUp_movesTheRow() {
        launch(preset: "typical")
        waitFor(UITestID.workoutPrograms).tap()
        waitFor(UITestID.settingsEditSplit).tap()

        let pull = waitFor(UITestID.splitDay("Pull"))
        XCTAssertTrue(pull.label.hasPrefix("2."))
        let push = waitFor(UITestID.splitDay("Push"))
        XCTAssertTrue(push.label.hasPrefix("1."))
        showMoveButtons()

        let moveUp = waitFor(UITestID.splitDayMoveUp("Pull"))
        scrollUntilHittable(moveUp)
        moveUp.tap()

        let movedPull = element(UITestID.splitDay("Pull"))
        let movedPush = element(UITestID.splitDay("Push"))
        let pullSettled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label BEGINSWITH '1.'"),
            object: movedPull
        )
        let pushSettled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label BEGINSWITH '2.'"),
            object: movedPush
        )
        wait(for: [pullSettled, pushSettled], timeout: 10)
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
