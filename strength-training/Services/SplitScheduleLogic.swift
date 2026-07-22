//
//  SplitScheduleLogic.swift
//  strength-training
//
//  Pure helpers for next-day suggestion and incomplete-week detection.
//

import Foundation

enum SplitScheduleLogic {

    struct SessionStamp: Equatable {
        let dayName: String
        let date: Date
    }

    /// Prompt when a new week starts and the previous week didn’t finish the split.
    struct IncompleteWeekPrompt: Equatable {
        let previousCompleted: [String]
        let remaining: [String]
        let weekStart: Date
    }

    // MARK: - Calendar

    /// Monday-start week, matching Today / This Week UI.
    static func mondayStartCalendar(_ base: Calendar = .current) -> Calendar {
        var cal = base
        cal.firstWeekday = 2
        return cal
    }

    static func weekInterval(containing date: Date, calendar: Calendar) -> DateInterval? {
        calendar.dateInterval(of: .weekOfYear, for: date)
    }

    // MARK: - Cycle days

    /// Ordered days that participate in the split cycle (excludes Full Body catch-alls).
    static func cycleDays(from activeDays: [DayType]) -> [DayType] {
        let homes = activeDays.filter { !$0.includesAllExercises }
        return homes.isEmpty ? activeDays : homes
    }

    // MARK: - Suggestion

    /// Next day to train. `sessions` may be unsorted.
    static func suggestedDay(
        orderedDays: [DayType],
        sessions: [SessionStamp],
        mode: SplitScheduleMode,
        carryoverDayNames: [String],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> DayType? {
        let cycle = cycleDays(from: orderedDays)
        guard !cycle.isEmpty else { return orderedDays.first }

        let cal = mondayStartCalendar(calendar)

        switch mode {
        case .rolling:
            return rollingSuggestion(cycle: cycle, sessions: sessions)
        case .weekly:
            return weeklySuggestion(
                cycle: cycle,
                sessions: sessions,
                carryoverDayNames: carryoverDayNames,
                now: now,
                calendar: cal
            )
        }
    }

    /// Rolling: next after the most recent completed cycle day (wraps).
    static func rollingSuggestion(
        cycle: [DayType],
        sessions: [SessionStamp]
    ) -> DayType {
        let cycleNames = Set(cycle.map(\.rawValue))
        let last = sessions
            .filter { cycleNames.contains($0.dayName) }
            .max(by: { $0.date < $1.date })
        guard let last,
              let idx = cycle.firstIndex(where: { $0.rawValue == last.dayName })
        else {
            return cycle[0]
        }
        return cycle[(idx + 1) % cycle.count]
    }

    /// Weekly: first cycle day not yet done this Mon–Sun week (or still in carryover).
    static func weeklySuggestion(
        cycle: [DayType],
        sessions: [SessionStamp],
        carryoverDayNames: [String],
        now: Date,
        calendar: Calendar
    ) -> DayType {
        if !carryoverDayNames.isEmpty {
            let carry = Set(carryoverDayNames)
            if let next = cycle.first(where: { carry.contains($0.rawValue) }) {
                return next
            }
        }

        guard let week = weekInterval(containing: now, calendar: calendar) else {
            return cycle[0]
        }
        let done = Set(
            sessions
                .filter { week.contains($0.date) }
                .map(\.dayName)
        )
        if let next = cycle.first(where: { !done.contains($0.rawValue) }) {
            return next
        }
        // Full cycle done this week → stay on last day (or first if empty history).
        return cycle.last ?? cycle[0]
    }

    // MARK: - Incomplete previous week

    /// When the current week has no cycle sessions yet, and last week finished only part of the split.
    static func incompleteWeekPrompt(
        orderedDays: [DayType],
        sessions: [SessionStamp],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> IncompleteWeekPrompt? {
        let cycle = cycleDays(from: orderedDays)
        guard cycle.count > 1 else { return nil }

        let cal = mondayStartCalendar(calendar)
        guard let thisWeek = weekInterval(containing: now, calendar: cal),
              let previousStart = cal.date(byAdding: .day, value: -7, to: thisWeek.start),
              let previousWeek = weekInterval(containing: previousStart, calendar: cal)
        else { return nil }

        let cycleNames = Set(cycle.map(\.rawValue))
        let thisWeekCycleSessions = sessions.filter {
            thisWeek.contains($0.date) && cycleNames.contains($0.dayName)
        }
        // Only prompt at the start of a week (no progress yet this week).
        guard thisWeekCycleSessions.isEmpty else { return nil }

        let previousDoneNames = orderedUnique(
            sessions
                .filter { previousWeek.contains($0.date) && cycleNames.contains($0.dayName) }
                .map(\.dayName)
        )
        guard !previousDoneNames.isEmpty else { return nil }

        let remaining = cycle.filter { !previousDoneNames.contains($0.rawValue) }
        guard !remaining.isEmpty else { return nil }

        return IncompleteWeekPrompt(
            previousCompleted: previousDoneNames,
            remaining: remaining.map(\.rawValue),
            weekStart: thisWeek.start
        )
    }

    // MARK: - Carryover pruning

    /// Drop carryover days that already have a completed session on/after `after`.
    static func prunedCarryover(
        carryoverDayNames: [String],
        sessions: [SessionStamp],
        after: Date
    ) -> [String] {
        let completed = Set(
            sessions
                .filter { $0.date >= after }
                .map(\.dayName)
        )
        return carryoverDayNames.filter { !completed.contains($0) }
    }

    // MARK: - Helpers

    private static func orderedUnique(_ names: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for name in names {
            if seen.insert(name).inserted {
                result.append(name)
            }
        }
        return result
    }
}
