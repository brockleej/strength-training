//
//  NextBuildFixesTests.swift
//  RockLogTests
//
//  RockLog 1.2 fixes from Lee's 1.1 (1) test pass. Synthetic values only.
//

import XCTest
import SwiftData
@testable import RockLog

final class NextBuildFixesTests: XCTestCase {

    // MARK: Item 2 — Stack menu respects kg

    func test_machineStepOptions_followTheUnit() {
        XCTAssertEqual(MachineSteps.options(for: .pounds), [5, 10, 15, 20])
        XCTAssertEqual(MachineSteps.options(for: .kilograms), [2.5, 5, 10])
    }

    /// Regression (1.1 (1)): in kg mode the menu offered 5/10/15/20, which stored 15 and 20 kg steps.
    func test_regression_kgStackStep_isStoredInKilograms_andSnapsOnTheKgGrid() {
        let profile = MachineStackProfile(gymID: UUID(), exerciseID: UUID())
        profile.applyTyped(step: 2.5, pins: [], unit: .kilograms)
        XCTAssertEqual(profile.definition.step, 2.5)
        XCTAssertEqual(profile.definition.pinUnit, .kilograms)
        XCTAssertFalse(MachineSteps.options(for: .kilograms).contains(20))
        // 41 kg target lands on 40 or 42.5 kg, never a pound step.
        let target = MassMath.pounds(fromDisplay: 41, unit: .kilograms)
        let offer = StackMath.snap(weightPounds: target, reps: 10, stack: profile.definition)
        let shownKg = MassMath.exactDisplay(fromPounds: offer.weightPounds, unit: .kilograms)
        XCTAssertEqual((shownKg / 2.5).rounded() * 2.5, shownKg, accuracy: 0.001)
    }

    // MARK: Item 3 — 5 kg weight step

    func test_kgStepperCycle_includesFive_andStillStartsOnTwoPointFive() {
        XCTAssertEqual(MassUnit.kilograms.stepperSteps, [5, 2.5, 1, 0.5])
        XCTAssertEqual(MassUnit.kilograms.defaultStepperStep, 2.5)
        XCTAssertEqual(MassUnit.pounds.stepperSteps, [5, 1, 0.5])
        XCTAssertEqual(MassUnit.pounds.defaultStepperStep, 5)
        for unit in MassUnit.allCases {
            XCTAssertTrue(unit.stepperSteps.contains(unit.defaultStepperStep))
        }
    }

    // MARK: Item 4 — plate-math line

    func test_plateLine_showsOnlyForPlainBarTotals() {
        var stack = StackDefinition.empty
        XCTAssertTrue(PlateLinePolicy.shows(isAssisted: false, loadMode: .bar, stack: nil))
        XCTAssertTrue(PlateLinePolicy.shows(isAssisted: false, loadMode: .bar, stack: stack))
        XCTAssertFalse(PlateLinePolicy.shows(isAssisted: true, loadMode: .bar, stack: nil))
        XCTAssertFalse(PlateLinePolicy.shows(isAssisted: false, loadMode: .assist, stack: nil))
        XCTAssertFalse(PlateLinePolicy.shows(isAssisted: false, loadMode: .added, stack: nil))
        stack.step = 10
        XCTAssertFalse(PlateLinePolicy.shows(isAssisted: false, loadMode: .bar, stack: stack))
    }

    /// Regression: the plate line converted an already-displayed kg number as if it were pounds.
    func test_regression_kgPlateLine_usesTheDisplayedKgTotal() {
        let readout = PlateLinePolicy.readout(displayedWeight: 60, unit: .kilograms)
        XCTAssertEqual(readout.bar, 20)
        XCTAssertEqual(readout.platesPerSide, [20])
        XCTAssertEqual(PlateLinePolicy.readout(displayedWeight: 135, unit: .pounds).platesPerSide, [45])
    }

    // MARK: Item 5 — Machine steps clarity

    func test_machineSteps_pillShowsTheChosenStep() {
        XCTAssertEqual(MachineSteps.pillLabel(for: nil), "Machine steps")
        XCTAssertEqual(MachineSteps.pillLabel(for: .empty), "Machine steps")
        var stack = StackDefinition.empty
        stack.step = 10
        XCTAssertEqual(MachineSteps.pillLabel(for: stack), "Steps 10 lb")
        stack.step = 2.5
        stack.pinUnit = .kilograms
        XCTAssertEqual(MachineSteps.pillLabel(for: stack), "Steps 2.5 kg")
        XCTAssertEqual(MachineSteps.optionLabel(10, unit: .pounds), "Every 10 lb")
        XCTAssertEqual(MachineSteps.optionLabel(2.5, unit: .kilograms), "Every 2.5 kg")
    }

