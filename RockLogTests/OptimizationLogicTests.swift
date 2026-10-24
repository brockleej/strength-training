//
//  OptimizationLogicTests.swift
//  RockLogTests
//
//  Units, body weight, stacks, carry, circuits, rest alerts, focus navigation,
//  warm-up, and the no-session log. Synthetic data only.
//

import XCTest
import SwiftData
@testable import RockLog

final class OptimizationLogicTests: XCTestCase {

    func test_massRoundTrip_doesNotWalk() {
        let pounds = 225.0
        let shown = MassMath.display(fromPounds: pounds, unit: .kilograms)
        let stored = MassMath.pounds(fromDisplay: shown, unit: .kilograms)
        let again = MassMath.display(fromPounds: stored, unit: .kilograms)
        XCTAssertEqual(shown, again)
        XCTAssertLessThan(abs(MassMath.switched(pounds, from: .pounds, to: .kilograms) - stored), 0.01)
    }

    func test_progressionSnap_usesTheActiveUnitThenStoresPounds() {
        let snapped = MassMath.snapProgression(pounds: 100, unit: .kilograms)
        let again = MassMath.snapProgression(pounds: snapped, unit: .kilograms)
        XCTAssertEqual(snapped, again, accuracy: 0.001)
        XCTAssertEqual(MassMath.snapProgression(pounds: 222, unit: .pounds), 220, accuracy: 0.001)
    }

    func test_plates_doNotChangeTheStoredWeight() {
        let readout = MassMath.plates(forTotal: 225, unit: .pounds)
        XCTAssertEqual(readout.bar, 45)
        XCTAssertEqual(readout.platesPerSide, [45, 45])
        XCTAssertTrue(MassMath.isStorable(10_000))
        XCTAssertFalse(MassMath.isStorable(10_001))
        XCTAssertFalse(MassMath.isStorable(.infinity))
    }

    func test_backdatedWeighIn_doesNotReplaceANewerSettingsValue() {
        let older = Date(timeIntervalSince1970: 1_000)
        let newer = Date(timeIntervalSince1970: 5_000)
        let weighIns = [
            LoadMath.WeighIn(date: newer, pounds: 180),
            LoadMath.WeighIn(date: older, pounds: 200),
        ]
        XCTAssertEqual(LoadMath.settingsPounds(afterLogging: weighIns, previousSettings: 175), 180)
        XCTAssertEqual(LoadMath.bodyWeight(asOf: older, weighIns: weighIns, settingsPounds: 175), 200)
        XCTAssertEqual(LoadMath.bodyWeight(asOf: older.addingTimeInterval(-10), weighIns: weighIns, settingsPounds: 175), 175)
    }

    func test_loadModes_andRelativeStrength() {
        XCTAssertEqual(LoadMath.effective(mode: .assist, entered: 40, bodyWeight: 180), 140)
        XCTAssertEqual(LoadMath.effective(mode: .added, entered: 25, bodyWeight: 180), 205)
        XCTAssertEqual(LoadMath.effective(mode: .assist, entered: 40, bodyWeight: 0), 0)
        XCTAssertEqual(LoadMath.relativeStrength(e1RM: 300, bodyWeight: 200), 1.5)
        XCTAssertNil(LoadMath.relativeStrength(e1RM: 300, bodyWeight: 0))
    }

    func test_stackSnap_tieRoundsDown_andRepsFollow() {
        var stack = StackDefinition.empty
        stack.step = 10
        stack.rangeMin = 10
        stack.rangeMax = 400
        let offer = StackMath.snap(weightPounds: 205, reps: 5, stack: stack)
        XCTAssertEqual(offer.weightPounds, 200, accuracy: 0.01)
        XCTAssertEqual(offer.reps, 6)
        let planned = StackMath.snap(weightPounds: 165, reps: 5, stack: stack)
        XCTAssertEqual(planned.weightPounds, 160, accuracy: 0.01)
        XCTAssertEqual(planned.reps, 6)
    }

