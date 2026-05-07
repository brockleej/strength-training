// strength-training/Views/Progress/LiftProgressionStats.swift
import Foundation

/// Pure-function shaper for the Progress dashboard's "LIFT PROGRESSION" section.
enum LiftProgressionStats {

    struct Row: Equatable, Identifiable {
        /// Stable identity = exercise.id.
        let id: UUID
        let exerciseName: String
        let dayType: DayType
        let topWeightLb: Double
        let allTimeBestLb: Double
        /// 0...1 — progress bar fill (topWeightLb / allTimeBestLb, clamped).
        let progressPct: Double
        let deltaVsLastSessionLb: Double?
        let isPR: Bool
    }

    /// Build sortable lift-progression rows for the dashboard.
    /// Filters: only exercises with at least one completed non-warmup set in `range`.
    /// Order: descending by `topWeightLb`, ties broken by `exerciseName`.
    static func rows(
        in range: ProgressTimeRange,
        exercises: [Exercise],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Row] {
        let start = range.startDate(now: now, calendar: calendar)

        let raw = exercises.compactMap { exercise -> Row? in
            // All non-warmup sets across all completed sessions for this exercise,
            // each annotated with its session date.
            let allSets: [(weight: Double, reps: Int, sessionDate: Date)] = exercise.recordsArray
                .filter { $0.session?.isCompleted == true }
                .flatMap { rec -> [(Double, Int, Date)] in
                    guard let date = rec.session?.date else { return [] }
                    return rec.setsArray
                        .filter { !$0.isWarmup }
                        .map { ($0.weightLbs, $0.reps, date) }
                }

            guard !allSets.isEmpty else { return nil }

            // Filter to in-period for the headline weight; whole history for all-time best.
            let inPeriod = allSets.filter { tup in
                if let s = start { return tup.sessionDate >= s && tup.sessionDate <= now }
                return true
            }
            guard !inPeriod.isEmpty else { return nil }

            let topInPeriod = inPeriod.map(\.weight).max() ?? 0
            let allTimeBest = allSets.map(\.weight).max() ?? topInPeriod
            let pct = allTimeBest > 0 ? min(1.0, max(0, topInPeriod / allTimeBest)) : 0

            // Delta vs last session: compare the most-recent in-period session's top set
            // to the session immediately preceding it (any window).
            let sessionsByDate = Dictionary(grouping: allSets, by: \.sessionDate)
                .map { (date: $0.key, sets: $0.value) }
                .sorted { $0.date < $1.date }
            let inPeriodSessionsByDate = sessionsByDate.filter {
                if let s = start { return $0.date >= s && $0.date <= now }
                return true
            }
            let deltaLb: Double?
            let isPR: Bool
            if let latest = inPeriodSessionsByDate.last,
               let latestIdx = sessionsByDate.firstIndex(where: { $0.date == latest.date }) {
                let latestTopWeight = latest.sets.map(\.weight).max() ?? 0
                let latestTopE1RM = latest.sets
                    .map { ProgressionService.e1RM(weight: $0.weight, reps: $0.reps) }
                    .max() ?? 0
                let priorE1RM = sessionsByDate[..<latestIdx]
                    .flatMap { $0.sets }
                    .map { ProgressionService.e1RM(weight: $0.weight, reps: $0.reps) }
                    .max() ?? 0
                isPR = latestTopE1RM > priorE1RM

                if latestIdx > 0 {
                    let prev = sessionsByDate[latestIdx - 1]
                    let prevTopWeight = prev.sets.map(\.weight).max() ?? 0
                    deltaLb = latestTopWeight - prevTopWeight
                } else {
                    deltaLb = nil
                }
            } else {
                deltaLb = nil
                isPR = false
            }

            return Row(
                id: exercise.id,
                exerciseName: exercise.name,
                dayType: exercise.dayType,
                topWeightLb: topInPeriod,
                allTimeBestLb: allTimeBest,
                progressPct: pct,
                deltaVsLastSessionLb: deltaLb,
                isPR: isPR
            )
        }

        return raw.sorted { lhs, rhs in
            if lhs.topWeightLb != rhs.topWeightLb { return lhs.topWeightLb > rhs.topWeightLb }
            return lhs.exerciseName < rhs.exerciseName
        }
    }
}
