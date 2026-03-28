//
//  ProgressionService.swift
//  strength-training
//

import Foundation

struct ProgressionService {

    // Fixed window for computing the average (not affected by aggressiveness).
    static let averageWindow = 4

    // MARK: - Public API

    /// Compute the rolling average best set across the last `averageWindow` sessions.
    /// Returns nil if the exercise has never been done in this mode.
    static func recentAverage(for exercise: Exercise, mode: TrainingMode) -> RecentAverage? {
        let records = completedRecords(for: exercise, mode: mode)
        guard !records.isEmpty else { return nil }

        let window = Array(records.prefix(averageWindow))
        let bestSets = window.compactMap { bestSet(in: $0) }
        guard !bestSets.isEmpty else { return nil }

        let count = Double(bestSets.count)
        let avgWeight = bestSets.map(\.weightLbs).reduce(0, +) / count
        let avgReps = Int((bestSets.map { Double($0.reps) }.reduce(0, +) / count).rounded())

        return RecentAverage(weight: avgWeight, reps: avgReps, sessionCount: bestSets.count)
    }

    /// Compute the progression suggestion for the next session.
    /// Returns nil only when the exercise has never been attempted.
    static func suggestion(
        for exercise: Exercise,
        mode: TrainingMode,
        aggressiveness: ProgressionAggressiveness
    ) -> ProgressionSuggestion? {
        let records = completedRecords(for: exercise, mode: mode)

        // Not enough data: surface the single session's best set as a raw reference.
        guard records.count >= 2 else {
            guard let first = records.first, let best = bestSet(in: first) else { return nil }
            return ProgressionSuggestion(
                targetWeight: best.weightLbs,
                targetReps: best.reps,
                basis: .notEnoughData
            )
        }

        guard let avg = recentAverage(for: exercise, mode: mode) else { return nil }

        // Check the last N sessions (N = aggressiveness threshold) for consistency.
        // Clamp to actual record count — prefix(n) silently returns fewer items when
        // records.count < n, which would let allSatisfy fire with insufficient data.
        let threshold = min(aggressiveness.consistencyThreshold, records.count)
        let recentRecords = Array(records.prefix(threshold))
        let recentBestSets = recentRecords.compactMap { bestSet(in: $0) }

        let isConsistent: Bool
        switch mode {
        case .highWeightLowReps:  // Strength
            // Rep cap: once averaging ≥ 20 reps, always suggest bumping weight.
            if avg.reps >= 20 {
                isConsistent = true
            } else {
                // All recent sessions must have hit at least the current average reps.
                isConsistent = recentBestSets.allSatisfy { $0.reps >= avg.reps }
            }
        case .lowWeightHighReps:  // Endurance
            // Ceiling is dynamic: average + 20. Only bump weight if consistently
            // exceeding this ceiling — prevents early weight increases on high-rep exercises.
            let ceiling = avg.reps + 20
            isConsistent = recentBestSets.allSatisfy { $0.reps >= ceiling }
        }

        if isConsistent {
            return ProgressionSuggestion(
                targetWeight: snap5(avg.weight + 5),
                targetReps: avg.reps,
                basis: .consistent
            )
        } else {
            return ProgressionSuggestion(
                targetWeight: snap5(avg.weight),
                targetReps: avg.reps + 1,
                basis: .improving
            )
        }
    }

    // MARK: - Helpers

    /// All completed ExerciseRecords for this exercise + mode, newest first.
    private static func completedRecords(for exercise: Exercise, mode: TrainingMode) -> [ExerciseRecord] {
        exercise.records
            .filter { $0.trainingMode == mode && $0.session?.isCompleted == true }
            .sorted { ($0.session?.date ?? .distantPast) > ($1.session?.date ?? .distantPast) }
    }

    /// The single heaviest set in a record (by weight). Ties broken by first occurrence.
    private static func bestSet(in record: ExerciseRecord) -> SetRecord? {
        record.sets.max(by: { $0.weightLbs < $1.weightLbs })
    }

    /// Round to the nearest 5 lbs.
    private static func snap5(_ value: Double) -> Double {
        (value / 5).rounded() * 5
    }
}
