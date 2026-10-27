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

        let logged = tapHittableSet(1)
        waitUntilEditing(logged)
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

    /// The set row is the button. A tap on that element enters edit mode.
    func test_setRowAccessibilityAction_entersEditMode() {
        launch(preset: "typical")
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()
        waitFor(UITestID.workoutExercise("UI Fresh Lift")).tap()
        waitFor(UITestID.focusLogSet).tap()

        let logged = tapHittableSet(1)
        waitUntilEditing(logged)
        XCTAssertTrue(element(UITestID.focusUpdateSet).waitForExistence(timeout: 4))
    }

    /// Bench has a last-time control beside the set. Tapping the set identifier
    /// must edit; that control stays a separate element outside the set's frame.
    func test_comparisonRowTap_selectsSetNotLastTime() {
        launch(preset: "typical")
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()
        waitFor(UITestID.workoutExercise("UI Bench Press")).tap()
        waitFor(UITestID.focusLogSet).tap()

        let lastTime = waitFor(UITestID.focusLoadLast(1))
        let logged = waitFor(UITestID.focusSet(1))
        scrollUntilHittable(logged)
        XCTAssertTrue(logged.isHittable, "focus.set.1 is not hittable")
        XCTAssertTrue(lastTime.isHittable, "focus.loadLast.1 is not hittable")
        XCTAssertNotEqual(lastTime.identifier, logged.identifier)
        let setCenter = CGPoint(x: logged.frame.midX, y: logged.frame.midY)
        XCTAssertFalse(
            lastTime.frame.contains(setCenter),
            "focus.set center sits on the last-time control, so a tap loads last time instead of editing."
        )
        logged.tap()
        waitUntilEditing(logged)
        XCTAssertTrue(element(UITestID.focusUpdateSet).waitForExistence(timeout: 4))
        XCTAssertTrue(lastTime.exists, "Selecting the set should leave the last-time control in place")
    }

    /// Tap the set by its identifier once it is on screen. Never a fixed coordinate.
    private func tapHittableSet(_ number: Int) -> XCUIElement {
        let row = waitFor(UITestID.focusSet(number))
        scrollUntilHittable(row)
        XCTAssertTrue(row.isHittable, "\(UITestID.focusSet(number)) is not hittable")
        row.tap()
        return row
    }

    private func waitUntilEditing(_ row: XCUIElement, timeout: TimeInterval = 6) {
        let editing = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "editing"),
            object: row
        )
        wait(for: [editing], timeout: timeout)
    }
}
