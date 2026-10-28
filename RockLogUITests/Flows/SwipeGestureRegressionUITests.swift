//
//  SwipeGestureRegressionUITests.swift
//  RockLogUITests
//
//  Synthetic fixtures only. A swipe must not open edit, and the existing
//  remove and reorder controls must still work.
//

import XCTest

final class SwipeGestureRegressionUITests: RockLogUITestCase {

    func test_splitSwipe_doesNotOpenEditor_andTrashDeletes() {
        launch(preset: "typical")
        tapTab("Settings")
        waitFor(UITestID.settingsEditSplit).tap()

        let pull = waitFor(UITestID.splitDay("Pull"))
        scrollUntilHittable(pull)
        pull.swipeLeft()

        XCTAssertFalse(
            app.navigationBars["Edit day"].waitForExistence(timeout: 1),
            "A swipe must not open Edit day"
        )
        XCTAssertTrue(pull.exists, "Pull must stay until Delete day is confirmed")
        let trash = element(UITestID.swipeTrash)
        XCTAssertTrue(trash.waitForExistence(timeout: 2), "Missing \(UITestID.swipeTrash)")
        XCTAssertTrue(trash.isHittable)
        trash.tap()
        dismissAlert(button: "Delete day")
        XCTAssertFalse(element(UITestID.splitDay("Pull")).waitForExistence(timeout: 2))
    }

    func test_setRowFullSwipe_deletesWithoutEnteringEdit() {
        launch(preset: "typical")
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()
        waitFor(UITestID.workoutExercise("UI Fresh Lift")).tap()
        waitFor(UITestID.focusLogSet).tap()

        let row = waitFor(UITestID.focusSet(1))
        scrollUntilHittable(row)
        XCTAssertTrue(row.isHittable)
        row.swipeLeft(velocity: .fast)

        XCTAssertFalse(element(UITestID.focusSet(1)).waitForExistence(timeout: 3))
        XCTAssertFalse(element(UITestID.focusUpdateSet).exists, "A swipe must not enter edit")
    }

    func test_splitReorder_moveUpStillChangesPosition() {
        launch(preset: "typical")
        tapTab("Settings")
        waitFor(UITestID.settingsEditSplit).tap()

        let pull = waitFor(UITestID.splitDay("Pull"))
        XCTAssertTrue(pull.label.hasPrefix("2."))
        let reorder = waitFor(UITestID.splitReorder)
        scrollUntilHittable(reorder)
        reorder.tap()

        let moveUp = waitFor(UITestID.splitDayMoveUp("Pull"))
        scrollUntilHittable(moveUp)
        XCTAssertTrue(moveUp.isEnabled)
        moveUp.tap()

        XCTAssertFalse(app.navigationBars["Edit day"].exists)
        let moved = element(UITestID.splitDay("Pull"))
        let settled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label BEGINSWITH '1.'"),
            object: moved
        )
        wait(for: [settled], timeout: 10)
    }
}
