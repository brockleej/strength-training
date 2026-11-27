//
//  Build122UITests.swift
//  RockLogUITests
//
//  1.2.2 items from Lee's notes (Nov 14 and Nov 19 2026). Synthetic presets only.
//

import XCTest

final class Build122UITests: RockLogUITestCase {

    /// Nov 14: "This screen needs an upper A/B or lower A/B". planWaiting queues
    /// Push (A week) then Pull (B week).
    func test_whatsNext_rowsAndStart_showTheWeek() {
        launch(preset: "planWaiting")
        let push = waitFor(UITestID.plannedRow("Push"))
        XCTAssertTrue(push.label.contains("Push A"), "Row label: \(push.label)")
        let pull = waitFor(UITestID.plannedRow("Pull"))
        XCTAssertTrue(pull.label.contains("Pull B"), "Row label: \(pull.label)")
        let start = waitFor(UITestID.todayStart)
        XCTAssertTrue(start.label.contains("Start Push A"), "Start label: \(start.label)")
        XCTAssertFalse(start.label.contains("A week"), "Not Today's picker label")

        pull.tap()
        let previewStart = waitFor(UITestID.plannedPreviewStart)
        XCTAssertTrue(previewStart.label.contains("Pull B"), "Preview Start label: \(previewStart.label)")
    }

    /// Nov 19: "after I hit done on an exercise, there's not an easy way back into
    /// that exercise to edit it." Done moves on; "Edit sets" goes straight back.
    func test_afterDone_editSetsGoesBackIntoTheLift_andEditsASet() {
        launch(preset: "typical")
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()
        waitFor(UITestID.workoutExercise("UI Bench Press")).tap()
        waitForLogSet().tap()
        XCTAssertTrue(element(UITestID.focusSet(1)).waitForExistence(timeout: 6))

        waitFor(UITestID.focusDone).tap()
        // Now on UI Fresh Lift, which has no sets yet.
        XCTAssertFalse(element(UITestID.focusSet(1)).waitForExistence(timeout: 2), "Moved to the next lift")
        let reopen = waitFor(UITestID.focusReopenFinished)
        XCTAssertTrue(reopen.isHittable, "Edit sets is on screen. frame=\(reopen.frame)")
        reopen.tap()

        // Back on Bench with its logged set. Tap it, change reps, update.
        let row = waitFor(UITestID.focusSet(1))
        XCTAssertFalse(element(UITestID.focusReopenFinished).exists, "Banner gone once back in")
        scrollUntilHittable(row)
        let before = row.label
        row.tap()
        let editing = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "editing", "editing"),
            object: row
        )
        XCTAssertEqual(XCTWaiter.wait(for: [editing], timeout: 6), .completed, "Set 1 opened for editing")
        waitFor(UITestID.stepperIncrease("Reps")).tap()
        waitFor(UITestID.focusUpdateSet).tap()
        let updated = waitFor(UITestID.focusSet(1))
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", before),
            object: updated
        )
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 6), .completed,
                       "Set 1 changed after the edit. before=\(before) after=\(updated.label)")
    }

    /// The other way back in: the workout list marks a done lift "Edit" and opens it.
    func test_afterDone_listRowSaysEdit_andOpensTheLift() {
        launch(preset: "typical")
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()
        waitFor(UITestID.workoutExercise("UI Bench Press")).tap()
        waitForLogSet().tap()
        XCTAssertTrue(element(UITestID.focusSet(1)).waitForExistence(timeout: 6))
        waitFor(UITestID.focusDone).tap()
        XCTAssertTrue(element(UITestID.focusReopenFinished).waitForExistence(timeout: 6))

        waitFor(UITestID.focusBack).tap()
        let bench = waitFor(UITestID.workoutExercise("UI Bench Press"))
        XCTAssertTrue(bench.label.contains("tap to edit"), "Done row label: \(bench.label)")
        bench.tap()
        XCTAssertTrue(element(UITestID.focusSet(1)).waitForExistence(timeout: 8), "Opened Bench with its logged set")
        XCTAssertTrue(element(UITestID.focusDone).label.contains("Resume"), "Still marked done until he edits or resumes")
    }

    /// Nov 19: "the kneeling hamstring goes by tens, the leg extension goes by 15s".
    /// Pick Every 15 lb on the lift; + and − move by 15.
    func test_weightStepper_movesByTheMachineStep() {
        launch(preset: "typical")
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()
        waitFor(UITestID.workoutExercise("UI Fresh Lift")).tap()
        _ = waitForLogSet()

        let steps = waitFor(UITestID.stackOverride)
        scrollUntilHittable(steps)
        steps.tap()
        let every15 = app.buttons["Every 15 lb"]
        XCTAssertTrue(every15.waitForExistence(timeout: 4), "Machine steps menu")
        every15.tap()
        XCTAssertTrue(waitFor(UITestID.stackOverride).label.contains("15"), "Pill shows the step")

        let plus = waitFor(UITestID.stepperIncrease("Weight"))
        let start = weight(plus)
        plus.tap()
        XCTAssertEqual(weight(plus), start + 15, accuracy: 0.01, "+ moves by the machine step")
        plus.tap()
        XCTAssertEqual(weight(plus), start + 30, accuracy: 0.01)
        let minus = waitFor(UITestID.stepperDecrease("Weight"))
        minus.tap()
        XCTAssertEqual(weight(plus), start + 15, accuracy: 0.01, "− moves by the machine step")
    }

    private func weight(_ button: XCUIElement) -> Double {
        Double((button.value as? String) ?? "") ?? -1
    }
}