    func test_learning_threeSessions_andThe150Slip() {
        XCTAssertNil(StackLearning.sessionStep(correctedPounds: [145, 185, 225]))
        XCTAssertEqual(StackLearning.sessionStep(correctedPounds: [140]), 20)
        XCTAssertEqual(StackLearning.sessionStep(correctedPounds: [150]), 15)
        XCTAssertEqual(StackLearning.sessionStep(correctedPounds: [25, 50, 75]), 25)

        let one = sample(1, [140])
        XCTAssertNil(StackLearning.learnedStep(sessions: [one], clearedAt: nil, currentStep: nil, origin: nil, learningEnabled: true))
        let two = [one, sample(2, [160])]
        XCTAssertNil(StackLearning.learnedStep(sessions: two, clearedAt: nil, currentStep: nil, origin: nil, learningEnabled: true))

        let twenty = [sample(1, [140]), sample(2, [160]), sample(3, [180])]
        XCTAssertEqual(StackLearning.learnedStep(sessions: twenty, clearedAt: nil, currentStep: nil, origin: nil, learningEnabled: true)?.step, 20)

        let mixed = [sample(1, [140]), sample(2, [150]), sample(3, [160])]
        XCTAssertEqual(StackLearning.learnedStep(sessions: mixed, clearedAt: nil, currentStep: nil, origin: nil, learningEnabled: true)?.step, 10)

        let oneFifty = [sample(1, [150]), sample(2, [150]), sample(3, [150])]
        let learned = StackLearning.learnedStep(sessions: oneFifty, clearedAt: nil, currentStep: 20, origin: .learned, learningEnabled: true)
        XCTAssertEqual(learned?.step, 15, "150 fits 15. The spec sentence that says 10 disagrees with the fit rule.")

        XCTAssertNil(StackLearning.learnedStep(sessions: mixed, clearedAt: nil, currentStep: nil, origin: .typed, learningEnabled: true))
        let cleared = Date(timeIntervalSince1970: 10_000)
        let old = mixed.map { StackSessionSample(id: $0.id, date: Date(timeIntervalSince1970: 100), correctedPounds: $0.correctedPounds) }
        XCTAssertNil(StackLearning.learnedStep(sessions: old, clearedAt: cleared, currentStep: nil, origin: nil, learningEnabled: true))
    }

    func test_kilogramPins_snapInKilograms_andSameWeightIsAHundredth() {
        var stack = StackDefinition.empty
        stack.pins = [10, 15, 20]
        stack.pinUnit = .kilograms
        let target = MassMath.pounds(fromDisplay: 14, unit: .kilograms)
        let offer = StackMath.snap(weightPounds: target, reps: 5, stack: stack)
        let shown = MassMath.exactDisplay(fromPounds: offer.weightPounds, unit: .kilograms)
        XCTAssertEqual(shown, 15, accuracy: 0.001)
        XCTAssertEqual(MassMath.clampedStackStep(1, unit: .kilograms), 2.5, accuracy: 0.001)
        XCTAssertEqual(MassMath.clampedStackStep(10, unit: .pounds), 10, accuracy: 0.001)
        XCTAssertTrue(MassMath.sameStoredPounds(140, 140.009))
        XCTAssertFalse(MassMath.sameStoredPounds(140, 140.02))
        let rows = [
            CarrySet(setNumber: 1, planWeight: 140, reps: 5, isWarmup: false, isLogged: true, displayWeight: 140),
            CarrySet(setNumber: 2, planWeight: 140.009, reps: 5, isWarmup: false, isLogged: false, displayWeight: 140.009),
            CarrySet(setNumber: 3, planWeight: 140.02, reps: 5, isWarmup: false, isLogged: false, displayWeight: 140.02),
        ]
        let carried = SameWeightCarry.apply(
            sets: rows,
            edit: SameWeightCarry.Edit(setNumber: 1, newWeight: 150, isWarmup: false, loggedTheOffer: false, repsOnly: false)
        )
        XCTAssertEqual(carried.sets.first { $0.setNumber == 2 }?.displayWeight, 150)
        XCTAssertEqual(carried.sets.first { $0.setNumber == 3 }?.displayWeight ?? 0, 140.02, accuracy: 0.001)
    }