    /// Regression (t277u): picking a step did nothing visible; the shown weight must snap at once.
    func test_regression_pickingAStep_snapsTheShownWeight() {
        let profile = MachineStackProfile(gymID: UUID(), exerciseID: UUID())
        profile.applyTyped(step: 10, pins: [], unit: .pounds)
        XCTAssertEqual(MachineSteps.snappedDisplay(137, unit: .pounds, stack: profile.definition), 140)
        XCTAssertEqual(MachineSteps.snappedDisplay(140, unit: .pounds, stack: profile.definition), 140)
        XCTAssertEqual(MachineSteps.snappedDisplay(137, unit: .pounds, stack: .empty), 137)
        profile.applyTyped(step: 5, pins: [], unit: .kilograms)
        XCTAssertEqual(MachineSteps.snappedDisplay(52, unit: .kilograms, stack: profile.definition), 50, accuracy: 0.26)
    }

    func test_noMachineSteps_turnsTheStackOff() {
        let profile = MachineStackProfile(gymID: UUID(), exerciseID: UUID())
        profile.applyTyped(step: 10, pins: [], unit: .pounds)
        profile.applyTyped(step: nil, pins: [], unit: .pounds)
        XCTAssertFalse(profile.definition.isActive)
    }

    // MARK: Item 6 — load pill names the mode

    func test_loadPill_namesTheActiveMode() {
        XCTAssertEqual(LoadMode.bar.pillLabel, "Load: Total")
        XCTAssertEqual(LoadMode.assist.pillLabel, "Load: Assist")
        XCTAssertEqual(LoadMode.added.pillLabel, "Load: Added")
        XCTAssertEqual(Set(LoadMode.allCases.map(\.menuLabel)).count, 3)
        // Stored raw values are unchanged so old sets still decode.
        XCTAssertEqual(LoadMode(stored: "bar", isAssisted: false), .bar)
    }

    // MARK: Item 7 — End alert options

    private func tick(_ seconds: TimeInterval, alert: RestEndAlert, active: Bool = true, call: Bool = false) -> RestAlertPolicy.Tick {
        RestAlertPolicy.Tick(
            now: Date(timeIntervalSince1970: seconds),
            soundEnabled: alert.playsSound,
            tapAtTenEnabled: true,
            callConnected: call,
            liveActivitiesAvailable: false,
            notificationPermissionDenied: false,
            appIsActive: active,
            endAlert: alert
        )
    }

    /// Walk a 30 s rest in 0.15 s steps (the app polls every 150 ms) and collect what fired.
    private func run(_ alert: RestEndAlert, active: Bool = true, call: Bool = false) -> (beeps: [Int], chirp: Bool, buzz: Bool, tap: Bool) {
        var state = RestAlertState.started(now: Date(timeIntervalSince1970: 0), duration: 30)
        var beeps: [Int] = []
        var chirp = false, buzz = false, tap = false
        var t = 0.15
        while t <= 30.3 {
            let e = RestAlertPolicy.onTick(&state, tick: tick(t, alert: alert, active: active, call: call))
            if let b = e.countdownBeep { beeps.append(b) }
            chirp = chirp || e.playChirp
            buzz = buzz || e.strongHaptic
            tap = tap || e.lightTap
            t += 0.15
        }
        return (beeps, chirp, buzz, tap)
    }

    func test_endAlert_chirpIsTheDefault_andHasNoBeeps() {
        XCTAssertEqual(RestEndAlert.resolve(stored: nil, legacySoundEnabled: nil), .chirp)
        let r = run(.chirp)
        XCTAssertEqual(r.beeps, [])
        XCTAssertTrue(r.chirp)
        XCTAssertTrue(r.buzz)
        XCTAssertTrue(r.tap, "Tap at 10 seconds is kept")
    }

