//
//  Build121FixesTests.swift
//  RockLogTests
//
//  1.2.1 fixes from Lee's 1.2 notes (Nov 9–11 2026): planned targets in any
//  mode, rest alert off screen, and circuits staying on a lift after its last set.
//  Synthetic fixtures only — no personal workout history.
//

import XCTest
import SwiftData
@testable import RockLog

@MainActor
final class Build121FixesTests: RockLogStoreTestCase {

    // MARK: - Planned target hidden by the Strength/Endurance switch (Nov 9)

    func test_plannedRecord_showsPlan_whenSwitchIsOnEndurance() throws {
        let session = try importPlannedLower()
        let vm = makeViewModel()
        vm.startPlannedSession(session)
        let lift = try XCTUnwrap(session.exerciseRecordsArray.first?.exercise)

        // He flips the app-wide switch (list segment or Focus menu).
        vm.selectedMode = .lowWeightHighReps

        XCTAssertNil(vm.currentRecord(for: lift), "No Endurance record exists — this is what hid the plan")
        let planned = try XCTUnwrap(vm.plannedRecord(for: lift), "The plan must still be found")
        XCTAssertEqual(planned.plannedSetsArray.map(\.weightLbs), [175, 180])
        XCTAssertEqual(planned.plannedSetsArray.map(\.reps), [8, 8])
    }

    func test_startPlannedSession_resetsStickyEnduranceToThePlanMode() throws {
        let session = try importPlannedLower()
        let vm = makeViewModel()
        // Left on Endurance from an earlier workout in the same app run.
        vm.selectedMode = .lowWeightHighReps

        vm.startPlannedSession(session)

        XCTAssertEqual(vm.selectedMode, .highWeightLowReps)
        let lift = try XCTUnwrap(session.exerciseRecordsArray.first?.exercise)
        XCTAssertEqual(vm.currentRecord(for: lift)?.plannedSetsArray.count, 2)
    }

    func test_startSession_onThePlannedDay_alsoResetsTheMode() throws {
        let session = try importPlannedLower()
        let vm = makeViewModel()
        vm.selectedMode = .lowWeightHighReps

        vm.startSession(dayType: .lower, rotationTrack: .a)

        XCTAssertEqual(vm.activeSession?.id, session.id)
        XCTAssertEqual(vm.selectedMode, .highWeightLowReps)
    }

    func test_adHocSession_keepsTheSwitchWhereHeLeftIt() {
        let vm = makeViewModel()
        vm.selectedMode = .lowWeightHighReps
        vm.startSession(dayType: .push, rotationTrack: .a)
        XCTAssertEqual(vm.selectedMode, .lowWeightHighReps, "Nothing planned, so the switch is his")
    }

    func test_plannedRecord_isNil_forALiftWithNoPlan() throws {
        let session = try importPlannedLower()
        let vm = makeViewModel()
        vm.startPlannedSession(session)
        let stranger = Exercise.make(name: "Demo Unplanned Curl", dayType: .lower, muscleGroup: "Arms", sortOrder: 9, isCustom: true)
        container.mainContext.insert(stranger)
        XCTAssertNil(vm.plannedRecord(for: stranger))
    }

    // MARK: - Rest alert with the phone locked (Nov 9)

    func test_tickContext_readsTheRealScreenState() {
        let saved = RestAlertRuntime.isAppActive
        defer { RestAlertRuntime.isAppActive = saved }
        RestAlertRuntime.isAppActive = { false }
        XCTAssertFalse(RestAlertRuntime.tickContext(now: .now).appIsActive)
        RestAlertRuntime.isAppActive = { true }
        XCTAssertTrue(RestAlertRuntime.tickContext(now: .now).appIsActive)
    }

    func test_lockedPhone_noDuckNoBeep_andTheEndNotificationIsKept() {
        let result = walkCountdownRest(appActive: false)
        XCTAssertEqual(result.beeps, [], "No beep it cannot play off screen")
        XCTAssertFalse(result.ducked, "Never duck his audiobook for a beep that will not sound")
        XCTAssertFalse(result.chirp)
        XCTAssertFalse(result.cancelledBackup, "The Rest is over notification must be left to sound")
    }

    func test_onScreen_keepsTheFiveSecondCountdownBeeps() {
        let result = walkCountdownRest(appActive: true)
        XCTAssertEqual(result.beeps, [5, 4, 3, 2, 1])
        XCTAssertTrue(result.ducked)
        XCTAssertTrue(result.chirp)
        XCTAssertTrue(result.cancelledBackup, "On screen the app plays the end itself")
    }

    // MARK: - Circuit: stay on the lift after its last set (Nov 11)

    private let ids = [UUID(), UUID(), UUID()]

