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

// MARK: - 1.2 circuit gaps (a)–(e). Synthetic UUIDs and numbers only.

final class CircuitGapsTests: XCTestCase {
    private let ids = (0..<6).map { _ in UUID() }

    private func members(_ logged: [Int], planned: Int? = 3, done: Set<Int> = []) -> [CircuitRoundMember] {
        logged.enumerated().map { index, count in
            CircuitRoundMember(exerciseID: ids[index], position: index + 1, loggedWorkingSets: count,
                               plannedWorkingSets: planned, isDone: done.contains(index))
        }
    }

    // (a) Save for all upcoming days carries circuits

    func test_a_upcomingSeats_keepCircuitOrder_forLiftsOnThatDay() {
        var plan = CircuitPlan(order: Array(ids.prefix(4)), seats: [:])
        let group = plan.makeCircuit([ids[2], ids[0], ids[1]])!
        // Future day has lifts 1, 3, 2 (no lift 0 this time).
        let seats = plan.upcomingSeats(forDayWith: [ids[1], ids[3], ids[2]])
        XCTAssertEqual(seats[ids[2]]?.group, group)
        XCTAssertEqual(seats[ids[2]]?.position, 1)
        XCTAssertEqual(seats[ids[1]]?.position, 2)
        XCTAssertNil(seats[ids[3]])
        XCTAssertNil(seats[ids[0]])
    }

    func test_a_upcomingSeats_dropACircuitThatWouldHaveOneLift() {
        var plan = CircuitPlan(order: Array(ids.prefix(4)), seats: [:])
        plan.makeCircuit([ids[0], ids[1]])
        XCTAssertTrue(plan.upcomingSeats(forDayWith: [ids[0], ids[3]]).isEmpty)
    }

    func test_a_upcomingSeats_ungroupedPlanClearsSeats() {
        let plan = CircuitPlan(order: Array(ids.prefix(3)), seats: [:])
        XCTAssertTrue(plan.upcomingSeats(forDayWith: Array(ids.prefix(3))).isEmpty)
    }

    // (b) Circuit rest is phone-only: iCloud sync stays off until Lee approves it