    func test_gymFallback_thenFivePounds() {
        let home = UUID()
        let away = UUID()
        let lift = UUID()
        var homeStack = StackDefinition.empty
        homeStack.step = 15
        let resolved = GymStackLookup.resolve(
            exerciseID: lift,
            gymID: away,
            homeGymID: home,
            profiles: [StackCandidate(id: UUID(), gymID: home, exerciseID: lift, updatedAt: nil, stack: homeStack)]
        )
        XCTAssertEqual(resolved?.step, 15)
        XCTAssertNil(GymStackLookup.resolve(exerciseID: lift, gymID: away, homeGymID: nil, profiles: []))
    }

    func test_typedStepBeatsANewerLearnedStep_andLearningDoesNotRewriteSamples() {
        var typed = StackDefinition.empty
        typed.step = 5
        typed.origin = .typed
        var learned = StackDefinition.empty
        learned.step = 20
        learned.origin = .learned
        let gym = UUID()
        let lift = UUID()
        let older = Date(timeIntervalSince1970: 10)
        let newer = Date(timeIntervalSince1970: 20)
        let rows = [
            StackCandidate(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, gymID: gym, exerciseID: lift, updatedAt: older, stack: typed),
            StackCandidate(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, gymID: gym, exerciseID: lift, updatedAt: newer, stack: learned),
        ]
        XCTAssertEqual(StackConflict.winner(rows)?.stack.origin, .typed)
        var firstLearned = learned
        firstLearned.step = 10
        let tie = [
            StackCandidate(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!, gymID: gym, exerciseID: lift, updatedAt: newer, stack: firstLearned),
            StackCandidate(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!, gymID: gym, exerciseID: lift, updatedAt: newer, stack: learned),
        ]
        XCTAssertEqual(StackConflict.winner(tie)?.id.uuidString, "00000000-0000-0000-0000-00000000000B")
        var samples = [
            StackSessionSample(id: UUID(), date: older, correctedPounds: [140, 160]),
            StackSessionSample(id: UUID(), date: newer, correctedPounds: [140, 160]),
            StackSessionSample(id: UUID(), date: Date(timeIntervalSince1970: 30), correctedPounds: [140, 160]),
        ]
        let before = samples.map(\.correctedPounds)
        _ = StackLearning.learnedStep(sessions: samples, clearedAt: nil, currentStep: nil, origin: nil, learningEnabled: true)
        XCTAssertEqual(samples.map(\.correctedPounds), before)
        XCTAssertNil(StackLearning.learnedStep(sessions: samples, clearedAt: nil, currentStep: nil, origin: .typed, learningEnabled: true))
    }

