//
//  Build121UITests.swift
//  RockLogUITests
//
//  1.2.1 fixes from Lee's 1.2 notes (Nov 9–11 2026). Synthetic presets only.
//

import XCTest

final class Build121UITests: RockLogUITestCase {

    /// Nov 9: Focus showed only "last" and no PLAN column. The plan was looked up
    /// only in the Strength/Endurance mode the app-wide switch was on.
    func test_plannedTarget_staysVisible_afterSwitchingToEndurance() {
        launch(preset: "planWaiting")
        waitFor(UITestID.todayStart).tap()
        let bench = waitFor(UITestID.workoutExercise("UI Bench Press"))
        let endurance = app.buttons["Endurance"]
        XCTAssertTrue(endurance.waitForExistence(timeout: 6), "Mode switch on the workout list")
        endurance.tap()
        bench.tap()
        _ = waitForLogSet()
        XCTAssertTrue(element(UITestID.focusLoadPlan(1)).waitForExistence(timeout: 8),
                      "PLAN column must still show with the switch on Endurance")
    }

    /// Nov 11: after the last set of a lift in a circuit, stay on that lift so Done
    /// is right there (no jump to the next lift, no drop back to the list).
    func test_circuit_lastSetOfALift_staysForDone() {
        makeCircuitA()
        waitFor(UITestID.workoutCircuitStart("A")).tap()
        XCTAssertTrue(element(UITestID.focusCircuitRound).waitForExistence(timeout: 8))
        // Rounds 1 and 2: Bench → Fresh, auto-advancing (no plan = 3 rounds; rest is off).
        for _ in 0..<4 {
            waitForLogSet().tap()
        }
        // Round 3 on Bench: its last set. Stay on Bench.
        XCTAssertTrue(element(UITestID.focusSet(2)).waitForExistence(timeout: 6))
        waitForLogSet().tap()
        XCTAssertTrue(element(UITestID.focusSet(3)).waitForExistence(timeout: 6),
                      "Still on Bench with its 3 sets, not jumped to Fresh (2 sets)")
        let done = waitFor(UITestID.focusDone)
        XCTAssertTrue(done.isHittable, "Done is right there after the last set")
        done.tap()
        // Done moves on to the lift that still owes its last set.
        XCTAssertTrue(element(UITestID.focusSet(2)).waitForExistence(timeout: 6))
        XCTAssertFalse(element(UITestID.focusSet(3)).waitForExistence(timeout: 2), "Now on Fresh (2 sets)")
        waitForLogSet().tap()
        // Last set of the whole circuit: stay on Fresh too instead of dropping to the list.
        XCTAssertTrue(element(UITestID.focusSet(3)).waitForExistence(timeout: 6))
        XCTAssertTrue(element(UITestID.focusDone).isHittable)
        XCTAssertTrue(element(UITestID.focusLogSet).exists, "Still on Focus, not back on the list")
    }

    /// Nov 10: "the rest footer gets in the way of navigation". The Rest / Workout bar
    /// was drawn over the floating tab bar (every tab covered on a Pro Max).
    func test_restBar_neverCoversTheTabs_orFocusNavigation() {
        launch(preset: "typical", extra: ["-RockLogRestTimer", "on"])
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()
        assertBarClearsTabs("list")
        waitFor(UITestID.workoutExercise("UI Fresh Lift")).tap()
        waitForLogSet().tap()
        XCTAssertTrue(waitFor(UITestID.restSkip).isHittable)
        // Focus while resting: back, previous/next, Log set, Done and every tab are tappable.
        for id in [UITestID.focusBack, UITestID.focusPrevious, UITestID.focusNext, UITestID.focusLogSet, UITestID.focusDone] {
            let control = element(id)
            if control.exists { XCTAssertTrue(control.isHittable, "focus: \(id) is covered. frame=\(control.frame)") }
        }
        assertBarClearsTabs("focus", barRequired: false)
        waitFor(UITestID.focusBack).tap()
        let bar = waitFor(UITestID.activeWorkoutBar)
        XCTAssertTrue(bar.label.hasPrefix("Rest"), "Still counting down on the list: \(bar.label)")
        assertBarClearsTabs("list-resting")
        tapTab("Settings")
        assertBarClearsTabs("settings")
    }

    private func assertBarClearsTabs(_ tag: String, barRequired: Bool = true) {
        let bar = element(UITestID.activeWorkoutBar)
        if barRequired {
            XCTAssertTrue(bar.waitForExistence(timeout: 6), "\(tag): Rest / Workout bar missing")
        }
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists, bar.exists {
            XCTAssertLessThanOrEqual(bar.frame.maxY, tabBar.frame.minY + 1,
                                     "\(tag): bar \(bar.frame) overlaps the tab bar \(tabBar.frame)")
        }
        for name in ["Workout", "History", "Progress", "Exercises", "Settings"] {
            let tab = app.tabBars.buttons[name]
            if tab.exists { XCTAssertTrue(tab.isHittable, "\(tag): tab \(name) is covered. frame=\(tab.frame)") }
        }
    }

    /// Circuit A = UI Bench Press → UI Fresh Lift, saved for today. Rest timer stays off.
    private func makeCircuitA() {
        launch(preset: "typical")
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()
        XCTAssertTrue(element(UITestID.workoutExercise("UI Fresh Lift")).waitForExistence(timeout: 8))
        let more = app.buttons["More options"]
        XCTAssertTrue(more.waitForExistence(timeout: 6))
        more.tap()
        let reorder = app.buttons["Reorder today's list"]
        XCTAssertTrue(reorder.waitForExistence(timeout: 4))
        reorder.tap()
        waitFor(UITestID.workoutCircuit).tap()
        waitFor(UITestID.circuitPick("UI Bench Press")).tap()
        waitFor(UITestID.circuitPick("UI Fresh Lift")).tap()
        waitFor(UITestID.circuitCreate).tap()
        XCTAssertTrue(element(UITestID.reorderCircuit("A")).waitForExistence(timeout: 6))
        waitFor(UITestID.workoutSaveToday).tap()
    }
}