    func test_b_circuitRest_isLocalOnly_andNeverWritesICloud() throws {
        let suite = "CircuitGapsTests-\(UUID().uuidString)"
        let local = UserDefaults(suiteName: suite)!
        defer { local.removePersistentDomain(forName: suite) }
        let g = UUID()
        XCTAssertEqual(CircuitRestStore.seconds(for: g, local: local), 90)
        CircuitRestStore.set(75, for: g, local: local)
        XCTAssertEqual(local.integer(forKey: CircuitRestStore.key(g)), 75)
        XCTAssertEqual(CircuitRestStore.seconds(for: g, local: local), 75)
        CircuitRestStore.set(1_000, for: g, local: local)
        XCTAssertEqual(CircuitRestStore.seconds(for: g, local: local), 600)
        // Default path writes the app's local store, and nothing reaches the cloud store.
        let before = (AppDefaults.cloud as? MemoryCloudStore)?.writeCount
        CircuitRestStore.set(45, for: g)
        if let cloud = AppDefaults.cloud as? MemoryCloudStore { XCTAssertEqual(cloud.writeCount, before) }
        XCTAssertNil(NSUbiquitousKeyValueStore.default.object(forKey: CircuitRestStore.key(g)))
        AppDefaults.local.removeObject(forKey: CircuitRestStore.key(g))
        // Source guard: the store's file never names the iCloud key-value store.
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("RockLog/Services/Optimization/CircuitPlan.swift")
        let text = try String(contentsOf: source, encoding: .utf8)
        let code = text.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }.joined(separator: "\n")
        XCTAssertFalse(code.contains("NSUbiquitousKeyValueStore"))
        XCTAssertFalse(code.contains("AppDefaults.cloud"))
    }

    // (c) Round-complete rest between rounds

    func test_c_roundBreak_onlyBetweenRounds() {
        let g = UUID()
        let mid = CircuitRounds.roundBreak(group: g, members: members([1, 1, 1]))
        XCTAssertEqual(mid, CircuitBreak(group: g, completedRound: 1, totalRounds: 3, nextExerciseID: ids[0]))
        XCTAssertNil(CircuitRounds.roundBreak(group: g, members: members([1, 1, 0])), "Inside a round: no break")
        XCTAssertNil(CircuitRounds.roundBreak(group: g, members: members([0, 0, 0])), "Not started: no break")
        XCTAssertNil(CircuitRounds.roundBreak(group: g, members: members([3, 3, 3])), "Last round: back to the list")
    }

    func test_c_resumeAfterRelaunch_usesTheLastSetTime() {
        let g = UUID()
        let now = Date(timeIntervalSince1970: 1_000_000)
        let resumed = CircuitRounds.resumableBreak(group: g, members: members([2, 2, 2]),
                                                   lastSetAt: now.addingTimeInterval(-20), restSeconds: 60, now: now)
        XCTAssertEqual(resumed?.break.completedRound, 2)
        XCTAssertEqual(resumed?.remaining ?? 0, 40, accuracy: 0.001)
        XCTAssertNil(CircuitRounds.resumableBreak(group: g, members: members([2, 2, 2]),
                                                  lastSetAt: now.addingTimeInterval(-61), restSeconds: 60, now: now),
                     "Rest already over while the app was closed")
        XCTAssertNil(CircuitRounds.resumableBreak(group: g, members: members([2, 2, 1]),
                                                  lastSetAt: now, restSeconds: 60, now: now))
        XCTAssertNil(CircuitRounds.resumableBreak(group: g, members: members([2, 2, 2]),
                                                  lastSetAt: nil, restSeconds: 60, now: now))
    }

    // (d) End circuit early

    func test_d_endEarly_closesOnlyOpenLifts() {
        var m = members([2, 1, 3])
        m[1].isDone = false
        XCTAssertEqual(Set(CircuitRounds.liftsToCloseEarly(m)), [ids[0], ids[1]])
        XCTAssertTrue(CircuitRounds.liftsToCloseEarly(members([3, 3], planned: 3)).isEmpty)
        XCTAssertTrue(CircuitRounds.liftsToCloseEarly(members([1, 1], done: [0, 1])).isEmpty)
    }

    // (e) Start Circuit A entry point

    func test_e_startLift_opensTheLiftThatOwesASet() {
        XCTAssertEqual(CircuitRounds.startLift(members([0, 0, 0])), ids[0])
        XCTAssertEqual(CircuitRounds.startLift(members([1, 0, 0])), ids[1])
        XCTAssertEqual(CircuitRounds.startLift(members([1, 1, 1])), ids[0])
        XCTAssertNil(CircuitRounds.startLift(members([3, 3, 3])))
    }

    func test_e_startTitle() {
        XCTAssertEqual(CircuitRounds.startTitle(letter: "A", members: members([0, 0, 0])), "Start Circuit A")
        XCTAssertEqual(CircuitRounds.startTitle(letter: "B", members: members([1, 1, 0])), "Continue Circuit B · Round 1 of 3")
        XCTAssertEqual(CircuitRounds.startTitle(letter: "A", members: members([1, 1, 1])), "Continue Circuit A · Round 2 of 3")
        XCTAssertEqual(CircuitRounds.startTitle(letter: "A", members: members([3, 3, 3])), "Circuit A done")
    }
}

