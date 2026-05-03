//
//  SimulationStoreTests.swift
//  progression-lab-tests
//

import XCTest
@testable import ProgressionLab

final class SimulationStoreTests: XCTestCase {

    private func makeDataset(
        exerciseCount: Int = 1,
        sessionsPerExercise: Int = 4,
        modes: [TrainingMode] = [.highWeightLowReps]
    ) -> LoadedDataset {
        var loaded: [LoadedExerciseRecords] = []
        for i in 0..<exerciseCount {
            let ex = LoadedExercise(
                id: UUID(),
                name: "Ex \(i)",
                dayType: "Arms",
                muscleGroup: "Test"
            )
            var snapshots: [ExerciseRecordSnapshot] = []
            for mode in modes {
                for j in 0..<sessionsPerExercise {
                    let date = Calendar.current.date(byAdding: .day, value: -j, to: Date())!
                    snapshots.append(ExerciseRecordSnapshot(
                        trainingMode: mode,
                        sessionDate: date,
                        sets: [SetSnapshot(weightLbs: 50, reps: 9, isWarmup: false, completedAt: date)]
                    ))
                }
            }
            loaded.append(LoadedExerciseRecords(exercise: ex, snapshots: snapshots))
        }
        let summary = LoadedDatasetSummary(
            exerciseCount: exerciseCount,
            sessionCount: sessionsPerExercise * exerciseCount,
            dateRangeStart: nil,
            dateRangeEnd: nil,
            skipReasons: [:]
        )
        return LoadedDataset(
            sourceURL: URL(fileURLWithPath: "/dev/null"),
            exportedAt: Date(),
            exercises: loaded,
            summary: summary
        )
    }

    func test_init_computesOneReplayPerExerciseModePair() {
        let dataset = makeDataset(exerciseCount: 2, modes: [.highWeightLowReps, .lowWeightHighReps])
        let store = SimulationStore(dataset: dataset)
        XCTAssertEqual(store.replays.count, 4)
    }

    func test_changingConfigB_changesReplayOutputs() {
        // Steady 4 × 50×9 history. With production params, both configs produce
        // the same .consistent suggestion: 50 + 5 = 55. Doubling Config B's
        // weight increment to 10 should give B a 60 target.
        let dataset = makeDataset()
        let store = SimulationStore(dataset: dataset)
        XCTAssertEqual(store.replays[0].nextSuggestionA?.targetWeight,
                       store.replays[0].nextSuggestionB?.targetWeight)

        var newParams = ProgressionParameters.productionModerate
        newParams.weightIncrement = 10
        store.configB.parameters = newParams
        store.recompute()

        XCTAssertEqual(store.replays[0].nextSuggestionA?.targetWeight, 55)
        XCTAssertEqual(store.replays[0].nextSuggestionB?.targetWeight, 60)
    }

    func test_emptyExerciseProducesNoReplay() {
        let dataset = makeDataset(modes: [.highWeightLowReps])
        let store = SimulationStore(dataset: dataset)
        XCTAssertEqual(store.replays.count, 1)
        XCTAssertEqual(store.replays[0].mode, .highWeightLowReps)
    }
}
