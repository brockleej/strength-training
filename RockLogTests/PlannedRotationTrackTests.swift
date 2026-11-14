//
//  PlannedRotationTrackTests.swift
//  RockLogTests
//
//  Starting a planned session must keep the A/B label stored at import.
//  Synthetic fixtures only — no personal workout history.
//

import XCTest
import SwiftData
@testable import RockLog

@MainActor
final class PlannedRotationTrackTests: RockLogStoreTestCase {

    func test_startPlannedSession_keepsImportedTrackB_whenTodayPickerIsA() throws {
        let session = try importLower(track: "B")
        XCTAssertEqual(session.track, .b)
        XCTAssertEqual(session.planStatus, .planned)

        let vm = makeViewModel()
        vm.startPlannedSession(session, rotationTrack: .a)

        XCTAssertEqual(vm.activeSession?.id, session.id)
        XCTAssertEqual(session.planStatus, .none)
        XCTAssertEqual(session.track, .b, "Today’s A picker must not replace an imported B")
    }

    func test_startPlannedSession_keepsImportedTrackA_whenTodayPickerIsB() throws {
        let session = try importLower(track: "A")
        let vm = makeViewModel()
        vm.startPlannedSession(session, rotationTrack: .b)

        XCTAssertEqual(vm.activeSession?.id, session.id)
        XCTAssertEqual(session.track, .a, "Today’s B picker must not replace an imported A")
    }

    func test_startSession_keepsImportedTrack_whenDayMatchesPlanned() throws {
        let session = try importLower(track: "B")
        let vm = makeViewModel()
        vm.startSession(dayType: .lower, rotationTrack: .a)

        let live = try XCTUnwrap(vm.activeSession)
        XCTAssertEqual(live.id, session.id)
        XCTAssertEqual(live.track, .b)
    }

    func test_resumePlannedSession_keepsImportedTrack() throws {
        let session = try importLower(track: "B")
        session.planStatus = .none
        let vm = makeViewModel()
        vm.suspendedSession = session

        vm.startPlannedSession(session, rotationTrack: .a)
        XCTAssertEqual(session.track, .b)
        XCTAssertEqual(vm.activeSession?.id, session.id)

        vm.suspendSession()
        vm.startSession(dayType: .lower, rotationTrack: .a)
        XCTAssertEqual(vm.activeSession?.id, session.id)
        XCTAssertEqual(session.track, .b)
    }

    func test_startUnplannedSession_usesPickerTrack() throws {
        let vm = makeViewModel()
        vm.startSession(dayType: .push, rotationTrack: .b)

        let live = try XCTUnwrap(vm.activeSession)
        XCTAssertEqual(live.day, .push)
        XCTAssertNil(live.trainingBlock)
        XCTAssertEqual(live.track, .b)

        vm.suspendSession()
        vm.startSession(dayType: .legs, rotationTrack: .a)
        let legs = try XCTUnwrap(vm.activeSession)
        XCTAssertEqual(legs.day, .legs)
        XCTAssertEqual(legs.track, .a)
    }

    func test_resumeUnplannedSession_usesPickerTrack() throws {
        let vm = makeViewModel()
        vm.startSession(dayType: .push, rotationTrack: .a)
        let session = try XCTUnwrap(vm.activeSession)
        XCTAssertEqual(session.track, .a)

        vm.suspendSession()
        vm.startSession(dayType: .push, rotationTrack: .b)
        XCTAssertEqual(vm.activeSession?.id, session.id)
        XCTAssertEqual(session.track, .b)
    }

    // MARK: - Fixture

    private func makeViewModel() -> WorkoutViewModel {
        holdWorkoutViewModel(WorkoutViewModel(
            modelContext: container.mainContext,
            healthKitService: HealthKitWorkoutService()
        ))
    }

    /// One unused Lower session. The lift name is synthetic.
    private func importLower(track: String) throws -> WorkoutSession {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let sessionID = UUID()
        let document = ProgramDocument(
            format: ProgramFormat.formatName,
            schemaVersion: ProgramFormat.schemaVersion,
            exportedAt: date,
            block: ProgramBlockPayload(
                id: UUID(),
                name: "Synthetic Planned Block",
                notes: "Fixture only.",
                startDate: date,
                sessions: [
                    ProgramSessionPayload(
                        id: sessionID,
                        date: date,
                        dayType: "Lower",
                        rotationTrack: track,
                        notes: nil,
                        exercises: [
                            ProgramExercisePayload(
                                id: UUID(),
                                name: "Demo Leg Press",
                                muscleGroup: "Quads",
                                trainingMode: "Strength",
                                notes: nil,
                                sets: [
                                    ProgramSetPayload(
                                        setNumber: 1,
                                        weightLbs: 180,
                                        reps: 8,
                                        isWarmup: false,
                                        isEachSide: false,
                                        isAssisted: false
                                    )
                                ]
                            )
                        ]
                    )
                ]
            )
        )
        _ = try ProgramImportService.importDocument(document, context: container.mainContext)
        let session = try XCTUnwrap(
            container.mainContext.fetch(FetchDescriptor<WorkoutSession>()).first { $0.id == sessionID }
        )
        XCTAssertEqual(session.day, .lower)
        XCTAssertNotNil(session.trainingBlock)
        return session
    }
}
