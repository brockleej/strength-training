//
//  Stage3LogicTests.swift
//  RockLogTests
//
//  Stage 3 structure: one save log, the workout bar line, appearance, and
//  a gym-access store that is not the shared phone store.
//

import XCTest
import SwiftData
@testable import RockLog

@MainActor
final class Stage3LogicTests: RockLogStoreTestCase {
    func test_saveFailureLine_namesTheActionAndNotTheNote() {
        struct Stub: Error {}
        let line = ModelSave.failureLine(action: "add-gym", error: Stub())
        XCTAssertEqual(line, "save failed: add-gym (Stub)")
        XCTAssertFalse(line.contains("UI Gym"))
        XCTAssertFalse(line.contains("Synthetic"))
    }

    func test_loggedSave_onALiveStoreDoesNotRecordAFailure() throws {
        var lines: [String] = []
        ModelSave.record = { lines.append($0) }
        defer { ModelSave.record = nil }
        let exercise = Exercise.make(name: "Synthetic Press", dayType: .push, muscleGroup: "Chest", isCustom: true)
        container.mainContext.insert(exercise)
        ModelSave.logged(container.mainContext, action: "stage3-save")
        XCTAssertTrue(lines.isEmpty)
        let saved = try container.mainContext.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(saved.map(\.name), ["Synthetic Press"])
    }

    func test_activeWorkoutBar_showsRestAheadOfElapsed() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let now = start.addingTimeInterval(90)
        XCTAssertEqual(
            ActiveWorkoutBarCopy.line(sessionStarted: start, restEnd: nil, now: now),
            "Workout 1:30"
        )
        XCTAssertEqual(
            ActiveWorkoutBarCopy.line(sessionStarted: start, restEnd: now.addingTimeInterval(12), now: now),
            "Rest 12s"
        )
        XCTAssertNil(ActiveWorkoutBarCopy.line(sessionStarted: nil, restEnd: nil, now: now))
    }

    func test_appearance_darkIsTheDefaultAndSystemClearsTheOverride() {
        XCTAssertEqual(AppearanceChoice.dark.colorScheme, .dark)
        XCTAssertNil(AppearanceChoice.system.colorScheme)
        XCTAssertEqual(AppearanceChoice.light.colorScheme, .light)
        UserDefaults.standard.removeObject(forKey: AppearanceChoice.key)
        XCTAssertEqual(AppearanceChoice.stored(), .dark)
    }

    func test_previewGymAccess_isNotTheSharedStore() {
        let preview = GymAccessStore(previewEntries: [])
        XCTAssertTrue(preview.entries.isEmpty)
        XCTAssertFalse(preview === GymAccessStore.shared)
    }

    func test_cancelPendingWork_clearsTheRestCountdown() {
        let viewModel = holdWorkoutViewModel(
            WorkoutViewModel(modelContext: container.mainContext, healthKitService: HealthKitWorkoutService())
        )
        viewModel.startRest(seconds: 30)
        XCTAssertNotNil(viewModel.restEndDate)
        viewModel.cancelPendingWork()
        XCTAssertNil(viewModel.restEndDate)
    }
}
