// strength-training/Views/Progress/ExerciseDrillDownStats.swift
import Foundation

/// Pure-function shaper for `ExerciseDrillDownView`'s hero, mini-chart, and recent rows.
enum ExerciseDrillDownStats {

    struct Best: Equatable {
        let weight: Double
        let reps: Int
        let sessionDate: Date
        let e1RM: Double
        /// True if `sessionDate` is on the same calendar day as `now`.
        let isToday: Bool
    }

    struct Bar: Equatable, Identifiable {
        let id = UUID()
        let weight: Double
        let reps: Int
        let sessionDate: Date
        let isPR: Bool
        let isLatest: Bool
    }

    struct RecentRow: Equatable, Identifiable {
        let id = UUID()
        let sessionID: UUID
        let dateLabel: String
        let setsCount: Int
        let topReps: Int
        let topWeightLb: Double
        let isPR: Bool
    }

    static func personalBest(
        for exercise: Exercise,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Best? {
        let allSets: [(weight: Double, reps: Int, date: Date)] = exercise.recordsArray
            .filter { $0.session?.isCompleted == true }
            .flatMap { rec -> [(Double, Int, Date)] in
                guard let d = rec.session?.date else { return [] }
                return rec.setsArray
                    .filter { !$0.isWarmup }
                    .map { ($0.weightLbs, $0.reps, d) }
            }

        guard let top = allSets.max(by: {
            ProgressionService.e1RM(weight: $0.weight, reps: $0.reps)
              < ProgressionService.e1RM(weight: $1.weight, reps: $1.reps)
        }) else { return nil }

        let isToday = calendar.isDate(top.date, inSameDayAs: now)
        return Best(
            weight: top.weight,
            reps: top.reps,
            sessionDate: top.date,
            e1RM: ProgressionService.e1RM(weight: top.weight, reps: top.reps),
            isToday: isToday
        )
    }

    static func lastTenTopSetBars(for exercise: Exercise) -> [Bar] {
        // Records for completed sessions, sorted newest-first.
        let priorSorted = exercise.recordsArray
            .filter { $0.session?.isCompleted == true }
            .compactMap { rec -> (record: ExerciseRecord, date: Date)? in
                guard let d = rec.session?.date else { return nil }
                return (rec, d)
            }
            .sorted { $0.date > $1.date }

        // Take 10 most-recent then reverse to oldest → newest for charting.
        let recent = Array(priorSorted.prefix(10).reversed())
        guard !recent.isEmpty else { return [] }

        // Walk all-time history once to capture running-max e1RM BEFORE each record
        // for accurate PR flagging on older bars.
        let chrono = exercise.recordsArray
            .filter { $0.session?.isCompleted == true }
            .compactMap { rec -> (record: ExerciseRecord, date: Date)? in
                guard let d = rec.session?.date else { return nil }
                return (rec, d)
            }
            .sorted { $0.date < $1.date }

        var runningMax: Double = 0
        var maxAtOrBeforeID: [UUID: Double] = [:]
        for entry in chrono {
            let workingSets = entry.record.setsArray.filter { !$0.isWarmup }
            let sessionTopE1RM = workingSets
                .map { ProgressionService.e1RM(weight: $0.weightLbs, reps: $0.reps) }
                .max() ?? 0
            maxAtOrBeforeID[entry.record.id] = runningMax  // snapshot prior to this record
            if sessionTopE1RM > runningMax { runningMax = sessionTopE1RM }
        }

        var bars: [Bar] = []

        for (i, entry) in recent.enumerated() {
            let workingSets = entry.record.setsArray.filter { !$0.isWarmup }
            // Top set = highest e1RM (matches Phase 5)
            guard let top = workingSets.max(by: {
                ProgressionService.e1RM(weight: $0.weightLbs, reps: $0.reps)
                  < ProgressionService.e1RM(weight: $1.weightLbs, reps: $1.reps)
            }) else { continue }
            let topE1RM = ProgressionService.e1RM(weight: top.weightLbs, reps: top.reps)
            let priorMax = maxAtOrBeforeID[entry.record.id] ?? 0
            let isPR = topE1RM > priorMax
            let isLatest = (i == recent.count - 1)
            bars.append(Bar(
                weight: top.weightLbs,
                reps: top.reps,
                sessionDate: entry.date,
                isPR: isPR,
                isLatest: isLatest
            ))
        }
        return bars
    }

    static func recentSessionRows(
        for exercise: Exercise,
        limit: Int = 4,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [RecentRow] {
        let chrono = exercise.recordsArray
            .filter { $0.session?.isCompleted == true }
            .compactMap { rec -> (record: ExerciseRecord, session: WorkoutSession, date: Date)? in
                guard let s = rec.session, let d = rec.session?.date else { return nil }
                return (rec, s, d)
            }
            .sorted { $0.date < $1.date }

        // Compute per-record PR (e1RM beats running max prior to that record).
        var runningMax: Double = 0
        var prByRecordID: [UUID: Bool] = [:]
        for entry in chrono {
            let workingSets = entry.record.setsArray.filter { !$0.isWarmup }
            let topE1RM = workingSets
                .map { ProgressionService.e1RM(weight: $0.weightLbs, reps: $0.reps) }
                .max() ?? 0
            prByRecordID[entry.record.id] = topE1RM > runningMax
            if topE1RM > runningMax { runningMax = topE1RM }
        }

        let newest = chrono.reversed().prefix(limit)
        return newest.compactMap { entry in
            let workingSets = entry.record.setsArray.filter { !$0.isWarmup }
            guard !workingSets.isEmpty,
                  let top = workingSets.max(by: {
                      ProgressionService.e1RM(weight: $0.weightLbs, reps: $0.reps)
                        < ProgressionService.e1RM(weight: $1.weightLbs, reps: $1.reps)
                  }) else { return nil }
            let label = relativeLabel(for: entry.date, now: now, calendar: calendar)
            return RecentRow(
                sessionID: entry.session.id,
                dateLabel: label,
                setsCount: workingSets.count,
                topReps: top.reps,
                topWeightLb: top.weightLbs,
                isPR: prByRecordID[entry.record.id] ?? false
            )
        }
    }

    /// Compact relative label: "Today" / "Yesterday" / "N days ago" up to 6 days,
    /// "N wks ago" for under 8 weeks, otherwise "MMM d".
    static func relativeLabel(for date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return "Yesterday" }
        let daysAgo = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        if daysAgo < 7 { return "\(daysAgo) days ago" }
        let weeksAgo = daysAgo / 7
        if weeksAgo < 8 { return "\(weeksAgo) wks ago" }
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}
