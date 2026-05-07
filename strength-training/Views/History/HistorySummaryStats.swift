// strength-training/Views/History/HistorySummaryStats.swift
import Foundation

/// Pure-function shaper for the History tab's summary strip.
/// Operates on a snapshot of completed `WorkoutSession`s passed in by the caller
/// (typically via SwiftData `@Query`). No SwiftData fetches, no UI dependencies.
enum HistorySummaryStats {

    /// Aggregated stats for the calendar month containing `now`.
    struct MonthStats: Equatable {
        let sessionCount: Int
        let totalVolumeLb: Int
        let prCount: Int
    }

    /// Compute this-month aggregates over `allCompletedSessions`.
    /// - Parameters:
    ///   - allCompletedSessions: every completed `WorkoutSession` the user has logged.
    ///     Order does not matter; the function sorts internally for PR detection.
    ///   - now: the reference date used to determine "this month". Defaults to `.now`.
    ///   - calendar: defaults to `.current`. Tests inject a fixed UTC calendar.
    /// - Returns: a `MonthStats` with session count, summed non-warmup volume, and PR count
    ///   for the current calendar month.
    static func thisMonth(
        allCompletedSessions: [WorkoutSession],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> MonthStats {
        guard let monthInterval = calendar.dateInterval(of: .month, for: now) else {
            return MonthStats(sessionCount: 0, totalVolumeLb: 0, prCount: 0)
        }

        let inMonth = allCompletedSessions.filter {
            monthInterval.contains($0.date)
        }

        let volume = inMonth.reduce(0) { acc, session in
            acc + nonWarmupVolume(session)
        }

        // Sessions sorted oldest → newest so we can scan all-time best as we go.
        // Tie-break on `id` for deterministic ordering when two sessions share an exact
        // timestamp — without it, the running best could flip between runs and PR count
        // would be non-reproducible.
        let sortedAll = allCompletedSessions.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        var bestByExercise: [UUID: Double] = [:]
        var prCount = 0

        for session in sortedAll {
            let isInMonth = monthInterval.contains(session.date)
            for record in session.exerciseRecordsArray {
                guard let exerciseID = record.exercise?.id else { continue }
                let bestPriorToThisSession = bestByExercise[exerciseID] ?? 0
                let bestThisSession = record.setsArray
                    .filter { !$0.isWarmup }
                    .map { ProgressionService.e1RM(weight: $0.weightLbs, reps: $0.reps) }
                    .max() ?? 0

                if isInMonth, bestThisSession > bestPriorToThisSession, bestThisSession > 0 {
                    prCount += 1
                }
                if bestThisSession > bestPriorToThisSession {
                    bestByExercise[exerciseID] = bestThisSession
                }
            }
        }

        return MonthStats(
            sessionCount: inMonth.count,
            totalVolumeLb: volume,
            prCount: prCount
        )
    }

    /// Compact volume display: `"12,840"`, `"187k"` for ≥100k.
    /// Used by the summary strip's center stat.
    static func formatVolume(_ lb: Int) -> String {
        if lb >= 100_000 {
            let k = Double(lb) / 1000.0
            return String(format: "%.0fk", k)
        }
        return lb.formatted(.number)
    }

    // MARK: - Private

    private static func nonWarmupVolume(_ session: WorkoutSession) -> Int {
        var total: Double = 0
        for record in session.exerciseRecordsArray {
            for set in record.setsArray where !set.isWarmup {
                total += set.weightLbs * Double(set.reps)
            }
        }
        return Int(total)
    }
}
