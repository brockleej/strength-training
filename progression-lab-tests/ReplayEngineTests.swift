//
//  ReplayEngineTests.swift
//  progression-lab-tests
//

import XCTest
@testable import ProgressionLab

final class ReplayEngineTests: XCTestCase {

    private let exercise = LoadedExercise(
        id: UUID(),
        name: "Test",
        dayType: "Arms",
        muscleGroup: "Test"
    )

    private func snapshot(daysAgo: Int, weight: Double, reps: Int, mode: TrainingMode = .highWeightLowReps) -> ExerciseRecordSnapshot {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return ExerciseRecordSnapshot(
            trainingMode: mode,
            sessionDate: date,
            sets: [SetSnapshot(weightLbs: weight, reps: reps, isWarmup: false, completedAt: date)]
        )
    }

    func test_replay_chronologicalOrder() {
        let snapshots = [
            snapshot(daysAgo: 0, weight: 50, reps: 9),
            snapshot(daysAgo: 1, weight: 50, reps: 8),
            snapshot(daysAgo: 2, weight: 50, reps: 7),
        ]
        let result = ReplayEngine.replay(
            exercise: exercise,
            mode: .highWeightLowReps,
            allSnapshots: snapshots,
            configA: .productionModerate,
            configB: .productionModerate
        )
        XCTAssertEqual(result.sessions.count, 3)
        XCTAssertEqual(result.sessions[0].actualBestSet.reps, 7)
        XCTAssertEqual(result.sessions[2].actualBestSet.reps, 9)
    }

    func test_replay_firstSessionGetsNoSuggestion() {
        let snapshots = [snapshot(daysAgo: 0, weight: 50, reps: 9)]
        let result = ReplayEngine.replay(
            exercise: exercise,
            mode: .highWeightLowReps,
            allSnapshots: snapshots,
            configA: .productionModerate,
            configB: .productionModerate
        )
        XCTAssertEqual(result.sessions.count, 1)
        XCTAssertNil(result.sessions[0].suggestionA)
        XCTAssertNil(result.sessions[0].suggestionB)
    }

    func test_replay_secondSessionGetsNotEnoughDataSuggestion() {
        let snapshots = [
            snapshot(daysAgo: 1, weight: 50, reps: 8),
            snapshot(daysAgo: 0, weight: 50, reps: 9),
        ]
        let result = ReplayEngine.replay(
            exercise: exercise,
            mode: .highWeightLowReps,
            allSnapshots: snapshots,
            configA: .productionModerate,
            configB: .productionModerate
        )
        XCTAssertEqual(result.sessions.count, 2)
        XCTAssertNil(result.sessions[0].suggestionA)
        XCTAssertEqual(result.sessions[1].suggestionA?.basis, .notEnoughData)
        XCTAssertEqual(result.sessions[1].suggestionA?.targetWeight, 50)
        XCTAssertEqual(result.sessions[1].suggestionA?.targetReps, 8)
    }

    func test_replay_nextSuggestionUsesAllHistory() {
        let snapshots = (0..<4).map { snapshot(daysAgo: $0, weight: 50, reps: 9) }
        let result = ReplayEngine.replay(
            exercise: exercise,
            mode: .highWeightLowReps,
            allSnapshots: snapshots,
            configA: .productionModerate,
            configB: .productionModerate
        )
        XCTAssertEqual(result.nextSuggestionA?.basis, .consistent)
        XCTAssertEqual(result.nextSuggestionA?.targetWeight, 55)
    }

    func test_replay_disagreementWhenConfigsDiffer() {
        // Oldest first; engine reverses to newest-first when feeding the algorithm.
        // For session at daysAgo=0, history = sessions at daysAgo=4..1, reversed → newest-first reps [9,9,7,9]
        // (matches the parity test fixture: moderate consistent 55×9, conservative improving 50×10)
        let snapshots = [
            snapshot(daysAgo: 4, weight: 50, reps: 9),
            snapshot(daysAgo: 3, weight: 50, reps: 7),
            snapshot(daysAgo: 2, weight: 50, reps: 9),
            snapshot(daysAgo: 1, weight: 50, reps: 9),
            snapshot(daysAgo: 0, weight: 50, reps: 9),
        ]
        let result = ReplayEngine.replay(
            exercise: exercise,
            mode: .highWeightLowReps,
            allSnapshots: snapshots,
            configA: .productionModerate,
            configB: .productionConservative
        )
        let final = result.sessions.last!
        XCTAssertNotNil(final.suggestionA)
        XCTAssertNotNil(final.suggestionB)
        XCTAssertTrue(final.isDisagreement)
        XCTAssertGreaterThan(result.disagreementRate ?? 0, 0)
    }

    func test_replay_modeFilterIgnoresOtherModes() {
        let strength = snapshot(daysAgo: 1, weight: 50, reps: 8, mode: .highWeightLowReps)
        let endurance = snapshot(daysAgo: 0, weight: 30, reps: 20, mode: .lowWeightHighReps)
        let result = ReplayEngine.replay(
            exercise: exercise,
            mode: .highWeightLowReps,
            allSnapshots: [strength, endurance],
            configA: .productionModerate,
            configB: .productionModerate
        )
        XCTAssertEqual(result.sessions.count, 1)
        XCTAssertEqual(result.sessions[0].actualBestSet.weightLbs, 50)
    }
}
