//
//  WorkoutLoggingUITests.swift
//  RockLogUITests
//

import XCTest

final class WorkoutLoggingUITests: RockLogUITestCase {

    func test_logEditDeleteFinish_andEffortPrompt() {
        runLogEditDeleteFinish(plainSetRows: false)
    }

    func test_logEditDeleteFinish_andEffortPrompt_plainSetRows() {
        runLogEditDeleteFinish(plainSetRows: true)
    }

    private func runLogEditDeleteFinish(plainSetRows: Bool) {
        launchLogging(plainSetRows: plainSetRows)
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()

        let fresh = waitFor(UITestID.workoutExercise("UI Fresh Lift"))
        fresh.tap()
        waitFor(UITestID.focusLogSet).tap()
        noteLogSetTapped()
        tapDiagControl()

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
        runSetRowAccessibilityAction(plainSetRows: false)
    }

    func test_setRowAccessibilityAction_entersEditMode_plainSetRows() {
        runSetRowAccessibilityAction(plainSetRows: true)
    }

    private func runSetRowAccessibilityAction(plainSetRows: Bool) {
        launchLogging(plainSetRows: plainSetRows)
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()
        waitFor(UITestID.workoutExercise("UI Fresh Lift")).tap()
        waitFor(UITestID.focusLogSet).tap()
        noteLogSetTapped()
        tapDiagControl()
        tapProbeWithoutAssert()

        let logged = tapHittableSet(1)
        printTEMPEditDeliveries("after set tap")
        waitUntilEditing(logged)
        printTEMPEditDeliveries("after editing")
        XCTAssertTrue(element(UITestID.focusUpdateSet).waitForExistence(timeout: 4))
    }

    /// Bench has a last-time control beside the set. Tapping the set identifier
    /// must edit; that control stays a separate element outside the set's frame.
    func test_comparisonRowTap_selectsSetNotLastTime() {
        runComparisonRowTap(plainSetRows: false)
    }

    func test_comparisonRowTap_selectsSetNotLastTime_plainSetRows() {
        runComparisonRowTap(plainSetRows: true)
    }

    private func runComparisonRowTap(plainSetRows: Bool) {
        launchLogging(plainSetRows: plainSetRows)
        selectPushIfNeeded()
        waitFor(UITestID.todayStart).tap()
        waitFor(UITestID.workoutExercise("UI Bench Press")).tap()
        waitFor(UITestID.focusLogSet).tap()
        noteLogSetTapped()
        tapDiagControl()

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
        noteBeforeSetTap()
        logFrameReads(logged)
        collectedHeight = logged.frame.height
        collectedButtonCount = app.buttons.matching(identifier: UITestID.focusSet(1)).count
        logged.tap()
        printHitOwner("after comparison tap")
        printFrameReadouts("after comparison tap")
        printTEMPEditDeliveries("after comparison tap")
        assertTapDiagnostics(logged)
        waitUntilEditing(logged)
        printTEMPEditDeliveries("after comparison editing")
        XCTAssertTrue(element(UITestID.focusUpdateSet).waitForExistence(timeout: 4))
        XCTAssertTrue(lastTime.exists, "Selecting the set should leave the last-time control in place")
    }

    private func launchLogging(plainSetRows: Bool) {
        loggingMode = plainSetRows ? "plain" : "wrapper"
        var extra = [UITestID.touchLogArgument, UITestID.diagControlArgument]
        if plainSetRows {
            extra.append(UITestID.plainSetRowsArgument)
        }
        launch(preset: "typical", extra: extra)
    }

    private var loggingMode = "wrapper"

    /// Same scroll, then element.tap(), as the set row.
    private func tapDiagControl() {
        let control = waitFor(UITestID.focusDiagControl)
        scrollUntilHittable(control)
        control.tap()
    }

    private func tapProbeWithoutAssert() {
        let probe = waitFor(UITestID.focusEditDeliveryProbeTEMP)
        scrollUntilHittable(probe)
        probe.tap()
    }

    /// Tap the set by its identifier once it is on screen. Never a fixed coordinate.
    private func tapHittableSet(_ number: Int) -> XCUIElement {
        let row = waitFor(UITestID.focusSet(number))
        scrollUntilHittable(row)
        scrollUntilHittable(row)
        noteBeforeSetTap()
        logFrameReads(row)
        collectedHeight = row.frame.height
        collectedButtonCount = app.buttons.matching(identifier: UITestID.focusSet(number)).count
        row.tap()
        printHitOwner("after set tap")
        printFrameReadouts("after set tap")
        assertTapDiagnostics(row)
        return row
    }

    private var collectedHeight: CGFloat = 0
    private var collectedButtonCount = 0