    func test_sameWeightCarry_andUndo_andStackSnap() {
        let rows = [
            CarrySet(setNumber: 1, planWeight: 145, reps: 5, isWarmup: false, isLogged: true, displayWeight: 145),
            CarrySet(setNumber: 2, planWeight: 145, reps: 5, isWarmup: false, isLogged: false, displayWeight: 145),
            CarrySet(setNumber: 3, planWeight: 165, reps: 5, isWarmup: false, isLogged: false, displayWeight: 165),
            CarrySet(setNumber: 0, planWeight: 145, reps: 8, isWarmup: true, isLogged: false, displayWeight: 145),
        ]
        let edit = SameWeightCarry.Edit(setNumber: 1, newWeight: 140, isWarmup: false, loggedTheOffer: false, repsOnly: false)
        let carried = SameWeightCarry.apply(sets: rows, edit: edit)
        XCTAssertEqual(carried.sets.first { $0.setNumber == 2 }?.displayWeight, 140)
        XCTAssertEqual(carried.sets.first { $0.setNumber == 3 }?.displayWeight, 165)
        XCTAssertEqual(carried.sets.first { $0.setNumber == 0 }?.displayWeight, 145)
        var stack = StackDefinition.empty
        stack.step = 10
        stack.rangeMin = 10
        stack.rangeMax = 400
        let snapped = SameWeightCarry.snapUnprotected(
            sets: carried.sets,
            stack: stack,
            protected: Set(carried.changedSetNumbers).union([1])
        )
        XCTAssertEqual(snapped.sets.first { $0.setNumber == 3 }?.displayWeight, 160)
        XCTAssertEqual(snapped.sets.first { $0.setNumber == 3 }?.reps, 6)
        let undone = SameWeightCarry.undo(sets: snapped.sets, undo: carried.undo!)
        XCTAssertEqual(undone.first { $0.setNumber == 2 }?.displayWeight, 145)

        let offer = SameWeightCarry.apply(
            sets: rows,
            edit: SameWeightCarry.Edit(setNumber: 1, newWeight: 145, isWarmup: false, loggedTheOffer: true, repsOnly: false)
        )
        XCTAssertNil(offer.undo)
        let ramp = [
            CarrySet(setNumber: 1, planWeight: 135, reps: 5, isWarmup: false, isLogged: true, displayWeight: 135),
            CarrySet(setNumber: 2, planWeight: 155, reps: 5, isWarmup: false, isLogged: false, displayWeight: 155),
            CarrySet(setNumber: 3, planWeight: 175, reps: 5, isWarmup: false, isLogged: false, displayWeight: 175),
        ]
        let kept = SameWeightCarry.apply(
            sets: ramp,
            edit: SameWeightCarry.Edit(setNumber: 1, newWeight: 130, isWarmup: false, loggedTheOffer: false, repsOnly: false)
        )
        XCTAssertEqual(kept.sets.map(\.displayWeight), [130, 155, 175])
    }

    func test_warmupTag_doesNotCopy_andRampIsNotLogged() {
        XCTAssertFalse(WarmupPolicy.nextTag(planSaysWarmup: false))
        XCTAssertTrue(WarmupPolicy.nextTag(planSaysWarmup: true))
        let ramp = WarmupPolicy.ramp(workingWeight: 200, stackStep: 10)
        XCTAssertEqual(ramp.map(\.isWarmup), [true, true, true])
        XCTAssertEqual(ramp.map(\.reps), [8, 5, 3])
        XCTAssertEqual(ramp.first?.weight, 100)
    }

    func test_startingWeight_planWins_andLineOmitsAMissingSide() {
        let suggestion = WeightReps(weight: 230, reps: 5)
        let last = WeightReps(weight: 225, reps: 5)
        let lastTime = StartingWeight.resolve(input(plan: nil, last: last, suggestion: suggestion, starting: .lastTime, logged: 0))
        XCTAssertEqual(lastTime.weight, 225)
        XCTAssertEqual(lastTime.line.text(), "Last time 225×5 · Suggested 230×5")
        let suggested = StartingWeight.resolve(input(plan: nil, last: last, suggestion: suggestion, starting: .suggested, logged: 0))
        XCTAssertEqual(suggested.weight, 230)
        XCTAssertEqual(suggested.line.text(), lastTime.line.text())
        let plan = StartingWeight.resolve(input(plan: WeightReps(weight: 185, reps: 8), last: last, suggestion: suggestion, starting: .suggested, logged: 0))
        XCTAssertEqual(plan.weight, 185)
        XCTAssertEqual(plan.reps, 8)
        XCTAssertFalse(plan.isWarmup)
        let empty = StartingWeight.resolve(input(plan: nil, last: nil, suggestion: nil, starting: .lastTime, logged: 0))
        XCTAssertEqual(empty.line.text(), "")
        XCTAssertEqual(empty.weight, 0)
    }

