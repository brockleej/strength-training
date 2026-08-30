//
//  SessionRosterLogic.swift
//  strength-training
//
//  A dated planned session owns its lift list. The day-plan catalog is not
//  consulted — two Lowers in one week can be Conventional vs Romanian.
//

import Foundation

enum SessionRosterLogic {
    /// True when the workout list must come from this session’s records only.
    static func usesSessionRoster(_ session: WorkoutSession?) -> Bool {
        session?.followsSessionRoster == true
    }

    /// Planned (or lifted-from-plan) order. Drops missing library links; keeps first mode.
    static func exercises(in session: WorkoutSession) -> [Exercise] {
        var seen = Set<UUID>()
        return session.exerciseRecordsArray
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { record in
                guard let exercise = record.exercise, seen.insert(exercise.id).inserted else {
                    return nil
                }
                return exercise
            }
    }

    static func names(in session: WorkoutSession) -> [String] {
        exercises(in: session).map(\.name)
    }
}
