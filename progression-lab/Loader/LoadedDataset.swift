//
//  LoadedDataset.swift
//  ProgressionLab
//

import Foundation

/// One exercise's identity + name + day type, lifted out of the JSON
/// for indexing snapshots.
struct LoadedExercise: Equatable {
    let id: UUID
    let name: String
    let dayType: String   // raw enum value as stored in the backup
    let muscleGroup: String
}

/// All snapshots for one exercise, grouped by training mode.
/// The algorithm consumes the per-mode array.
struct LoadedExerciseRecords: Equatable {
    let exercise: LoadedExercise
    let snapshots: [ExerciseRecordSnapshot]   // already sorted newest-first across modes
}

/// Successful result of parsing a backup JSON.
struct LoadedDataset {
    let sourceURL: URL
    let exportedAt: Date
    let exercises: [LoadedExerciseRecords]
    let summary: LoadedDatasetSummary
}

/// Human-readable summary used by the loader screen.
struct LoadedDatasetSummary {
    let exerciseCount: Int
    let sessionCount: Int
    let dateRangeStart: Date?
    let dateRangeEnd: Date?
    let skipReasons: [SkipReason: Int]   // count by reason

    enum SkipReason: String {
        case orphanedExerciseID = "orphaned exerciseID"
        case unknownTrainingMode = "unknown trainingMode"
        case incompleteSession = "incomplete session"
    }

    /// Renders e.g. "11 exercises, 47 sessions, Feb 26 → Apr 15, 2026 (3 records skipped: ...)"
    var displayLine: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        var line = "\(exerciseCount) exercises, \(sessionCount) sessions"
        if let start = dateRangeStart, let end = dateRangeEnd {
            line += ", \(formatter.string(from: start)) → \(formatter.string(from: end))"
        }
        let totalSkipped = skipReasons.values.reduce(0, +)
        if totalSkipped > 0 {
            let parts = skipReasons.sorted(by: { $0.key.rawValue < $1.key.rawValue })
                .map { "\($0.value) \($0.key.rawValue)" }
            line += " (\(totalSkipped) records skipped: \(parts.joined(separator: ", ")))"
        }
        return line
    }
}
