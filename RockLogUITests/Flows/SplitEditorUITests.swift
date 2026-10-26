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
        swipeToRemove(pull)
        XCTAssertTrue(element(UITestID.splitDay("Pull")).exists, "A full swipe must not delete a split day.")
        dismissAlert(button: "Delete day")
        XCTAssertFalse(element(UITestID.splitDay("Pull")).waitForExistence(timeout: 2))
        XCTAssertTrue(labelBefore.contains("Pull"))

        tapTab("Workout")
        selectPushIfNeeded()
        waitFor(UITestID.todayEditDay).tap()
        let bench = waitFor(UITestID.dayPlanExercise("UI Bench Press"))
        swipeToRemove(bench)
        XCTAssertFalse(element(UITestID.dayPlanExercise("UI Bench Press")).waitForExistence(timeout: 3))
    }

    func test_splitReorder_dragChangesPositionLabel() {
        launch(preset: "typical")
        tapTab("Settings")
        waitFor(UITestID.settingsEditSplit).tap()

        let pull = waitFor(UITestID.splitDay("Pull"))
        let push = waitFor(UITestID.splitDay("Push"))
        XCTAssertTrue(pull.label.hasPrefix("2."))
        // Presets sit above the day list. Off-screen rows exist in the
        // tree; the drag has to start on a hittable row or the ScrollView
        // takes it. Hold long enough for the long-press to lock scrolling.
        scrollUntilHittable(pull)
        XCTAssertTrue(push.isHittable)
        pull.press(forDuration: 1.0, thenDragTo: push, withVelocity: .slow, thenHoldForDuration: 0.4)

        let moved = element(UITestID.splitDay("Pull"))
        XCTAssertTrue(moved.waitForExistence(timeout: 4))
        let settled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label BEGINSWITH '1.'"),
            object: moved
        )
        wait(for: [settled], timeout: 4)
    }
}
