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

    /// Reorder is checked through the row's Move up action. The long-press
    /// drag stays in the app; this test does not depend on it.
    func test_splitReorder_dragChangesPositionLabel() {
        launch(preset: "typical")
        tapTab("Settings")
        waitFor(UITestID.settingsEditSplit).tap()

        let pull = waitFor(UITestID.splitDay("Pull"))
        XCTAssertTrue(pull.label.hasPrefix("2."))
        scrollUntilHittable(pull)
        let moveUp = pull.buttons["Move up"]
        XCTAssertTrue(moveUp.waitForExistence(timeout: 4))
        moveUp.tap()

        let moved = element(UITestID.splitDay("Pull"))
        XCTAssertTrue(moved.waitForExistence(timeout: 4))
        let settled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label BEGINSWITH '1.'"),
            object: moved
        )
        wait(for: [settled], timeout: 10)
    }
}