/// View-model wiring for the 1.2 circuit gaps, on an in-memory store with synthetic lifts.
@MainActor
final class CircuitGapsViewModelTests: RockLogStoreTestCase {
    private func makeSession(_ context: ModelContext, exercises: [Exercise], planned: Bool, logged: Bool) -> WorkoutSession {
        let session = WorkoutSession(dayType: .push, date: Date())
        if planned { session.planStatus = .planned }
        context.insert(session)
        var records: [ExerciseRecord] = []
        for (index, exercise) in exercises.enumerated() {
            let record = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: index)
            record.exercise = exercise
            record.session = session
            context.insert(record)
            if logged && index == 0 {
                let set = SetRecord(setNumber: 1, weightLbs: 100, reps: 5)
                set.exerciseRecord = record
                context.insert(set)
                record.sets = [set]
            }
            records.append(record)
        }
        session.exerciseRecords = records
        return session
    }

    private func lifts(_ context: ModelContext) -> [Exercise] {
        (0..<3).map { index in
            let exercise = Exercise.make(name: "UI Circuit Lift \(index)", dayType: .push, isCustom: true)
            context.insert(exercise)
            return exercise
        }
    }

    func test_a_saveForAllUpcoming_copiesCircuitsToPlannedDays() throws {
        let context = container.mainContext
        let exercises = lifts(context)
        _ = makeSession(context, exercises: exercises, planned: false, logged: true)
        let future = makeSession(context, exercises: [exercises[2], exercises[0], exercises[1]], planned: true, logged: false)
        try context.save()
        let vm = holdWorkoutViewModel(WorkoutViewModel(modelContext: context, healthKitService: HealthKitWorkoutService()))
        XCTAssertNotNil(vm.activeSession)
        var plan = vm.todayCircuitPlan(orderedIDs: exercises.map(\.id))
        let group = try XCTUnwrap(plan.makeCircuit([exercises[1].id, exercises[0].id]))
        vm.applyTodayPlan(plan, exercises: exercises)
        vm.saveTodayOrderToRemainingPlanned(exercises: exercises, plan: plan)
        let byID = Dictionary(uniqueKeysWithValues: future.exerciseRecordsArray.map { ($0.exercise!.id, $0) })
        XCTAssertEqual(byID[exercises[1].id]?.groupID, group)
        XCTAssertEqual(byID[exercises[1].id]?.groupPosition, 1)
        XCTAssertEqual(byID[exercises[0].id]?.groupID, group)
        XCTAssertEqual(byID[exercises[0].id]?.groupPosition, 2)
        XCTAssertNil(byID[exercises[2].id]?.groupID)
    }

    func test_d_endCircuitEarly_marksOpenLiftsDone_andLeavesOthers() throws {
        let context = container.mainContext
        let exercises = lifts(context)
        let live = makeSession(context, exercises: exercises, planned: false, logged: true)
        try context.save()
        let vm = holdWorkoutViewModel(WorkoutViewModel(modelContext: context, healthKitService: HealthKitWorkoutService()))
        var plan = vm.todayCircuitPlan(orderedIDs: exercises.map(\.id))
        let group = try XCTUnwrap(plan.makeCircuit([exercises[0].id, exercises[1].id]))
        vm.applyTodayPlan(plan, exercises: exercises)
        vm.endCircuitEarly(group: group)
        let byID = Dictionary(uniqueKeysWithValues: live.exerciseRecordsArray.map { ($0.exercise!.id, $0) })
        XCTAssertEqual(byID[exercises[0].id]?.isCompleted, true)
        XCTAssertEqual(byID[exercises[1].id]?.isCompleted, true)
        XCTAssertEqual(byID[exercises[2].id]?.isCompleted, false)
        XCTAssertNil(vm.circuitBreak)
        XCTAssertFalse(vm.isResting)
    }

    func test_e_circuitStart_onlyOnTheFirstLiftOfACircuit() throws {
        let context = container.mainContext
        let exercises = lifts(context)
        _ = makeSession(context, exercises: exercises, planned: false, logged: true)
        try context.save()
        let vm = holdWorkoutViewModel(WorkoutViewModel(modelContext: context, healthKitService: HealthKitWorkoutService()))
        var plan = vm.todayCircuitPlan(orderedIDs: exercises.map(\.id))
        plan.makeCircuit([exercises[1].id, exercises[2].id])
        vm.applyTodayPlan(plan, exercises: exercises)
        XCTAssertNil(vm.circuitStart(before: exercises[0], in: exercises))
        XCTAssertNil(vm.circuitStart(before: exercises[2], in: exercises))
        let start = try XCTUnwrap(vm.circuitStart(before: exercises[1], in: exercises))
        XCTAssertEqual(start.letter, "A")
        XCTAssertEqual(start.title, "Start Circuit A")
        XCTAssertEqual(start.liftID, exercises[1].id)
    }

    func test_c_roundBreak_resumesAfterRelaunchFromTheLastSet() throws {
        let context = container.mainContext
        let exercises = lifts(context)
        let live = makeSession(context, exercises: Array(exercises.prefix(2)), planned: false, logged: true)
        // Lift 1 logs its round-1 set 10 s ago, so round 1 is complete.
        let record = live.exerciseRecordsArray.first { $0.exercise?.id == exercises[1].id }!
        let set = SetRecord(setNumber: 1, weightLbs: 80, reps: 8)
        set.completedAt = Date().addingTimeInterval(-10)
        set.exerciseRecord = record
        context.insert(set)
        record.sets = [set]
        live.exerciseRecordsArray.first { $0.exercise?.id == exercises[0].id }?.sets?.forEach {
            $0.completedAt = Date().addingTimeInterval(-40)
        }
        try context.save()
        let vm = holdWorkoutViewModel(WorkoutViewModel(modelContext: context, healthKitService: HealthKitWorkoutService()))
        var plan = vm.todayCircuitPlan(orderedIDs: exercises.prefix(2).map(\.id))
        let group = try XCTUnwrap(plan.makeCircuit(exercises.prefix(2).map(\.id)))
        vm.applyTodayPlan(plan, exercises: Array(exercises.prefix(2)))
        XCTAssertNil(vm.circuitBreak)
        vm.resumeCircuitBreakIfNeeded(for: exercises[0])
        XCTAssertEqual(vm.circuitBreak?.group, group)
        XCTAssertEqual(vm.circuitBreak?.completedRound, 1)
        XCTAssertTrue(vm.isResting)
        XCTAssertLessThanOrEqual(vm.remainingRestSeconds, Double(CircuitRestStore.seconds(for: group)) - 9)
        vm.skipRest()
        XCTAssertNil(vm.circuitBreak, "Skip rest also ends the break")
    }
}

