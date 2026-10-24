//
//  FirstLaunchUITests.swift
//  RockLogUITests
//

import XCTest

final class FirstLaunchUITests: RockLogUITestCase {

    func test_firstLaunch_continueStaysDisabledUntilASplitIsPicked() {
        launch(preset: "empty")
        XCTAssertTrue(app.staticTexts["Pick a split or restore"].waitForExistence(timeout: 12))
        let continueButton = waitFor(UITestID.firstRunContinue)
        XCTAssertFalse(continueButton.isEnabled)

        element(UITestID.firstRunChoice("Push / Pull / Legs")).tap()
        XCTAssertTrue(continueButton.isEnabled)
    }

    func test_firstLaunch_leaveEmpty_showsEmptyHistoryAndNoSyntheticLifts() {
        launch(preset: "empty")
        element(UITestID.firstRunChoice("Push / Pull / Legs")).tap()
        waitFor(UITestID.firstRunContinue).tap()
        waitFor(UITestID.firstRunLeaveEmpty).tap()
        waitFor(UITestID.firstRunContinue).tap()
        waitFor(UITestID.firstRunSkip).tap()

        tapTab("History")
        XCTAssertTrue(element(UITestID.historyEmpty).waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["No workouts yet"].exists)

        tapTab("Workout")
        let push = element(UITestID.todayDay("Push"))
        if push.waitForExistence(timeout: 4) { push.tap() }
        waitFor(UITestID.todayStart).tap()
        XCTAssertTrue(app.staticTexts["Add exercise"].waitForExistence(timeout: 8))
        XCTAssertFalse(element(UITestID.workoutExercise("UI Bench Press")).exists)
    }

    func test_firstLaunch_starters_pinACatalogBench() {
        launch(preset: "empty")
        element(UITestID.firstRunChoice("Push / Pull / Legs")).tap()
        waitFor(UITestID.firstRunContinue).tap()
        waitFor(UITestID.firstRunStarters).tap()
        waitFor(UITestID.firstRunContinue).tap()
        waitFor(UITestID.firstRunSkip).tap()

        tapTab("Workout")
        let push = element(UITestID.todayDay("Push"))
        if push.waitForExistence(timeout: 4) { push.tap() }
        waitFor(UITestID.todayStart).tap()
        XCTAssertTrue(
            element(UITestID.workoutExercise("Dumbbell Bench Press")).waitForExistence(timeout: 8)
        )
    }
}