    func test_previousMirrorsNext() {
        let done: (Int) -> Bool = { $0 == 1 }
        XCTAssertEqual(FocusNavigation.nextIndex(count: 3, index: 0, isDone: done), 2)
        XCTAssertEqual(FocusNavigation.previousIndex(count: 3, index: 2, isDone: done), 0)
        let none: (Int) -> Bool = { _ in false }
        XCTAssertEqual(FocusNavigation.previousIndex(count: 3, index: 0, isDone: none), 2)
        XCTAssertEqual(FocusNavigation.nextIndex(count: 3, index: 2, isDone: none), 0)
        let ends: (Int) -> Bool = { $0 != 1 }
        XCTAssertEqual(FocusNavigation.nextIndex(count: 3, index: 1, isDone: ends), 2)
        XCTAssertEqual(FocusNavigation.previousIndex(count: 3, index: 1, isDone: ends), 0)
        XCTAssertNil(FocusNavigation.previousIndex(count: 3, index: 0, isDone: { $0 != 0 }))
        XCTAssertNil(FocusNavigation.nextIndex(count: 3, index: 2, isDone: { $0 != 2 }))
        XCTAssertNil(FocusNavigation.nextIndex(count: 1, index: 0, isDone: { _ in false }))
        XCTAssertNil(FocusNavigation.previousIndex(count: 1, index: 0, isDone: { _ in false }))
    }

    func test_circuit_workingSetsAdvance_warmupsDoNot() {
        let members = [
            CircuitMember(exerciseID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, position: 1, isDone: false, loggedWorkingSets: 0, plannedWorkingCount: 3),
            CircuitMember(exerciseID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, position: 2, isDone: false, loggedWorkingSets: 0, plannedWorkingCount: 3),
        ]
        XCTAssertFalse(CircuitAdvance.canCreate(count: 1))
        XCTAssertFalse(CircuitAdvance.canCreate(count: 5))
        XCTAssertEqual(CircuitAdvance.next(after: members[0].exerciseID, members: members), members[1].exerciseID)
    }

    func test_restSeed_andLearningStaysQuietUntilEight() {
        XCTAssertEqual(RestSeed.seconds(name: "Back Squat", muscles: "Quads", settingsFallback: 90), 180)
        XCTAssertEqual(RestSeed.seconds(name: "Curl", muscles: "Biceps", settingsFallback: 120), 90)
        XCTAssertNil(RestLearning.offer(samples: [90, 90, 90], savedDefault: 180, enabled: true, alreadyOfferedThisSession: false))
        XCTAssertNil(RestLearning.offer(samples: Array(repeating: 90, count: 8), savedDefault: 180, enabled: false, alreadyOfferedThisSession: false))
        XCTAssertEqual(RestLearning.offer(samples: Array(repeating: 90, count: 8), savedDefault: 180, enabled: true, alreadyOfferedThisSession: false), 90)
    }

    func test_restAlert_zeroOnce_tenRearms_callSkipsChirp() {
        var state = RestAlertState.started(now: Date(timeIntervalSince1970: 0), duration: 30)
        var tick = RestAlertPolicy.Tick(
            now: Date(timeIntervalSince1970: 20),
            soundEnabled: true,
            tapAtTenEnabled: true,
            callConnected: false,
            liveActivitiesAvailable: true,
            notificationPermissionDenied: false,
            appIsActive: true
        )
        let ten = RestAlertPolicy.onTick(&state, tick: tick)
        XCTAssertTrue(ten.lightTap)
        tick.now = Date(timeIntervalSince1970: 21)
        XCTAssertFalse(RestAlertPolicy.onTick(&state, tick: tick).lightTap)
        _ = RestAlertPolicy.onNudge(&state, seconds: 15, now: tick.now)
        tick.now = state.endDate.addingTimeInterval(-9)
        XCTAssertTrue(RestAlertPolicy.onTick(&state, tick: tick).lightTap)
        tick.now = state.endDate
        tick.callConnected = true
        let zero = RestAlertPolicy.onTick(&state, tick: tick)
        XCTAssertTrue(zero.strongHaptic)
        XCTAssertFalse(zero.playChirp)
        XCTAssertFalse(zero.duck)
        XCTAssertFalse(RestAlertPolicy.onTick(&state, tick: tick).strongHaptic)
        XCTAssertFalse(RestAlertPolicy.chirpInterruptsSpokenAudio)
        XCTAssertFalse(RestAlertPolicy.keepAliveDucks)
        XCTAssertTrue(RestAlertPolicy.categoryIsPlayback)
        XCTAssertFalse(RestAlertPolicy.endAlertIsTimeSensitive)
        let skipped = RestAlertPolicy.onSkip(&state)
        XCTAssertTrue(skipped.cancelBackup)
        XCTAssertTrue(skipped.endActivity)
    }

