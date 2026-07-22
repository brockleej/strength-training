//
//  TodayViewModel.swift
//  strength-training
//
//  Slim state holder for the Today screen: day selection + A/B week + async
//  last-session-duration strings. Session lifecycle stays in WorkoutViewModel;
//  session data flows through @Query in TodayView.
//

import SwiftUI

@Observable
final class TodayViewModel {
    var selectedDayType: DayType = .arms
    /// A/B week for the selected day — applies to every day type.
    var selectedRotationTrack: RotationTrack = .a

    /// Weekly-mode dialog when last week didn’t finish the split.
    var incompleteWeekPrompt: SplitScheduleLogic.IncompleteWeekPrompt?

    /// "47 min" per day type, from the most recent completed session of that
    /// type that has a HealthKit workout. Missing key → no duration suffix.
    private(set) var lastDurations: [DayType: String] = [:]

    /// Re-sync selection every time Today appears.
    /// Priority: suspended session → schedule suggestion → default.
    func syncSelection(
        suspended: WorkoutSession?,
        completedSessions: [WorkoutSession],
        orderedDays: [DayType],
        suggestedTrack: (DayType) -> RotationTrack
    ) {
        pruneCarryover(completedSessions: completedSessions)

        if let suspended {
            selectedDayType = suspended.day
            syncRotationTrack(suspended: suspended, suggestedTrack: suggestedTrack)
            incompleteWeekPrompt = nil
            return
        }

        let stamps = completedSessions.map {
            SplitScheduleLogic.SessionStamp(dayName: $0.day.rawValue, date: $0.date)
        }
        let mode = SplitSchedulePreferences.mode

        if mode == .weekly {
            considerIncompleteWeekPrompt(
                orderedDays: orderedDays,
                stamps: stamps
            )
        } else {
            incompleteWeekPrompt = nil
        }

        let suggested = SplitScheduleLogic.suggestedDay(
            orderedDays: orderedDays,
            sessions: stamps,
            mode: mode,
            carryoverDayNames: SplitSchedulePreferences.carryoverDayNames
        )
        selectedDayType = suggested ?? DayType.defaultSelection
        syncRotationTrack(suspended: nil, suggestedTrack: suggestedTrack)
    }

    /// When the user picks a different day, refresh the suggested A/B week.
    func selectDayType(
        _ dayType: DayType,
        suspended: WorkoutSession?,
        suggestedTrack: (DayType) -> RotationTrack
    ) {
        selectedDayType = dayType
        syncRotationTrack(suspended: suspended, suggestedTrack: suggestedTrack)
    }

    // MARK: - Incomplete week actions
    // Each choice also writes SplitSchedulePreferences.mode so Settings stays in sync.

    /// Stay on strict weekly and finish days left from last week.
    func continueIncompleteWeek() {
        guard let prompt = incompleteWeekPrompt else { return }
        let remaining = prompt.remaining.map { DayType($0) }
        SplitSchedulePreferences.mode = .weekly
        SplitSchedulePreferences.setCarryover(remaining)
        SplitSchedulePreferences.markPrompted(weekStart: prompt.weekStart)
        incompleteWeekPrompt = nil
        if let first = remaining.first {
            selectedDayType = first
        }
    }

    /// Stay on strict weekly; abandon last week’s leftovers and start from day 1.
    func restartSplitThisWeek() {
        guard let prompt = incompleteWeekPrompt else { return }
        SplitSchedulePreferences.mode = .weekly
        SplitSchedulePreferences.clearCarryover()
        SplitSchedulePreferences.markPrompted(weekStart: prompt.weekStart)
        incompleteWeekPrompt = nil
        selectedDayType = DayType.exerciseHomeDays.first
            ?? DayType.allCases.first
            ?? .arms
    }

    /// Switch to rolling splits (Settings updates) and pick next day after last workout.
    func switchToRollingFromIncompletePrompt(orderedDays: [DayType], completedSessions: [WorkoutSession]) {
        guard let prompt = incompleteWeekPrompt else { return }
        SplitSchedulePreferences.mode = .rolling
        SplitSchedulePreferences.clearCarryover()
        SplitSchedulePreferences.markPrompted(weekStart: prompt.weekStart)
        incompleteWeekPrompt = nil
        let stamps = completedSessions.map {
            SplitScheduleLogic.SessionStamp(dayName: $0.day.rawValue, date: $0.date)
        }
        selectedDayType = SplitScheduleLogic.suggestedDay(
            orderedDays: orderedDays,
            sessions: stamps,
            mode: .rolling,
            carryoverDayNames: []
        ) ?? selectedDayType
    }

    func dismissIncompleteWeekPrompt() {
        // Ask once per week; do not change mode on dismiss.
        if let prompt = incompleteWeekPrompt {
            SplitSchedulePreferences.markPrompted(weekStart: prompt.weekStart)
        }
        incompleteWeekPrompt = nil
    }

    // MARK: - Private

    private func considerIncompleteWeekPrompt(
        orderedDays: [DayType],
        stamps: [SplitScheduleLogic.SessionStamp]
    ) {
        // Already carrying unfinished days — no need to re-prompt.
        if !SplitSchedulePreferences.carryoverDayNames.isEmpty {
            incompleteWeekPrompt = nil
            return
        }

        guard let prompt = SplitScheduleLogic.incompleteWeekPrompt(
            orderedDays: orderedDays,
            sessions: stamps
        ) else {
            incompleteWeekPrompt = nil
            return
        }

        if SplitSchedulePreferences.didPrompt(forWeekStart: prompt.weekStart) {
            incompleteWeekPrompt = nil
            return
        }

        incompleteWeekPrompt = prompt
    }

    private func pruneCarryover(completedSessions: [WorkoutSession]) {
        let carry = SplitSchedulePreferences.carryoverDayNames
        guard !carry.isEmpty else { return }
        // Drop days completed in the last 21 days (covers carryover finish).
        let after = Calendar.current.date(byAdding: .day, value: -21, to: .now) ?? .distantPast
        let stamps = completedSessions.map {
            SplitScheduleLogic.SessionStamp(dayName: $0.day.rawValue, date: $0.date)
        }
        let pruned = SplitScheduleLogic.prunedCarryover(
            carryoverDayNames: carry,
            sessions: stamps,
            after: after
        )
        if pruned != carry {
            SplitSchedulePreferences.carryoverDayNames = pruned
        }
    }

    private func syncRotationTrack(
        suspended: WorkoutSession?,
        suggestedTrack: (DayType) -> RotationTrack
    ) {
        if let suspended, suspended.day == selectedDayType {
            // Resume keeps the session's track; default All → A for the control.
            selectedRotationTrack = suspended.track == .every ? .a : suspended.track
        } else {
            selectedRotationTrack = suggestedTrack(selectedDayType)
        }
    }

    /// Fetch the duration string for each day type's most recent HK-backed session.
    /// `sessions` must be completed sessions sorted newest-first.
    func fetchLastDurations(sessions: [WorkoutSession], healthKitService: HealthKitWorkoutService) async {
        for dayType in DayType.allCases {
            guard let session = sessions.first(where: { $0.day == dayType && $0.healthKitWorkoutUUID != nil }),
                  let uuid = session.healthKitWorkoutUUID
            else { continue }
            if let stats = await healthKitService.fetchWorkoutStats(for: uuid) {
                let minutes = max(1, Int((stats.duration / 60).rounded()))
                lastDurations[dayType] = "\(minutes) min"
            }
        }
    }
}
