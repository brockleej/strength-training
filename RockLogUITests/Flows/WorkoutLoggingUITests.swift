//
//  WorkoutLoggingUITests.swift
//  RockLogUITests
//

import XCTest

final class WorkoutLoggingUITests: RockLogUITestCase {

    func test_logEditDeleteFinish_andEffortPrompt() {
        launch(preset: "typical")
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()

        let fresh = waitFor(UITestID.workoutExercise("UI Fresh Lift"))
        fresh.tap()
        waitFor(UITestID.focusLogSet).tap()

        let logged = waitFor(UITestID.focusSet(1))
        scrollUntilHittable(logged)
        logged.tap()
        let editing = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "editing"),
            object: logged
        )
        wait(for: [editing], timeout: 6)
        waitFor(UITestID.stepperIncrease("Reps")).tap()
        waitFor(UITestID.focusUpdateSet).tap()

        let updated = waitFor(UITestID.focusSet(1))
        swipeToRemove(updated)
        XCTAssertFalse(element(UITestID.focusSet(1)).waitForExistence(timeout: 2))

        waitFor(UITestID.focusLogSet).tap()
        XCTAssertTrue(element(UITestID.focusSet(1)).waitForExistence(timeout: 6))
        waitFor(UITestID.focusBack).tap()

        waitFor(UITestID.workoutFinish).tap()
        confirmFinishWorkout()

        let rating = waitFor(UITestID.effortRating(8))
        rating.tap()
        waitFor(UITestID.effortSave).tap()

        XCTAssertTrue(app.staticTexts["Effort 8 · Hard"].waitForExistence(timeout: 8))
        let duration = waitFor(UITestID.summaryDuration)
        XCTAssertFalse(duration.label.contains("200"), "Build 17: duration must not show a multi-hour idle as 200.")
        waitFor(UITestID.summaryDone).tap()

        tapTab("History")
        XCTAssertFalse(element(UITestID.historyEmpty).exists)
        XCTAssertTrue(app.staticTexts["Push"].waitForExistence(timeout: 6))
    }

    func test_zeroWeightPrefill_logsWithoutAHugeDuration() {
        launch(preset: "typical")
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()
        waitFor(UITestID.workoutExercise("UI Fresh Lift")).tap()
        waitFor(UITestID.focusLogSet).tap()
        let setRow = waitFor(UITestID.focusSet(1))
        XCTAssertTrue(setRow.label.contains("0") || setRow.label.localizedCaseInsensitiveContains("weight"))
        waitFor(UITestID.focusBack).tap()
        waitFor(UITestID.workoutFinish).tap()
        confirmFinishWorkout()
        waitFor(UITestID.effortSkip).tap()
        let duration = waitFor(UITestID.summaryDuration)
        XCTAssertFalse(duration.label.contains("200"))
    }

    /// The set row's default accessibility action, not a coordinate tap, enters edit mode.
    func test_setRowAccessibilityAction_entersEditMode() {
        launch(preset: "typical")
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()
        waitFor(UITestID.workoutExercise("UI Fresh Lift")).tap()
        waitFor(UITestID.focusLogSet).tap()

        let logged = waitFor(UITestID.focusSet(1))
        scrollUntilHittable(logged)
        let activate = logged.buttons["Activate"]
        XCTAssertTrue(activate.waitForExistence(timeout: 4), "Set row is missing its default accessibility action")
        activate.tap()

        let editing = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "editing"),
            object: logged
        )
        wait(for: [editing], timeout: 6)
        XCTAssertTrue(element(UITestID.focusUpdateSet).waitForExistence(timeout: 4))
    }
}
