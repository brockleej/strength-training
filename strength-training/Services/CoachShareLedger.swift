//
//  CoachShareLedger.swift
//  Session IDs already sent to RockCoach. “Unsent workouts” is everything
//  completed that is not in this set.
//

import Foundation

enum CoachShareLedger {
    static let idsKey = "coachSharedSessionIDs"

    nonisolated static var sharedIDs: Set<UUID> {
        get {
            let raw = UserDefaults.standard.stringArray(forKey: idsKey) ?? []
            return Set(raw.compactMap(UUID.init(uuidString:)))
        }
        set {
            UserDefaults.standard.set(newValue.map(\.uuidString).sorted(), forKey: idsKey)
        }
    }

    nonisolated static func markShared<S: Sequence>(_ ids: S) where S.Element == UUID {
        var next = sharedIDs
        next.formUnion(ids)
        sharedIDs = next
    }

    static func unshared(from sessions: [WorkoutSession]) -> [WorkoutSession] {
        unshared(from: sessions, alreadyShared: sharedIDs)
    }

    static func unshared(from sessions: [WorkoutSession], alreadyShared: Set<UUID>) -> [WorkoutSession] {
        sessions
            .filter { $0.isCompleted && !alreadyShared.contains($0.id) }
            .sorted { $0.date < $1.date }
    }
}
