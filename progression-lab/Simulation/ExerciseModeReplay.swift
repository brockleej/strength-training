//
//  ExerciseModeReplay.swift
//  ProgressionLab
//

import Foundation

/// Per-session result of replaying the algorithm under both Config A and B.
/// One of these per (exercise, mode, session).
struct SessionReplay: Identifiable {
    let id = UUID()
    let sessionDate: Date
    let actualBestSet: SetSnapshot
    let suggestionA: ProgressionSuggestion?
    let suggestionB: ProgressionSuggestion?

    /// True if both suggestions are present, both are .improving or .consistent,
    /// and they differ on weight, reps, or basis.
    var isDisagreement: Bool {
        guard let a = suggestionA, let b = suggestionB else { return false }
        guard a.basis != .notEnoughData, b.basis != .notEnoughData else { return false }
        return a.targetWeight != b.targetWeight
            || a.targetReps != b.targetReps
            || a.basis != b.basis
    }

    /// True if both produced a real (non-notEnoughData) suggestion. Used as the
    /// denominator for disagreement-rate calculations.
    var isEligibleForComparison: Bool {
        guard let a = suggestionA, let b = suggestionB else { return false }
        return a.basis != .notEnoughData && b.basis != .notEnoughData
    }
}

/// All replay results for one exercise+mode pair, plus dashboard-summary data.
struct ExerciseModeReplay: Identifiable {
    var id: String { "\(exercise.id)-\(mode.rawValue)" }
    let exercise: LoadedExercise
    let mode: TrainingMode
    let sessions: [SessionReplay]   // chronological, oldest → newest
    let nextSuggestionA: ProgressionSuggestion?
    let nextSuggestionB: ProgressionSuggestion?

    /// Disagreement % for the dashboard. Returns nil when no eligible sessions.
    var disagreementRate: Double? {
        let eligible = sessions.filter(\.isEligibleForComparison)
        guard !eligible.isEmpty else { return nil }
        let disagreements = eligible.filter(\.isDisagreement).count
        return Double(disagreements) / Double(eligible.count)
    }
}
