//
//  WorkoutEdgeCaseTests.swift
//  RockLogTests
//
//  Zero, negative, and very large loads, plus set edits that must stay finite.
//

import XCTest
import SwiftData
@testable import RockLog

@MainActor
final class WorkoutEdgeCaseTests: RockLogStoreTestCase {

    func test_effectiveLoad_clampsZeroAndNegative_hugeVolumeStaysFinite() {
        let zero = SetRecord(setNumber: 1, weightLbs: 0, reps: 10)
        XCTAssertEqual(zero.effectiveLoadLbs(), 0)
        XCTAssertEqual(zero.volumeContribution, 0)

        let negative = SetRecord(setNumber: 1, weightLbs: -40, reps: 8)
        XCTAssertEqual(negative.effectiveLoadLbs(), 0)
        XCTAssertEqual(negative.estimatedE1RM, 0)

        let huge = SetRecord(setNumber: 1, weightLbs: 10_000, reps: 10)
        XCTAssertEqual(huge.effectiveLoadLbs(), 10_000)
        XCTAssertEqual(huge.volumeContribution, 100_000)
        XCTAssertTrue(huge.volumeContribution.isFinite)
        XCTAssertTrue(huge.estimatedE1RM.isFinite)
    }

    func test_e1RM_zeroWeightIsZero() {
        XCTAssertEqual(E1RM.estimate(weightLbs: 0, reps: 10), 0)
        XCTAssertEqual(E1RM.estimate(weightLbs: 10_000, reps: 1), 10_000 * (1 + 1.0 / 30))
    }

    func test_addSet_allowsZeroAndTenThousand() throws {
        let context = container.mainContext
        let exercise = Exercise.make(name: "UI Load Lift", dayType: .push, isCustom: true)
        let session = WorkoutSession(dayType: .push, date: Date())
        context.insert(exercise)
        context.insert(session)
        try context.save()

        let viewModel = WorkoutViewModel(modelContext: context, healthKitService: HealthKitWorkoutService())
        viewModel.activeSession = session
        viewModel.addSet(exercise: exercise, weight: 0, reps: 10)
        XCTAssertNil(viewModel.pendingCelebration, "A zero-load set must not celebrate a PR.")
        viewModel.addSet(exercise: exercise, weight: 10_000, reps: 1)

        let weights = session.exerciseRecordsArray
            .flatMap(\.loggedSetsArray)
            .map(\.weightLbs)
            .sorted()
        XCTAssertEqual(weights, [0, 10_000])
    }

    func test_updateSet_clampsZeroRepsToOne() throws {
        let context = container.mainContext
        let exercise = Exercise.make(name: "UI Edit Lift", dayType: .push, isCustom: true)
        let session = WorkoutSession(dayType: .push, date: Date())
        context.insert(exercise)
        context.insert(session)
        try context.save()

        let viewModel = WorkoutViewModel(modelContext: context, healthKitService: HealthKitWorkoutService())
        viewModel.activeSession = session
        viewModel.addSet(exercise: exercise, weight: 135, reps: 5)
        let set = try XCTUnwrap(session.exerciseRecordsArray.flatMap(\.loggedSetsArray).first)
        viewModel.updateSet(set, weight: 135, reps: 0)
        XCTAssertEqual(set.reps, 1)
        XCTAssertFalse(set.isTarget)
    }
}
