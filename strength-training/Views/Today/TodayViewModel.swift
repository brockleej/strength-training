//
//  TodayViewModel.swift
//  strength-training
//
//  Slim state holder for the Today screen: day selection + async
//  last-session-duration strings. Session lifecycle stays in WorkoutViewModel;
//  session data flows through @Query in TodayView.
//

import SwiftUI

@Observable
final class TodayViewModel {
    var selectedDayType: DayType = .arms

    /// "47 min" per day type, from the most recent completed session of that
    /// type that has a HealthKit workout. Missing key → no duration suffix.
    private(set) var lastDurations: [DayType: String] = [:]

    /// Re-sync selection every time Today appears.
    /// Priority: suspended session's day → most recent completed session's day → Arms.
    func syncSelection(suspended: WorkoutSession?, mostRecent: WorkoutSession?) {
        selectedDayType = suspended?.dayType ?? mostRecent?.dayType ?? .arms
    }

    /// Fetch the duration string for each day type's most recent HK-backed session.
    /// `sessions` must be completed sessions sorted newest-first.
    func fetchLastDurations(sessions: [WorkoutSession], healthKitService: HealthKitWorkoutService) async {
        for dayType in DayType.allCases {
            guard let session = sessions.first(where: { $0.dayType == dayType && $0.healthKitWorkoutUUID != nil }),
                  let uuid = session.healthKitWorkoutUUID
            else { continue }
            if let stats = await healthKitService.fetchWorkoutStats(for: uuid) {
                let minutes = max(1, Int((stats.duration / 60).rounded()))
                lastDurations[dayType] = "\(minutes) min"
            }
        }
    }
}
