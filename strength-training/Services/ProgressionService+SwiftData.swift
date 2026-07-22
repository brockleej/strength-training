//
//  ProgressionService+SwiftData.swift
//  strength-training
//
//  iOS-only adapter that exposes the pure ProgressionService API on top of
//  SwiftData @Model types. Lives outside Shared/Algorithm/ so the macOS
//  ProgressionLab target doesn't try to compile SwiftData-coupled code.
//

import Foundation
import SwiftData

extension ProgressionService {
    /// Compute the rolling average best set across the last `averageWindow` sessions.
    /// Returns nil if the exercise has never been done in this mode.
    static func recentAverage(for exercise: Exercise, mode: TrainingMode) -> RecentAverage? {
        let snapshots = snapshotsFromCompletedRecords(of: exercise)
        return recentAverage(records: snapshots, mode: mode, window: averageWindow)
    }

    /// Compute the progression suggestion for the next session.
    /// Returns nil only when the exercise has never been attempted.
    static func suggestion(
        for exercise: Exercise,
        mode: TrainingMode,
        aggressiveness: ProgressionAggressiveness
    ) -> ProgressionSuggestion? {
        let snapshots = snapshotsFromCompletedRecords(of: exercise)
        return suggestion(records: snapshots, mode: mode, params: aggressiveness.parameters)
    }

    /// Adapts an `Exercise`'s SwiftData records into `ExerciseRecordSnapshot`s
    /// for the pure algorithm. Preserves the existing filters: completed-only
    /// sessions, sorted newest-first by session date.
    private static func snapshotsFromCompletedRecords(of exercise: Exercise) -> [ExerciseRecordSnapshot] {
        exercise.recordsArray
            .filter { $0.session?.isCompleted == true }
            .sorted { ($0.session?.date ?? .distantPast) > ($1.session?.date ?? .distantPast) }
            .compactMap { record in
                guard let sessionDate = record.session?.date else { return nil }
                let sets = record.setsArray.map { swiftDataSet in
                    // Assisted: feed effective load (BW − assist) so progression
                    // tracks harder work as assistance drops — never negative.
                    SetSnapshot(
                        weightLbs: swiftDataSet.effectiveLoadLbs(),
                        reps: swiftDataSet.reps,
                        isWarmup: swiftDataSet.isWarmup,
                        completedAt: swiftDataSet.completedAt
                    )
                }
                return ExerciseRecordSnapshot(
                    trainingMode: record.trainingMode,
                    sessionDate: sessionDate,
                    sets: sets
                )
            }
    }
}