// MARK: - QA 1.2: stored set values never move when display or machine steps change

@MainActor
final class StoredSetValueTests: RockLogStoreTestCase {
    private var savedUnit: MassUnit = .pounds

    override func setUpWithError() throws {
        try super.setUpWithError()
        savedUnit = MassUnitPreferences.unit
    }

    override func tearDown() {
        MassUnitPreferences.unit = savedUnit
        super.tearDown()
    }

    private func liveSet(_ context: ModelContext, entered: Double, unit: MassUnit) throws -> (Exercise, SetRecord) {
        let exercise = Exercise.make(name: "Synthetic Machine Row", dayType: .push, isCustom: true)
        context.insert(exercise)
        let session = WorkoutSession(dayType: .push, date: Date())
        context.insert(session)
        let record = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
        record.exercise = exercise
        record.session = session
        context.insert(record)
        let set = SetRecord(setNumber: 1, weightLbs: 0, reps: 8)
        set.stampEntered(entered, unit: unit)
        set.exerciseRecord = record
        context.insert(set)
        record.sets = [set]
        session.exerciseRecords = [record]
        try context.save()
        return (exercise, set)
    }

    func test_savedSet_unchanged_byMachineStepsSnapAndUnitToggle() throws {
        let context = container.mainContext
        MassUnitPreferences.unit = .pounds
        let (exercise, set) = try liveSet(context, entered: 147.5, unit: .pounds)
        let before = (set.weightLbs, set.enteredValue, set.enteredUnitRaw, set.reps)
        let vm = holdWorkoutViewModel(WorkoutViewModel(modelContext: context, healthKitService: HealthKitWorkoutService()))

        vm.applyTypedStack(exercise: exercise, step: 10, pins: [])
        if let stack = vm.stackDefinition(for: exercise) {
            _ = MachineSteps.snappedDisplay(set.displayValue(in: .pounds), unit: .pounds, stack: stack)
        }
        MassUnitPreferences.unit = .kilograms
        vm.applyTypedStack(exercise: exercise, step: 5, pins: [])
        if let stack = vm.stackDefinition(for: exercise) {
            _ = MachineSteps.snappedDisplay(set.displayValue(in: .kilograms), unit: .kilograms, stack: stack)
        }
        _ = MassUnit.kilograms.stepperSteps
        vm.applyTypedStack(exercise: exercise, step: nil, pins: [])
        MassUnitPreferences.unit = .pounds

        XCTAssertEqual(set.weightLbs, before.0)
        XCTAssertEqual(set.enteredValue, before.1)
        XCTAssertEqual(set.enteredUnitRaw, before.2)
        XCTAssertEqual(set.reps, before.3)
        XCTAssertEqual(set.displayValue(in: .pounds), 147.5, "lb → kg → lb does not walk the number")
    }

