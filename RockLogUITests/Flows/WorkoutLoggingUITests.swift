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
        printTEMPEditDeliveries("after set tap")
        waitUntilEditing(logged)
        printTEMPEditDeliveries("after editing")
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
        assertTEMPProbeBumpsReadout()

        let logged = tapHittableSet(1)
        printTEMPEditDeliveries("after set tap")
        waitUntilEditing(logged)
        printTEMPEditDeliveries("after editing")
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
        attachTapScreenshot()
        logged.tap()
        printTEMPEditDeliveries("after comparison tap")
        waitUntilEditing(logged)
        printTEMPEditDeliveries("after comparison editing")
        XCTAssertTrue(element(UITestID.focusUpdateSet).waitForExistence(timeout: 4))
        XCTAssertTrue(lastTime.exists, "Selecting the set should leave the last-time control in place")
    }

    /// Tap the set by its identifier once it is on screen. Never a fixed coordinate.
    private func tapHittableSet(_ number: Int) -> XCUIElement {
        let row = waitFor(UITestID.focusSet(number))
        scrollUntilHittable(row)
        XCTAssertTrue(row.isHittable, "\(UITestID.focusSet(number)) is not hittable")
        attachTapScreenshot()
        row.tap()
        return row
    }

    /// TEMP: remove before merge. A control outside swipeToDelete must move the readout.
    private func assertTEMPProbeBumpsReadout() {
        let probe = waitFor(UITestID.focusEditDeliveryProbeTEMP)
        scrollUntilHittable(probe)
        XCTAssertTrue(probe.isHittable, "TEMP probe is not hittable")
        probe.tap()
        let readout = editDeliveryValue()
        print("TEMP probe readout: \(readout)")
        XCTAssertTrue(
            readout.contains("probe=1@"),
            "TEMP counter readout did not update outside swipeToDelete: \(readout)"
        )
    }

    /// TEMP: remove before merge. Prints gesture, accessibility, and id-change counts.
    private func printTEMPEditDeliveries(_ note: String) {
        let text = editDeliveryValue()
        print("TEMP edit-delivery \(note): \(text)")
        XCTContext.runActivity(named: "TEMP edit-delivery \(note): \(text)") { _ in }
    }

    private func editDeliveryValue() -> String {
        let probe = element(UITestID.focusEditDeliveryTEMP)
        guard probe.waitForExistence(timeout: 2) else { return "missing" }
        if let value = probe.value as? String, !value.isEmpty {
            return value
        }
        return probe.label
    }

    private func waitUntilEditing(_ row: XCUIElement, timeout: TimeInterval = 6) {
        let editing = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "editing", "editing"),
            object: row
        )
        let result = XCTWaiter.wait(for: [editing], timeout: timeout)
        guard result == .completed else {
            let dump = focusSetDump(1)
            let delivery = editDeliveryValue()
            print("TEMP edit-delivery on timeout: \(delivery)")
            print("TEMP focus.set dump: \(dump)")
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "TEMP focus hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "TEMP focus screenshot"
            shot.lifetime = .keepAlways
            add(shot)
            let seenValue = (row.value as? String) ?? String(describing: row.value ?? "nil")
            XCTFail("focus.set did not show editing in label or value. label=\(row.label) value=\(seenValue) delivery=\(delivery) \(dump)")
            return
        }
    }

    private func attachTapScreenshot() {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "TEMP screenshot at set tap"
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func focusSetDump(_ number: Int) -> String {
        let query = app.descendants(matching: .any).matching(identifier: UITestID.focusSet(number))
        var lines = ["count=\(query.count)"]
        for index in 0..<query.count {
            lines.append(describeElement(query.element(boundBy: index), index: index))
        }
        if query.count > 0 {
            lines.append("centerOwner=\(elementOwningCenter(of: query.element(boundBy: 0)))")
        }
        return lines.joined(separator: " | ")
    }

    private func describeElement(_ match: XCUIElement, index: Int) -> String {
        let value = (match.value as? String) ?? String(describing: match.value ?? "nil")
        let frame = match.frame
        return "[\(index)] type=\(match.elementType.rawValue) identifier=\(match.identifier) label=\(match.label) value=\(value) enabled=\(match.isEnabled) hittable=\(match.isHittable) frame=(\(frame.minX),\(frame.minY),\(frame.width),\(frame.height))"
    }

    /// Smallest element whose frame contains the set row's center.
    private func elementOwningCenter(of row: XCUIElement) -> String {
        let center = CGPoint(x: row.frame.midX, y: row.frame.midY)
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
            let value = (match.value as? String) ?? ""
            best = "type=\(match.elementType.rawValue) identifier=\(match.identifier) label=\(match.label) value=\(value) enabled=\(match.isEnabled) hittable=\(match.isHittable)"
        }
        return best
    }
}
