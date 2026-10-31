//
//  WorkoutLoggingUITests.swift
//  RockLogUITests
//

import XCTest

final class WorkoutLoggingUITests: RockLogUITestCase {

    func test_logEditDeleteFinish_andEffortPrompt() {
        openLift("UI Fresh Lift")
        waitForLogSet().tap()

        let logged = tapSet(1)
        waitUntilEditing(logged)
        waitFor(UITestID.stepperIncrease("Reps")).tap()
        waitFor(UITestID.focusUpdateSet).tap()

        let updated = waitFor(UITestID.focusSet(1))
        deleteLoggedSet(updated)
        XCTAssertFalse(element(UITestID.focusSet(1)).waitForExistence(timeout: 2))

        waitForLogSet().tap()
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
        waitForLogSet().tap()
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
    func test_setRowTap_entersEditMode() {
        openLift("UI Fresh Lift")
        waitForLogSet().tap()
        let logged = tapSet(1)
        waitUntilEditing(logged)
        XCTAssertTrue(element(UITestID.focusUpdateSet).waitForExistence(timeout: 4))
    }

    /// Bench has a last-time control beside the set. Tapping the set identifier
    /// must edit; that control stays a separate element outside the set's frame.
    func test_comparisonRowTap_selectsSetNotLastTime() {
        openLift("UI Bench Press")
        waitForLogSet().tap()

        let lastTime = waitFor(UITestID.focusLoadLast(1))
        let logged = waitFor(UITestID.focusSet(1))
        scrollUntilHittable(logged)
        scrollClearOfStepper(logged)
        let layout = narrowLayoutLine(around: logged)
        if !layout.isEmpty {
            print(layout)
        }
        XCTAssertGreaterThanOrEqual(logged.frame.height, 44, "focus.set.1 is shorter than 44. \(layout)")
        XCTAssertTrue(logged.isHittable, "focus.set.1 is not hittable. \(layout)")
        let lastCenter = CGPoint(x: lastTime.frame.midX, y: lastTime.frame.midY)
        XCTAssertTrue(
            lastTime.isHittable,
            "focus.loadLast.1 is not hittable. last=\(frameDescription(lastTime)) set=\(frameDescription(logged)) owner=\(elementOwning(lastCenter)) window=\(format(app.windows.firstMatch.frame)) progress=\(frameDescription(element(UITestID.focusSetProgress))) logSet=\(frameDescription(element(UITestID.focusLogSet)))"
        )
        XCTAssertNotEqual(lastTime.identifier, logged.identifier)
        let setCenter = CGPoint(x: logged.frame.midX, y: logged.frame.midY)
        XCTAssertFalse(
            lastTime.frame.contains(setCenter),
            "focus.set center sits on the last-time control, so a tap loads last time instead of editing. \(layout)"
        )
        let stepper = element(UITestID.stepperIncrease("Weight"))
        if stepper.exists {
            XCTAssertFalse(
                stepper.frame.contains(setCenter),
                "focus.set center sits on the weight stepper. \(layout)"
            )
        }
        logged.tap()
        waitUntilEditing(logged)
        XCTAssertTrue(element(UITestID.focusUpdateSet).waitForExistence(timeout: 4))
        XCTAssertTrue(lastTime.exists, "Selecting the set should leave the last-time control in place")
    }

    /// Regression (1.2 run 20261030-234727): the "Set 2 of 4" cue sat in the pinned
    /// footer, made it taller, and pushed the just-logged row behind the steppers
    /// so "last time" for set 1 was not tappable on iPhone 17 Pro.
    func test_regression_setProgress_staysAboveSetRows_notInFooter() {
        openLift("UI Bench Press")
        waitForLogSet().tap()
        let progress = waitFor(UITestID.focusSetProgress)
        let lastTime = waitFor(UITestID.focusLoadLast(1))
        XCTAssertLessThan(progress.frame.maxY, lastTime.frame.minY, "set progress should sit on the sets heading, above the rows")
        // Reachable by a normal scroll on every phone (SE needs one swipe).
        scrollUntilHittable(lastTime)
        XCTAssertTrue(lastTime.isHittable, "set 1 last-time control stays covered after scrolling")
    }

    private func openLift(_ name: String) {
        launch(preset: "typical", extra: [UITestID.diagControlArgument])
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()
        waitFor(UITestID.workoutExercise(name)).tap()
    }

    @discardableResult
    private func tapSet(_ number: Int) -> XCUIElement {
        let row = waitFor(UITestID.focusSet(number))
        scrollUntilHittable(row)
        scrollClearOfStepper(row)
        let layout = narrowLayoutLine(around: row)
        if !layout.isEmpty {
            print(layout)
        }
        row.tap()
        return row
    }

    private func deleteLoggedSet(_ row: XCUIElement) {
        row.swipeLeft()
        if element(UITestID.focusSet(1)).exists {
            tapMenuItem(identifier: UITestID.setDelete, label: "Delete")
        }
    }

    /// On a phone 375pt wide or narrower, record the set frame, whatever owns
    /// its center, and the last-time and stepper frames. `-RockLogDiag` is on.
    private func narrowLayoutLine(around row: XCUIElement) -> String {
        let width = app.windows.firstMatch.frame.width
        guard width <= 375 else { return "" }
        let center = CGPoint(x: row.frame.midX, y: row.frame.midY)
        let last = element(UITestID.focusLoadLast(1))
        let stepper = element(UITestID.stepperIncrease("Weight"))
        return "SE layout width=\(format(width)) set=\(format(row.frame)) centerOwner=\(elementOwning(center)) last=\(frameDescription(last)) stepper=\(frameDescription(stepper))"
    }

    private func scrollClearOfStepper(_ row: XCUIElement) {
        let stepper = element(UITestID.stepperIncrease("Weight"))
        guard stepper.exists else { return }
        let scroll = app.scrollViews.firstMatch
        var attempts = 0
        while attempts < 4, stepper.frame.intersects(row.frame), scroll.exists {
            scroll.swipeUp(velocity: .slow)
            attempts += 1
        }
    }

    private func elementOwning(_ center: CGPoint) -> String {
        let query = app.descendants(matching: .any)
        let limit = min(query.count, 800)
        var bestArea = CGFloat.greatestFiniteMagnitude
        var best = "none"
        for index in 0..<limit {
            let match = query.element(boundBy: index)
            let frame = match.frame
            guard frame.width > 1, frame.height > 1, frame.contains(center) else { continue }
            let area = frame.width * frame.height
            guard area < bestArea else { continue }
            bestArea = area
            best = "id=\(match.identifier) label=\(match.label) frame=\(format(frame))"
        }
        return best
    }

    private func frameDescription(_ match: XCUIElement) -> String {
        guard match.exists else { return "missing" }
        return "id=\(match.identifier) frame=\(format(match.frame))"
    }

    private func format(_ frame: CGRect) -> String {
        String(format: "%.1f,%.1f,%.1f,%.1f", frame.minX, frame.minY, frame.width, frame.height)
    }

    private func format(_ value: CGFloat) -> String {
        String(format: "%.1f", value)
    }

    private func waitUntilEditing(_ row: XCUIElement, timeout: TimeInterval = 6) {
        let editing = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "editing", "editing"),
            object: row
        )
        let result = XCTWaiter.wait(for: [editing], timeout: timeout)
        guard result == .completed else {
            let seenValue = (row.value as? String) ?? String(describing: row.value ?? "nil")
            XCTFail("focus.set did not show editing in label or value. label=\(row.label) value=\(seenValue) \(narrowLayoutLine(around: row))")
            return
        }
    }
}
