//
//  ProgressionService.swift
//  strength-training
//

import Foundation

struct ProgressionService {

    // Fixed window for computing the average (not affected by aggressiveness).
    static let averageWindow = 4

    // MARK: - Pure API (data-source-agnostic)

    /// Compute the rolling average best set across the last `window` sessions for
    /// the given training mode. Records may include other modes; this function
    /// applies the mode filter. Records must be pre-sorted newest-first by session
    /// date (the snapshot adapter is responsible for this).
    /// Returns nil if there are no records or no extractable best sets.
    static func recentAverage(
        records: [ExerciseRecordSnapshot],
        mode: TrainingMode,
        window: Int
    ) -> RecentAverage? {
        let filtered = records.filter { $0.trainingMode == mode }
        return recentAverage(filteredRecords: filtered, window: window)
    }

    /// Compute the progression suggestion for the next session.
    /// Records may include other modes; this function applies the mode filter.
    /// Records must be pre-sorted newest-first by session date.
    /// Returns nil only when no record exists for this exercise+mode.
    static func suggestion(
        records: [ExerciseRecordSnapshot],
        mode: TrainingMode,
        params: ProgressionParameters
    ) -> ProgressionSuggestion? {
        let filtered = records.filter { $0.trainingMode == mode }

        // Not enough data: surface the single session's best set as a raw reference.
        guard filtered.count >= 2 else {
            guard let first = filtered.first, let best = bestSet(in: first) else { return nil }
            return ProgressionSuggestion(
                targetWeight: best.weightLbs,
                targetReps: best.reps,
                basis: .notEnoughData
            )
        }

        guard let avg = recentAverage(filteredRecords: filtered, window: params.averageWindow) else {
            return nil
        }

        // Check the last N sessions (N = consistencyThreshold) for consistency.
        // Clamp to actual record count — prefix(n) silently returns fewer items when
        // records.count < n, which would let allSatisfy fire with insufficient data.
        let threshold = min(params.consistencyThreshold, filtered.count)
        let recentRecords = Array(filtered.prefix(threshold))
        let recentBestSets = recentRecords.compactMap { bestSet(in: $0) }

        let isConsistent: Bool
        switch mode {
        case .highWeightLowReps:  // Strength
            // Rep cap: once averaging at or above the cap, always suggest bumping weight.
            if avg.reps >= params.strengthRepCap {
                isConsistent = true
            } else {
                // All recent sessions must have hit at least the current average reps.
                isConsistent = recentBestSets.allSatisfy { $0.reps >= avg.reps }
            }
        case .lowWeightHighReps:  // Endurance
            // Ceiling is dynamic: average + offset. Only bump weight if consistently
            // exceeding this ceiling.
            let ceiling = avg.reps + params.enduranceCeilingOffset
            isConsistent = recentBestSets.allSatisfy { $0.reps >= ceiling }
        }

        if isConsistent {
            return ProgressionSuggestion(
                targetWeight: snap5(avg.weight + params.weightIncrement),
                targetReps: avg.reps,
                basis: .consistent
            )
        } else {
            return ProgressionSuggestion(
                targetWeight: snap5(avg.weight),
                targetReps: avg.reps + params.repIncrement,
                basis: .improving
            )
        }
    }

    // MARK: - Pure helpers

    /// Computes the rolling average over the first `window` records (assumed
    /// pre-filtered to the desired mode and pre-sorted newest-first).
    private static func recentAverage(
        filteredRecords: [ExerciseRecordSnapshot],
        window: Int
    ) -> RecentAverage? {
        guard !filteredRecords.isEmpty else { return nil }
        let windowed = Array(filteredRecords.prefix(window))
        let bestSets = windowed.compactMap { bestSet(in: $0) }
        guard !bestSets.isEmpty else { return nil }
        let count = Double(bestSets.count)
        let avgWeight = bestSets.map(\.weightLbs).reduce(0, +) / count
        let avgReps = Int((bestSets.map { Double($0.reps) }.reduce(0, +) / count).rounded())
        return RecentAverage(weight: avgWeight, reps: avgReps, sessionCount: bestSets.count)
    }

    /// The single heaviest *working* set in a snapshot record (by weight).
    /// Warm-up sets are excluded so a heavy ramp does not drive progression.
    /// Ties broken by first occurrence — Swift's `max(by:)` only replaces the
    /// running max when the predicate returns true, so the predicate `<` makes
    /// the *first* occurrence of the max win. This predicate is load-bearing.
    private static func bestSet(in record: ExerciseRecordSnapshot) -> SetSnapshot? {
        record.sets
            .filter { !$0.isWarmup }
            .max(by: { $0.weightLbs < $1.weightLbs })
    }

    /// Round to the nearest 5 lbs.
    static func snap5(_ value: Double) -> Double {
        (value / 5).rounded() * 5
    }
}
