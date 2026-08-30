//
//  MonthlyOverload.swift
//  strength-training
//
//  Calendar-month progressive-overload recap for the Progress tab.
//  Derived view only — no new persisted entities.
//
//  Best working set: heaviest non-warmup set; if weights tie, higher reps
//  wins; if those tie, the first occurrence is kept.
//
//  Modes are combined (unlike last-session compare / in-workout progression,
//  which stay per-mode). A monthly review answers “did this lift get heavier
//  or get more reps?” — endurance sets lose to a heavier strength top set.
//

import Foundation

enum MonthlyOverload {

    // MARK: - Public types

    struct WorkingSet: Equatable {
        let weightLbs: Double
        let reps: Int

        /// Compact lift label, e.g. `"225×5"` or `"47.5×8"`.
        var formatted: String {
            "\(StepperLogic.format(weightLbs))×\(reps)"
        }
    }

    /// How this month’s best set compares to last month’s.
    ///
    /// Missing a month is **not** treated as a zero — `.new` / `.missing`
    /// rather than inventing `0×0`. Deloads are `.down` without extra emphasis.
    enum Comparison: Equatable {
        case up
        case down
        case flat
        case new
        case missing
    }

    struct SetInput: Equatable {
        let weightLbs: Double
        let reps: Int
        var isWarmup: Bool = false
    }

    struct LiftInput: Equatable {
        let exerciseID: UUID
        let exerciseName: String
        let dayTypeName: String
        let sortOrder: Int
        let sets: [SetInput]
    }

    struct SessionInput: Equatable {
        let date: Date
        let lifts: [LiftInput]
    }

    struct Row: Equatable, Identifiable {
        var id: UUID { exerciseID }
        let exerciseID: UUID
        let exerciseName: String
        let dayTypeName: String
        let sortOrder: Int
        let thisMonth: WorkingSet?
        let lastMonth: WorkingSet?
        let comparison: Comparison
        /// Short delta for the table: `"+5 lb"`, `"+1"`, `"="`, `"New"`, `"—"`.
        let deltaLabel: String
    }

    struct Group: Equatable, Identifiable {
        var id: String { dayTypeName }
        let dayTypeName: String
        let rows: [Row]
    }

    struct Review: Equatable {
        let thisMonthLabel: String
        let lastMonthLabel: String
        let thisMonthWorkoutCount: Int
        let lastMonthWorkoutCount: Int
        let groups: [Group]

        var rows: [Row] { groups.flatMap(\.rows) }
        var isEmpty: Bool { groups.isEmpty }
    }

    // MARK: - Calendar windows

    /// `[start, end)` of the calendar month containing `date`.
    static func monthInterval(containing date: Date, calendar: Calendar) -> DateInterval? {
        calendar.dateInterval(of: .month, for: date)
    }

    /// Calendar month immediately before `interval` (handles year wrap).
    static func previousMonthInterval(before interval: DateInterval, calendar: Calendar) -> DateInterval? {
        guard let lastStart = calendar.date(byAdding: .month, value: -1, to: interval.start) else {
            return nil
        }
        return calendar.dateInterval(of: .month, for: lastStart)
    }

    static func monthWindows(now: Date, calendar: Calendar) -> (this: DateInterval, last: DateInterval)? {
        guard let thisMonth = monthInterval(containing: now, calendar: calendar),
              let lastMonth = previousMonthInterval(before: thisMonth, calendar: calendar)
        else { return nil }
        return (thisMonth, lastMonth)
    }

    // MARK: - Best-set rule

    /// Heaviest non-warmup set; weight ties break to higher reps.
    /// Equal weight+reps keeps the first occurrence (`max` only replaces on `<`).
    static func bestWorkingSet(in sets: [SetInput]) -> WorkingSet? {
        sets
            .filter { !$0.isWarmup }
            .max { lhs, rhs in
                if lhs.weightLbs != rhs.weightLbs {
                    return lhs.weightLbs < rhs.weightLbs
                }
                return lhs.reps < rhs.reps
            }
            .map { WorkingSet(weightLbs: $0.weightLbs, reps: $0.reps) }
    }

    static func compare(thisMonth: WorkingSet?, lastMonth: WorkingSet?) -> Comparison {
        switch (thisMonth, lastMonth) {
        case (nil, nil):
            return .flat
        case (_?, nil):
            return .new
        case (nil, _?):
            return .missing
        case let (current?, previous?):
            if current.weightLbs > previous.weightLbs { return .up }
            if current.weightLbs < previous.weightLbs { return .down }
            if current.reps > previous.reps { return .up }
            if current.reps < previous.reps { return .down }
            return .flat
        }
    }

