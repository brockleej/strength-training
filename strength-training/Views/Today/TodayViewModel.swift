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

    /// "47 min" per day type, from the most recent completed session of that
    /// type that has a HealthKit workout. Missing key → no duration suffix.
    private(set) var lastDurations: [DayType: String] = [:]

    /// Re-sync selection every time Today appears.
    /// Priority: suspended session's day → most recent completed session's day → default.
    func syncSelection(
        suspended: WorkoutSession?,
        mostRecent: WorkoutSession?,
        suggestedTrack: (DayType) -> RotationTrack
    ) {
        selectedDayType = suspended?.day ?? mostRecent?.day ?? DayType.defaultSelection
        syncRotationTrack(suspended: suspended, suggestedTrack: suggestedTrack)
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