    private func assertTapDiagnostics(_ row: XCUIElement) {
        let delivery = editDeliveryValue()
        let control = element(UITestID.focusDiagControl)
        let controlDiag = (control.value as? String) ?? "missing"
        let line = "mode=\(loggingMode) height=\(collectedHeight) count=\(collectedButtonCount) controlDiag=\(controlDiag) rowButton=\(stampCount(delivery, "button")) gesture=\(stampCount(delivery, "gesture")) accessibility=\(stampCount(delivery, "accessibility")) probe=\(stampCount(delivery, "probe"))"
        print("TEMP summary \(line)")
        let heightOK = collectedHeight >= 40
        let diagOK = controlDiag.contains("diag=1")
        XCTAssertTrue(heightOK && diagOK, line)
    }

    private func stampCount(_ delivery: String, _ key: String) -> String {
        guard let range = delivery.range(of: "\(key)=") else { return "?" }
        let digits = delivery[range.upperBound...].prefix { $0.isNumber }
        return digits.isEmpty ? "?" : String(digits)
    }

    /// Immediate frame reads only. The tap stays row.tap() and is not delayed.
    private func logFrameReads(_ row: XCUIElement) {
        var lines: [String] = []
        for index in 0..<4 {
            lines.append("TEMP frame[\(index)] \(formatFrame(row.frame))")
        }
        let frame = row.frame
        lines.append("TEMP xctestFrame=\(formatFrame(frame)) tap=\(frame.midX),\(frame.midY)")
        lastFrameLog = lines.joined(separator: " | ")
        print(lastFrameLog)
    }

    private func printFrameReadouts(_ note: String) {
        let line = "TEMP readouts \(note) touch=\(touchLogValue()) delivery=\(editDeliveryValue())"
        lastFrameLog += " | \(line)"
        print(line)
    }

    private func formatFrame(_ frame: CGRect) -> String {
        String(format: "%.1f,%.1f,%.1f,%.1f", frame.minX, frame.minY, frame.width, frame.height)
    }

    private var lastFrameLog = ""

    private var logSetTapAt: Date?

    /// TEMP: remove before merge. Snapshot immediately after Log set.
    private func noteLogSetTapped() {
        logSetTapAt = Date()
        attachTouchDiagnostics("after logSet")
    }

    /// TEMP: remove before merge. Snapshot immediately before the set-row tap.
    private func noteBeforeSetTap() {
        let elapsed: String
        if let start = logSetTapAt {
            elapsed = String(format: "%.0f", Date().timeIntervalSince(start) * 1000)
        } else {
            elapsed = "unset"
        }
        let buttonCount = app.buttons.matching(identifier: UITestID.focusSet(1)).count
        let tree = trimmedFocusTree()
        lastFrameLog += " | TEMP focus.set.1 buttons=\(buttonCount) focusTree=\(tree)"
        print("TEMP logSet-to-tap ms=\(elapsed) focus.set.1 buttons=\(buttonCount)")
        print("TEMP focusTree \(tree)")
        attachTouchDiagnostics("before set tap")
    }

    private func trimmedFocusTree() -> String {
        let full = app.debugDescription
        let needle = full.range(of: "focus.set") ?? full.range(of: "focus.logSet")
        guard let needle else { return "no-focus-subtree" }
        let start = full.index(needle.lowerBound, offsetBy: -500, limitedBy: full.startIndex) ?? full.startIndex
        let end = full.index(needle.upperBound, offsetBy: 1500, limitedBy: full.endIndex) ?? full.endIndex
        return full[start..<end].replacingOccurrences(of: "\n", with: " | ")
    }

    private func touchLogValue() -> String {
        let probe = element(UITestID.focusTouchLogTEMP)
        guard probe.waitForExistence(timeout: 2) else { return "missing" }
        if let value = probe.value as? String, !value.isEmpty {
            return value
        }
        return probe.label
    }

    private func printHitOwner(_ note: String) {
        let text = touchLogValue()
        print("TEMP hit-test \(note): \(text)")
        XCTContext.runActivity(named: "TEMP hit-test \(note)") { _ in }
    }

    private func attachTouchDiagnostics(_ note: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "TEMP \(note) screenshot"
        shot.lifetime = .keepAlways
        add(shot)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "TEMP \(note) hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        let banner = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier CONTAINS[c] %@ OR identifier CONTAINS[c] %@ OR identifier CONTAINS[c] %@", "banner", "toast", "prompt")
        ).firstMatch
        lastSurfaceNote = "TEMP \(note) keyboards=\(app.keyboards.count) sheets=\(app.sheets.count) alerts=\(app.alerts.count) bannerOrToastOrPrompt=\(banner.exists) effort=\(element(UITestID.effortSave).exists)"
        print(lastSurfaceNote)
    }

    private var lastSurfaceNote = ""

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
            let hit = touchLogValue()
            XCTFail("focus.set did not show editing in label or value. label=\(row.label) value=\(seenValue) delivery=\(delivery) \(dump) \(lastSurfaceNote) hit=\(hit) \(lastFrameLog)")
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