    func test_editEntry_keepsStoredWeight_whenOnlyRepsChange_inOtherUnit() {
        // Entered 147.5 lb, edited while the app shows kg, weight untouched.
        let pounds = MassMath.pounds(fromDisplay: 147.5, unit: .pounds)
        let shownKg = MassMath.shown(enteredValue: 147.5, enteredUnit: .pounds, canonicalPounds: pounds, display: .kilograms)
        let kept = MassMath.editedEntry(
            previousPounds: pounds, previousEnteredValue: 147.5, previousEnteredUnit: .pounds,
            newDisplay: shownKg, unit: .kilograms
        )
        XCTAssertEqual(kept.pounds, pounds)
        XCTAssertEqual(kept.enteredValue, 147.5)
        XCTAssertEqual(kept.enteredUnit, .pounds)

        let changed = MassMath.editedEntry(
            previousPounds: pounds, previousEnteredValue: 147.5, previousEnteredUnit: .pounds,
            newDisplay: 70, unit: .kilograms
        )
        XCTAssertEqual(changed.enteredValue, 70)
        XCTAssertEqual(changed.enteredUnit, .kilograms)
        XCTAssertEqual(changed.pounds, MassMath.storedPounds(fromEntered: 70, unit: .kilograms), accuracy: 0.0001)
    }

    func test_historyEdit_repsOnly_inKg_keepsStoredPoundsAndEntry() throws {
        let context = container.mainContext
        MassUnitPreferences.unit = .kilograms
        let (_, set) = try liveSet(context, entered: 147.5, unit: .pounds)
        let pounds = set.weightLbs
        let vm = holdWorkoutViewModel(WorkoutViewModel(modelContext: context, healthKitService: HealthKitWorkoutService()))
        let entry = MassMath.editedEntry(
            previousPounds: set.weightLbs, previousEnteredValue: set.enteredValue,
            previousEnteredUnit: set.enteredUnit, newDisplay: set.displayValue(in: .kilograms), unit: .kilograms
        )
        vm.updateSet(set, weight: entry.pounds, reps: 10,
                     enteredValue: entry.enteredValue, enteredUnit: entry.enteredUnit)
        XCTAssertEqual(set.reps, 10, "the edited field changes")
        XCTAssertEqual(set.weightLbs, pounds, "weight stays exactly as stored")
        XCTAssertEqual(set.enteredUnit, .pounds)
        XCTAssertEqual(set.enteredValue, 147.5)
    }
}

// MARK: - QA 1.2: ducking ends by deactivating with notifyOthersOnDeactivation

final class RecordingAudioSession: AudioSessionControlling, @unchecked Sendable {
    var calls: [String] = []
    func setCategory(duck: Bool) throws { calls.append("category duck=\(duck)") }
    func setActive(_ active: Bool, notifyOthers: Bool) throws { calls.append("active=\(active) notify=\(notifyOthers)") }
}

@MainActor
final class RestTimerDuckTeardownTests: XCTestCase {
    func test_endDuck_deactivates_withNotifyOthers() {
        let fake = RecordingAudioSession()
        let previous = RestTimerSoundService.swapSessionForTesting(fake)
        defer { _ = RestTimerSoundService.swapSessionForTesting(previous) }
        RestTimerSoundService.configureSession(duck: true)
        RestTimerSoundService.endDuck()
        RestTimerSoundService.waitForAudioQueueForTesting()
        XCTAssertEqual(fake.calls.first, "category duck=true")
        XCTAssertTrue(fake.calls.contains("active=true notify=false"))
        XCTAssertEqual(fake.calls.last { $0.hasPrefix("active=") }, "active=false notify=true",
                       "the audiobook only comes back up if others are notified on deactivation")
    }

    func test_sessionCalls_runOffTheMainThread() {
        final class ThreadProbe: AudioSessionControlling, @unchecked Sendable {
            var onMain: [Bool] = []
            func setCategory(duck: Bool) throws { onMain.append(Thread.isMainThread) }
            func setActive(_ active: Bool, notifyOthers: Bool) throws { onMain.append(Thread.isMainThread) }
        }
        let probe = ThreadProbe()
        let previous = RestTimerSoundService.swapSessionForTesting(probe)
        defer { _ = RestTimerSoundService.swapSessionForTesting(previous) }
        RestTimerSoundService.configureSession(duck: true)
        RestTimerSoundService.endDuck()
        RestTimerSoundService.waitForAudioQueueForTesting()
        XCTAssertFalse(probe.onMain.isEmpty)
        XCTAssertFalse(probe.onMain.contains(true))
    }
}
