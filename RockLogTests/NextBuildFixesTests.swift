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

    // MARK: Item 9 — Units copy

    func test_unitsCopy_isPlain_andHasNoPlateList() {
        XCTAssertEqual(UnitsSettingsCopy.footer,
                       "Choose how weights show across the app. Suggestions go up by 5 lb or 2.5 kg at a time.")
        XCTAssertFalse(UnitsSettingsCopy.footer.contains("plates"))
        XCTAssertFalse(UnitsSettingsCopy.footer.contains("1.25"))
    }

    // MARK: Item 10 — more sets below

    /// Regression (t290u): nothing said more planned sets were further down.
    func test_regression_setProgress_saysMoreBelow() {
        XCTAssertEqual(SetProgressLabel.text(loggedCount: 1, plannedCount: 4), "Set 2 of 4 · 2 more below")
        XCTAssertEqual(SetProgressLabel.text(loggedCount: 3, plannedCount: 4), "Set 4 of 4 · last planned")
        XCTAssertEqual(SetProgressLabel.text(loggedCount: 4, plannedCount: 4), "Set 5 · extra (4 planned)")
        XCTAssertEqual(SetProgressLabel.text(loggedCount: 0, plannedCount: 0), "Set 1")
        XCTAssertEqual(SetProgressLabel.text(loggedCount: 2, plannedCount: 3, editingSetNumber: 1), "Editing set 1 of 3")
    }

    // MARK: Item 11 — Reorder Today with circuits

    private let ids = (0..<6).map { _ in UUID() }

    func test_plan_buildsBlocks_andACircuitMovesAsOne() {
        let g = UUID()
        var plan = CircuitPlan(order: ids, seats: [ids[2]: (g, 1), ids[3]: (g, 2)])
        XCTAssertEqual(plan.blocks.count, 5)
        XCTAssertEqual(plan.blocks[2], .circuit(group: g, lifts: [ids[2], ids[3]]))
        XCTAssertEqual(plan.letter(for: g), "A")
        // Drag the circuit block to the top.
        plan.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        XCTAssertEqual(plan.order, [ids[2], ids[3], ids[0], ids[1], ids[4], ids[5]])
        // Drag a lift above the circuit; the circuit stays together.
        plan.move(fromOffsets: IndexSet(integer: 1), toOffset: 0)
        XCTAssertEqual(plan.blocks[0].id, ids[0])
        XCTAssertEqual(plan.blocks[1], .circuit(group: g, lifts: [ids[2], ids[3]]))
    }

    func test_moved_matchesListOnMoveSemantics() {
        XCTAssertEqual(CircuitPlan.moved([1, 2, 3, 4], fromOffsets: IndexSet(integer: 0), toOffset: 4), [2, 3, 4, 1])
        XCTAssertEqual(CircuitPlan.moved([1, 2, 3, 4], fromOffsets: IndexSet(integer: 3), toOffset: 0), [4, 1, 2, 3])
        XCTAssertEqual(CircuitPlan.moved([1, 2, 3, 4], fromOffsets: IndexSet([0, 2]), toOffset: 4), [2, 4, 1, 3])
        XCTAssertEqual(CircuitPlan.moved([1, 2, 3, 4], fromOffsets: IndexSet(integer: 1), toOffset: 2), [1, 2, 3, 4])
    }

    func test_upToThreeCircuits_fromSixLifts_eachWithItsOwnLetter() {
        var plan = CircuitPlan(order: ids, seats: [:])
        let a = plan.makeCircuit([ids[0], ids[1]])
        let b = plan.makeCircuit([ids[3], ids[2]])
        XCTAssertTrue(plan.canMakeAnotherCircuit)
        let c = plan.makeCircuit([ids[4], ids[5]])
        XCTAssertNotNil(a); XCTAssertNotNil(b); XCTAssertNotNil(c)
        XCTAssertEqual(plan.circuits.count, 3)
        XCTAssertEqual([a, b, c].compactMap { $0.flatMap(plan.letter(for:)) }, ["A", "B", "C"])
        // B keeps the order the lifts were picked in.
        XCTAssertEqual(plan.circuits[1].lifts, [ids[3], ids[2]])
        XCTAssertFalse(plan.canMakeAnotherCircuit)
        XCTAssertNil(plan.makeCircuit([ids[0], ids[2]]), "Lifts already in a circuit are not pickable")
    }

    func test_editAndUngroup() {
        var plan = CircuitPlan(order: ids, seats: [:])
        let a = plan.makeCircuit([ids[1], ids[2], ids[3]])!
        XCTAssertEqual(plan.makeCircuit([ids[1], ids[3]], editing: a), a)
        XCTAssertEqual(plan.circuits.first?.lifts, [ids[1], ids[3]])
        XCTAssertTrue(plan.ungroupedLifts.contains(ids[2]), "A lift dropped from a circuit goes back to standalone")
        plan.ungroup(a)
        XCTAssertTrue(plan.circuits.isEmpty)
        XCTAssertEqual(Set(plan.order), Set(ids))
        XCTAssertNil(plan.makeCircuit([ids[0]]), "A circuit needs at least two lifts")
    }

    func test_seats_areOneBasedPerCircuit() {
        var plan = CircuitPlan(order: ids, seats: [:])
        let a = plan.makeCircuit([ids[4], ids[0]])!
        XCTAssertEqual(plan.seats[ids[4]]?.group, a)
        XCTAssertEqual(plan.seats[ids[4]]?.position, 1)
        XCTAssertEqual(plan.seats[ids[0]]?.position, 2)
        XCTAssertNil(plan.seats[ids[1]])
        XCTAssertEqual(Array(plan.order.prefix(2)), [ids[4], ids[0]], "The circuit lands where its first lift was")
    }

    func test_circuitRest_defaultsTo90_andClamps() {
        let g = UUID()
        XCTAssertEqual(CircuitRestStore.seconds(for: g), 90)
        CircuitRestStore.set(5, for: g)
        XCTAssertEqual(CircuitRestStore.seconds(for: g), 15)
        CircuitRestStore.set(120, for: g)
        XCTAssertEqual(CircuitRestStore.seconds(for: g), 120)
    }

    // MARK: Item 12 — in-workout circuit rounds (t299u)

    private func members(_ logged: [Int], planned: Int? = 3) -> [CircuitRoundMember] {
        logged.enumerated().map { index, count in
            CircuitRoundMember(exerciseID: ids[index], position: index + 1, loggedWorkingSets: count, plannedWorkingSets: planned)
        }
    }

    func test_insideARound_goesStraightToTheNextLift_withNoRest() {
        let step = CircuitRounds.stepAfterLogging(ids[0], members: members([1, 0, 0]))
        XCTAssertEqual(step, CircuitRoundStep(next: ids[1], restAfterRound: false, completedRound: nil))
        let step2 = CircuitRounds.stepAfterLogging(ids[1], members: members([1, 1, 0]))
        XCTAssertEqual(step2.next, ids[2])
        XCTAssertFalse(step2.restAfterRound)
    }

    func test_endOfRound_restsOnce_thenLoopsToTheFirstLift() {
        let step = CircuitRounds.stepAfterLogging(ids[2], members: members([1, 1, 1]))
        XCTAssertEqual(step, CircuitRoundStep(next: ids[0], restAfterRound: true, completedRound: 1))
        XCTAssertEqual(CircuitRounds.currentRound(members([1, 1, 1])), 2)
        XCTAssertEqual(CircuitRounds.totalRounds(members([1, 1, 1])), 3)
    }

    func test_lastRound_finishesTheCircuit() {
        let step = CircuitRounds.stepAfterLogging(ids[2], members: members([3, 3, 3]))
        XCTAssertNil(step.next)
        XCTAssertTrue(step.restAfterRound)
        XCTAssertEqual(step.completedRound, 3)
    }

    func test_roundPill_andStrip() {
        let m = members([2, 1, 1])
        XCTAssertEqual(CircuitRounds.currentRound(m), 2)
        XCTAssertEqual(CircuitRounds.doneThisRound(m), [ids[0]])
    }

    func test_unevenPlans_shortLiftDropsOut() {
        var m = members([2, 2], planned: 3)
        m[1].plannedWorkingSets = 2
        // Lift 1 has finished its two; after lift 0's third set the circuit is done.
        m[0].loggedWorkingSets = 3
        let step = CircuitRounds.stepAfterLogging(ids[0], members: m)
        XCTAssertNil(step.next)
        // Mid-way, round 3 skips the finished lift and rests.
        let mid = CircuitRounds.stepAfterLogging(ids[1], members: members([2, 2], planned: nil))
        XCTAssertTrue(mid.restAfterRound)
        XCTAssertEqual(mid.next, ids[0])
    }

    func test_noPlannedSets_defaultsToThreeRounds() {
        XCTAssertEqual(CircuitRounds.totalRounds(members([0, 0], planned: nil)), 3)
    }
}