    /// Regression (t290u/t291u): 1.1 lost the 5-second countdown; it is back as its own choice.
    func test_regression_countdownBeeps_fireOncePerSecond_fiveToOne_thenChirp() {
        let r = run(.countdown)
        XCTAssertEqual(r.beeps, [5, 4, 3, 2, 1])
        XCTAssertTrue(r.chirp)
        XCTAssertTrue(r.buzz)
    }

    func test_countdownBeeps_onScreenOnly_andNotDuringACall() {
        XCTAssertEqual(run(.countdown, active: false).beeps, [])
        XCTAssertEqual(run(.countdown, call: true).beeps, [])
    }

    func test_buzzOnly_andOff() {
        let buzz = run(.buzz)
        XCTAssertEqual(buzz.beeps, [])
        XCTAssertFalse(buzz.chirp)
        XCTAssertTrue(buzz.buzz)
        let off = run(.off)
        XCTAssertEqual(off.beeps, [])
        XCTAssertFalse(off.chirp)
        XCTAssertFalse(off.buzz)
    }

    func test_endAlert_migratesTheOldCountdownSoundsSwitch() {
        XCTAssertEqual(RestEndAlert.resolve(stored: nil, legacySoundEnabled: false), .buzz)
        XCTAssertEqual(RestEndAlert.resolve(stored: nil, legacySoundEnabled: true), .chirp)
        XCTAssertEqual(RestEndAlert.resolve(stored: "countdown", legacySoundEnabled: false), .countdown)
        XCTAssertEqual(RestEndAlert.resolve(stored: "bogus", legacySoundEnabled: nil), .chirp)
        XCTAssertEqual(RestEndAlert.allCases.map(\.title),
                       ["Chirp at zero", "5-second countdown beeps", "Buzz only", "Off"])
    }

    func test_countdownBeep_ducksOtherAudio() {
        var state = RestAlertState.started(now: Date(timeIntervalSince1970: 0), duration: 30)
        _ = RestAlertPolicy.onTick(&state, tick: tick(25.5, alert: .countdown))
        let e = RestAlertPolicy.onTick(&state, tick: tick(26.0, alert: .countdown))
        XCTAssertEqual(e.countdownBeep, 4)
        XCTAssertTrue(e.duck)
    }

    // MARK: Item 8 — import prompt copy

    /// Regression (t278u): a one-day file said "Add 1 week of planned workouts".
    func test_regression_oneDayFile_saysOneWorkout_notOneWeek() {
        let prompt = ProgramImportSummary(
            blockName: "Synthetic", sessionCount: 1, weekCount: 1,
            createdExerciseCount: 0, skippedDuplicateSessionCount: 0
        ).confirmationPrompt
        XCTAssertTrue(prompt.message.contains("1 workout"), prompt.message)
        XCTAssertFalse(prompt.message.localizedCaseInsensitiveContains("week"), prompt.message)
        XCTAssertEqual(ProgramImportService.planAmount(sessionCount: 4, weekCount: 1), "4 workouts")
        XCTAssertEqual(ProgramImportService.planAmount(sessionCount: 24, weekCount: 8), "24 workouts over 8 weeks")
    }

    func test_importButtons_arePlainAndSafe() {
        let prompt = ProgramImportService.addPlanPrompt(sessionCount: 3, weekCount: 1)
        XCTAssertEqual(prompt.confirmTitle, "Add to my plan")
        XCTAssertEqual(prompt.cancelTitle, "Cancel")
        XCTAssertEqual(ProgramImportService.replaceUnusedPlanTitle, "Replace upcoming planned days")
        XCTAssertEqual(ProgramImportService.importSplitConfirmTitle, "Replace my split")
        XCTAssertEqual(ProgramImportService.importSplitCancelTitle, "Cancel")
        for text in [prompt.message, ProgramImportService.replaceSplitMessage(), ProgramImportService.importSplitMessage()] {
            XCTAssertTrue(text.contains("History"), text)
            XCTAssertFalse(text.localizedCaseInsensitiveContains("unused"), text)
            XCTAssertFalse(text.localizedCaseInsensitiveContains("block"), text)
        }
        let summary = ProgramImportSummary(blockName: "S", sessionCount: 1, weekCount: 1, createdExerciseCount: 0, skippedDuplicateSessionCount: 0)
        XCTAssertEqual(ProgramImportService.resultMessage(summary: summary, replacedSplit: false), "Added 1 workout to your plan. Your history is unchanged.")
    }
}
