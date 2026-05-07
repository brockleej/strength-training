// strength-training/Views/Workout/WorkoutSummaryStats.swift
import Foundation

/// Pure-function stats helper for `WorkoutSummaryView`. Operates on a single
/// `WorkoutSession`'s in-memory state — no SwiftData fetches, no UI dependencies.
enum WorkoutSummaryStats {

    /// Wall-clock duration from session start to the last logged set's `completedAt`.
    /// Returns 0 if the session has no sets.
    static func durationSeconds(for session: WorkoutSession) -> TimeInterval {
        let allSets = session.exerciseRecordsArray.flatMap { $0.setsArray }
        guard let last = allSets.map(\.completedAt).max() else { return 0 }
        return last.timeIntervalSince(session.date)
    }

    /// Total weight × reps across all non-warmup sets. Integer for clean display.
    static func totalVolume(for session: WorkoutSession) -> Int {
        var total: Double = 0
        for record in session.exerciseRecordsArray {
            for set in record.setsArray where !set.isWarmup {
                total += set.weightLbs * Double(set.reps)
            }
        }
        return Int(total)
    }

    /// Count of non-warmup sets across all records in the session.
    static func totalSets(for session: WorkoutSession) -> Int {
        session.exerciseRecordsArray.reduce(0) { count, record in
            count + record.setsArray.filter { !$0.isWarmup }.count
        }
    }

    /// Whole-minute duration (floor). Used for the "47 min" display.
    static func formatDurationMin(_ seconds: TimeInterval) -> Int {
        Int(seconds / 60)
    }
}