    func test_interchange_preservesUnknownKeys_andWalksVersions() throws {
        let legacy = """
        {"version":1,"exercises":[],"sessions":[],"futureField":"kept","weightLbs":135}
        """.data(using: .utf8)!
        var object = try InterchangeCodec.parseObject(legacy)
        try InterchangeCodec.migrate(&object, to: 2)
        XCTAssertEqual(object["formatVersion"]?.int, 2)
        XCTAssertEqual(object["unitSystem"]?.string, "lb")
        XCTAssertEqual(object["payload"]?["futureField"]?.string, "kept")
        try InterchangeCodec.migrate(&object, to: 1)
        XCTAssertEqual(object["formatVersion"]?.int, 1)
        XCTAssertEqual(object["unitSystem"]?.string, "lb")
        let issues = InterchangeCodec.validate(object)
        XCTAssertTrue(issues.isEmpty, issues.map(\.message).joined(separator: ", "))
        object["weightUnit"] = .string("stone")
        XCTAssertFalse(InterchangeCodec.validate(object).isEmpty)
    }

    @MainActor
    func test_addSet_withNoLiveSession_doesNotCrash() throws {
        let container = try InMemoryRockLogStore.make()
        let context = container.mainContext
        let viewModel = WorkoutViewModel(modelContext: context, healthKitService: HealthKitWorkoutService())
        viewModel.resetAfterStoreReplace()
        let exercise = Exercise(name: "Bench", dayType: .push, muscleGroup: "Chest", sortOrder: 0)
        context.insert(exercise)
        viewModel.addSet(exercise: exercise, weight: 135, reps: 5)
        XCTAssertNil(viewModel.activeSession)
        let sets = try context.fetch(FetchDescriptor<SetRecord>())
        XCTAssertTrue(sets.isEmpty)
    }

    @MainActor
    func test_warmupFlag_isNotCopiedOntoTheNextLoggedSet() throws {
        let container = try InMemoryRockLogStore.make()
        let context = container.mainContext
        let viewModel = WorkoutViewModel(modelContext: context, healthKitService: HealthKitWorkoutService())
        let exercise = Exercise(name: "Squat", dayType: .legs, muscleGroup: "Quads", sortOrder: 0)
        context.insert(exercise)
        viewModel.startSession(dayType: .legs, rotationTrack: .every)
        viewModel.addSet(exercise: exercise, weight: 135, reps: 5, isWarmup: true)
        viewModel.addSet(exercise: exercise, weight: 225, reps: 5, isWarmup: WarmupPolicy.nextTag(planSaysWarmup: false))
        let sets = viewModel.currentRecord(for: exercise)?.loggedSetsArray.sorted { $0.setNumber < $1.setNumber }
        XCTAssertEqual(sets?.map(\.isWarmup), [true, false])
    }

    private func sample(_ n: Int, _ weights: [Double]) -> StackSessionSample {
        StackSessionSample(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000\(n)")!,
            date: Date(timeIntervalSince1970: Double(n) * 86_400),
            correctedPounds: weights
        )
    }

    private func input(
        plan: WeightReps?,
        last: WeightReps?,
        suggestion: WeightReps?,
        starting: StartingWeightChoice,
        logged: Int
    ) -> StartingWeight.Input {
        StartingWeight.Input(
            setNumber: logged + 1,
            loggedCount: logged,
            plan: plan,
            lastTimeSameSet: last,
            lastTimeBest: last,
            suggestion: suggestion,
            sessionLast: nil,
            repeatLastSet: false,
            starting: starting,
            stack: nil
        )
    }
}
