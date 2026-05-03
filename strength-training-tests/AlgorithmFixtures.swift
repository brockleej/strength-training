//
//  AlgorithmFixtures.swift
//  strength-training-tests
//
//  Synthetic data builders for ProgressionService tests.
//

import Foundation
@testable import strength_training

enum AlgorithmFixtures {

    /// One set with the given weight and reps. completedAt defaults to .now.
    static func set(_ weight: Double, reps: Int, isWarmup: Bool = false, at date: Date = .now) -> SetSnapshot {
        SetSnapshot(weightLbs: weight, reps: reps, isWarmup: isWarmup, completedAt: date)
    }

    /// One record on the given date with the given sets, in the given mode.
    static func record(
        date: Date,
        mode: TrainingMode = .highWeightLowReps,
        sets: [SetSnapshot]
    ) -> ExerciseRecordSnapshot {
        ExerciseRecordSnapshot(trainingMode: mode, sessionDate: date, sets: sets)
    }

    /// A series of `count` records, one per day going backwards from today,
    /// each with a single set at `weight × reps`. Returned newest-first to match
    /// the algorithm's expected sort order.
    static func steadyHistory(
        count: Int,
        weight: Double,
        reps: Int,
        mode: TrainingMode = .highWeightLowReps
    ) -> [ExerciseRecordSnapshot] {
        let today = Date()
        return (0..<count).map { dayOffset in
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: today)!
            return record(date: date, mode: mode, sets: [set(weight, reps: reps, at: date)])
        }
    }
}
