//
//  ImportAndBackupUITests.swift
//  RockLogUITests
//

import XCTest

final class ImportAndBackupUITests: RockLogUITestCase {

    func test_programImport_unknownLift_keepsCurrentSplit() {
        launch(
            preset: "typical",
            environment: SyntheticPayloads.environment(json: SyntheticPayloads.programMysteryLift())
        )
        dismissAlert(button: "Add workouts")
        dismissAlert(button: "Keep my current split")
        XCTAssertTrue(app.buttons["OK"].waitForExistence(timeout: 4))
        app.buttons["OK"].tap()

        XCTAssertTrue(app.staticTexts["What's next"].waitForExistence(timeout: 8))
        XCTAssertTrue(element(UITestID.plannedRow("Push")).waitForExistence(timeout: 6))

        tapTab("Exercises")
        let search = app.textFields["Search exercises"].exists
            ? app.textFields["Search exercises"]
            : app.searchFields["Search exercises"]
        XCTAssertTrue(search.waitForExistence(timeout: 6))
        search.tap()
        search.typeText("UI Mystery Lift")
        XCTAssertTrue(app.staticTexts["UI Mystery Lift"].waitForExistence(timeout: 6))
    }

    func test_splitImport_replacesDays() {
        launch(
            preset: "typical",
            environment: SyntheticPayloads.environment(json: SyntheticPayloads.splitAlphaBeta())
        )
        dismissAlert(button: "Use this split")
        XCTAssertTrue(app.buttons["OK"].waitForExistence(timeout: 6))
        app.buttons["OK"].tap()
        XCTAssertTrue(element(UITestID.todayDay("UI Alpha")).waitForExistence(timeout: 8))
        XCTAssertTrue(element(UITestID.todayDay("UI Beta")).exists)
    }

    func test_splitImport_canKeepWaitingPlan() {
        launch(
            preset: "planWaiting",
            environment: SyntheticPayloads.environment(json: SyntheticPayloads.splitAlphaBeta())
        )
        dismissAlert(button: "Use this split")
        dismissAlert(button: "Keep them")
        XCTAssertTrue(app.buttons["OK"].waitForExistence(timeout: 4))
        app.buttons["OK"].tap()
        XCTAssertTrue(element(UITestID.plannedRow("Push")).waitForExistence(timeout: 8))
    }

    func test_badImport_showsErrorAndLeavesBench() {
        launch(
            preset: "typical",
            environment: SyntheticPayloads.environment(json: "{")
        )
        XCTAssertTrue(app.alerts["RockLog"].waitForExistence(timeout: 8))
        app.alerts["RockLog"].buttons["OK"].tap()
        selectPushIfNeeded()
        waitFor(UITestID.todayEditDay).tap()
        XCTAssertTrue(element(UITestID.dayPlanExercise("UI Bench Press")).waitForExistence(timeout: 6))
    }

    func test_restoreCancel_leavesSyntheticBench() {
        launch(
            preset: "typical",
            environment: SyntheticPayloads.environment(json: SyntheticPayloads.backupRestoredLift())
        )
        tapTab("Settings")
        dismissAlert(button: "Don't restore")
        XCTAssertFalse(app.staticTexts["UI Restored Lift"].exists)

        tapTab("Workout")
        selectPushIfNeeded()
        waitFor(UITestID.todayEditDay).tap()
        XCTAssertTrue(element(UITestID.dayPlanExercise("UI Bench Press")).waitForExistence(timeout: 6))
    }

    func test_restoreConfirm_replacesWithSyntheticBackup() {
        launch(
            preset: "typical",
            environment: SyntheticPayloads.environment(json: SyntheticPayloads.backupRestoredLift())
        )
        tapTab("Settings")
        dismissAlert(button: "Replace split and exercises")
        let restored = app.alerts["Success"]
        XCTAssertTrue(
            restored.waitForExistence(timeout: 12),
            "Restore removed Settings before its alert could show. Success has to come from the root."
        )
        let ok = restored.buttons["OK"]
        XCTAssertTrue(ok.isHittable)
        ok.tap()
        XCTAssertTrue(element(UITestID.todayDay("UI Day")).waitForExistence(timeout: 8))
        waitFor(UITestID.todayStart).tap()
        XCTAssertTrue(element(UITestID.workoutExercise("UI Restored Lift")).waitForExistence(timeout: 8))
        XCTAssertFalse(element(UITestID.workoutExercise("UI Bench Press")).exists)
    }

    /// #56 regression: a backup with repeated set ids used to be refused.
    func test_restoreConfirm_duplicateSetIDs_showsRepairNote() {
        let payload = SyntheticPayloads.backupDuplicateSetIDs()
        XCTAssertEqual(payload.components(separatedBy: "C3000000-0000-4000-8000-000000000004").count - 1, 3, "Fixture must repeat the set id")
        launch(
            preset: "typical",
            environment: SyntheticPayloads.environment(json: payload)
        )
        tapTab("Settings")
        dismissAlert(button: "Replace split and exercises")
        let restored = app.alerts["Success"]
        XCTAssertTrue(restored.waitForExistence(timeout: 12))
        let byID = restored.descendants(matching: .any)[UITestID.restoreNoticeMessage]
        let byText = restored.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "Removed 1 duplicate set. Gave 1 set a new ID")
        ).firstMatch
        if !byText.waitForExistence(timeout: 4) { print("ROCKLOG_ALERT_TREE \(restored.debugDescription)") }
        XCTAssertTrue(byText.exists, "Repair note text missing")
        print("ROCKLOG_RESTORE_NOTE_ID_EXISTS=\(byID.exists)")
        let ok = restored.buttons["OK"]
        XCTAssertTrue(ok.isHittable)
        ok.tap()
        XCTAssertTrue(element(UITestID.todayDay("UI Day")).waitForExistence(timeout: 8))
    }

    func test_restoreConfirm_weekALift_isHiddenWhenNextSessionIsWeekB() {
        launch(
            preset: "typical",
            environment: SyntheticPayloads.environment(json: SyntheticPayloads.backupRestoredWeekALift())
        )
        tapTab("Settings")
        dismissAlert(button: "Replace split and exercises")
        let restored = app.alerts["Success"]
        XCTAssertTrue(
            restored.waitForExistence(timeout: 12),
            "Restore removed Settings before its alert could show. Success has to come from the root."
        )
        let ok = restored.buttons["OK"]
        XCTAssertTrue(ok.isHittable)
        ok.tap()
        XCTAssertTrue(element(UITestID.todayDay("UI Day")).waitForExistence(timeout: 8))
        let start = waitFor(UITestID.todayStart)
        XCTAssertTrue(start.label.contains("B week"), start.label)
        start.tap()
        XCTAssertTrue(element(UITestID.workoutFinish).waitForExistence(timeout: 8))
        let aWeek = app.buttons["A week"]
        XCTAssertTrue(aWeek.waitForExistence(timeout: 6))
        XCTAssertFalse(element(UITestID.workoutExercise("UI A Week Lift")).exists)
        aWeek.tap()
        XCTAssertTrue(element(UITestID.workoutExercise("UI A Week Lift")).waitForExistence(timeout: 6))
    }
}