    static func deltaLabel(thisMonth: WorkingSet?, lastMonth: WorkingSet?) -> String {
        switch compare(thisMonth: thisMonth, lastMonth: lastMonth) {
        case .new:
            return "New"
        case .missing:
            return "—"
        case .flat:
            return "="
        case .up, .down:
            guard let current = thisMonth, let previous = lastMonth else { return "—" }
            let weightDelta = current.weightLbs - previous.weightLbs
            if weightDelta != 0 {
                let sign = weightDelta > 0 ? "+" : "−"
                return "\(sign)\(StepperLogic.format(abs(weightDelta))) lb"
            }
            let repsDelta = current.reps - previous.reps
            let sign = repsDelta > 0 ? "+" : "−"
            return "\(sign)\(abs(repsDelta))"
        }
    }

    // MARK: - Review

    static func review(
        sessions: [SessionInput],
        now: Date,
        calendar: Calendar,
        dayOrder: [String] = []
    ) -> Review {
        guard let windows = monthWindows(now: now, calendar: calendar) else {
            return Review(
                thisMonthLabel: "",
                lastMonthLabel: "",
                thisMonthWorkoutCount: 0,
                lastMonthWorkoutCount: 0,
                groups: []
            )
        }

        let thisSessions = sessions.filter { windows.this.contains($0.date) }
        let lastSessions = sessions.filter { windows.last.contains($0.date) }

        let thisByExercise = bestSetsByExercise(in: thisSessions)
        let lastByExercise = bestSetsByExercise(in: lastSessions)

        var identity: [UUID: (name: String, day: String, sort: Int)] = [:]
        for session in thisSessions + lastSessions {
            for lift in session.lifts {
                if identity[lift.exerciseID] == nil {
                    identity[lift.exerciseID] = (lift.exerciseName, lift.dayTypeName, lift.sortOrder)
                }
            }
        }

        let ids = Set(thisByExercise.keys).union(lastByExercise.keys)
        let rows: [Row] = ids.compactMap { id in
            guard let meta = identity[id] else { return nil }
            let thisBest = thisByExercise[id]
            let lastBest = lastByExercise[id]
            guard thisBest != nil || lastBest != nil else { return nil }
            return Row(
                exerciseID: id,
                exerciseName: meta.name,
                dayTypeName: meta.day,
                sortOrder: meta.sort,
                thisMonth: thisBest,
                lastMonth: lastBest,
                comparison: compare(thisMonth: thisBest, lastMonth: lastBest),
                deltaLabel: deltaLabel(thisMonth: thisBest, lastMonth: lastBest)
            )
        }

        let grouped = Dictionary(grouping: rows, by: \.dayTypeName)
        let groups: [Group] = grouped.keys
            .sorted { lhs, rhs in
                let l = groupSortKey(lhs, dayOrder: dayOrder)
                let r = groupSortKey(rhs, dayOrder: dayOrder)
                if l.rank != r.rank { return l.rank < r.rank }
                return l.name.localizedCaseInsensitiveCompare(r.name) == .orderedAscending
            }
            .compactMap { name in
                let sortedRows = (grouped[name] ?? []).sorted { lhs, rhs in
                    if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                    return lhs.exerciseName.localizedCaseInsensitiveCompare(rhs.exerciseName) == .orderedAscending
                }
                return sortedRows.isEmpty ? nil : Group(dayTypeName: name, rows: sortedRows)
            }

        return Review(
            thisMonthLabel: monthLabel(windows.this, calendar: calendar),
            lastMonthLabel: monthLabel(windows.last, calendar: calendar),
            thisMonthWorkoutCount: thisSessions.count,
            lastMonthWorkoutCount: lastSessions.count,
            groups: groups
        )
    }

    // MARK: - Private

    private static func bestSetsByExercise(in sessions: [SessionInput]) -> [UUID: WorkingSet] {
        var collected: [UUID: [SetInput]] = [:]
        for session in sessions {
            for lift in session.lifts {
                collected[lift.exerciseID, default: []].append(contentsOf: lift.sets)
            }
        }
        var best: [UUID: WorkingSet] = [:]
        for (id, sets) in collected {
            if let winner = bestWorkingSet(in: sets) {
                best[id] = winner
            }
        }
        return best
    }

    private static func groupSortKey(_ name: String, dayOrder: [String]) -> (rank: Int, name: String) {
        if let index = dayOrder.firstIndex(of: name) {
            return (index, name)
        }
        if name == DayType.unassigned.rawValue {
            return (Int.max - 1, name)
        }
        return (Int.max, name)
    }

    private static func monthLabel(_ interval: DateInterval, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter.string(from: interval.start)
    }
}