    private func members(_ logged: [Int], planned: [Int?]) -> [CircuitRoundMember] {
        logged.enumerated().map { index, count in
            CircuitRoundMember(exerciseID: ids[index], position: index + 1, loggedWorkingSets: count, plannedWorkingSets: planned[index])
        }
    }

    func test_circuit_lastSetOfALift_staysForDone_midRound() {
        // Lift 0 plans 2 sets, lift 1 plans 3. Lift 0 just logged its 2nd (last).
        let step = CircuitRounds.stepAfterLogging(ids[0], members: members([2, 1], planned: [2, 3]))
        XCTAssertTrue(step.staysForDone)
        XCTAssertFalse(step.restAfterRound, "Lift 1 still owes round 2, so no rest yet")
    }

    func test_circuit_finalRound_staysOnEachLift_insteadOfJumping() {
        let first = CircuitRounds.stepAfterLogging(ids[0], members: members([3, 2], planned: [3, 3]))
        XCTAssertTrue(first.staysForDone, "Last set of lift 0: stay so Done is right there")
        let last = CircuitRounds.stepAfterLogging(ids[1], members: members([3, 3], planned: [3, 3]))
        XCTAssertTrue(last.staysForDone, "Last set of the circuit stays too (no jump back to the list)")
        XCTAssertNil(last.next)
    }

    func test_circuit_nonFinalSets_stillAutoAdvance() {
        let step = CircuitRounds.stepAfterLogging(ids[0], members: members([1, 0, 0], planned: [3, 3, 3]))
        XCTAssertFalse(step.staysForDone)
        XCTAssertEqual(step.next, ids[1])
        XCTAssertFalse(step.restAfterRound)
    }

    func test_circuit_liftAlreadyMarkedDone_doesNotStay() {
        var m = members([3, 2], planned: [3, 3])
        m[0].isDone = true
        XCTAssertFalse(CircuitRounds.stepAfterLogging(ids[0], members: m).staysForDone)
    }

    // MARK: - Fixtures

    private func walkCountdownRest(appActive: Bool) -> (beeps: [Int], ducked: Bool, chirp: Bool, cancelledBackup: Bool) {
        let saved = RestAlertRuntime.isAppActive
        defer { RestAlertRuntime.isAppActive = saved }
        RestAlertRuntime.isAppActive = { appActive }
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var state = RestAlertState.started(now: start, duration: 20)
        var beeps: [Int] = []
        var ducked = false, chirp = false, cancelled = false
        var t = 0.15
        while t <= 20.4 {
            var tick = RestAlertRuntime.tickContext(now: start.addingTimeInterval(t))
            tick.endAlert = .countdown
            tick.soundEnabled = true
            tick.callConnected = false
            let effects = RestAlertPolicy.onTick(&state, tick: tick)
            if let beep = effects.countdownBeep { beeps.append(beep) }
            ducked = ducked || effects.duck
            chirp = chirp || effects.playChirp
            cancelled = cancelled || effects.cancelBackup
            t += 0.15
        }
        return (beeps, ducked, chirp, cancelled)
    }

    private func makeViewModel() -> WorkoutViewModel {
        holdWorkoutViewModel(WorkoutViewModel(
            modelContext: container.mainContext,
            healthKitService: HealthKitWorkoutService()
        ))
    }

    /// One unused Lower session with a two-set Strength plan. Synthetic names and numbers.
    private func importPlannedLower() throws -> WorkoutSession {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let sessionID = UUID()
        let document = ProgramDocument(
            format: ProgramFormat.formatName,
            schemaVersion: ProgramFormat.schemaVersion,
            exportedAt: date,
            block: ProgramBlockPayload(
                id: UUID(),
                name: "Synthetic 1.2.1 Block",
                notes: "Fixture only.",
                startDate: date,
                sessions: [
                    ProgramSessionPayload(
                        id: sessionID,
                        date: date,
                        dayType: "Lower",
                        rotationTrack: "A",
                        notes: nil,
                        exercises: [
                            ProgramExercisePayload(
                                id: UUID(),
                                name: "Demo Hack Squat",
                                muscleGroup: "Quads",
                                trainingMode: "Strength",
                                notes: nil,
                                sets: [
                                    ProgramSetPayload(setNumber: 1, weightLbs: 175, reps: 8, isWarmup: false, isEachSide: false, isAssisted: false),
                                    ProgramSetPayload(setNumber: 2, weightLbs: 180, reps: 8, isWarmup: false, isEachSide: false, isAssisted: false),
                                ]
                            )
                        ]
                    )
                ]
            )
        )
        _ = try ProgramImportService.importDocument(document, context: container.mainContext)
        return try XCTUnwrap(
            container.mainContext.fetch(FetchDescriptor<WorkoutSession>()).first { $0.id == sessionID }
        )
    }
}
