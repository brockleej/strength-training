//
//  PlannedBlockQueue.swift
//  strength-training
//
//  An imported block is an ordered queue of unused sessions — not a calendar
//  that burns days you miss. File order is queue order.
//

import Foundation

enum PlannedBlockQueue {
    /// Next-up line for Today. No “you missed Monday.”
    nonisolated static func nextUpLabel(dayName: String) -> String {
        "Next up: \(dayName)"
    }

    nonisolated static func cardSecondary(isNext: Bool, liftCount: Int) -> String {
        let lifts = liftCount == 1 ? "1 lift" : "\(liftCount) lifts"
        return isNext ? "Next up · \(lifts)" : "Then · \(lifts)"
    }

    /// WorkoutSession / records are MainActor (SwiftData + default isolation).
    /// Do not pass `isUnused` as a function reference into Array.filter — that
    /// API is nonisolated and is this compile error.
    @MainActor
    static func isUnused(_ session: WorkoutSession) -> Bool {
        guard !session.isCompleted else { return false }
        if hasAthleteLoggedSets(session) { return false }
        if session.isPlanned || session.isSkippedPlan { return true }
        return session.trainingBlock != nil && session.followsSessionRoster
    }

    @MainActor
    static func unusedSessions(in sessions: [WorkoutSession]) -> [WorkoutSession] {
        // Don't call isolated helpers from Array.filter/sorted — those
        // closures are nonisolated even when this function is @MainActor.
        var ranked: [(session: WorkoutSession, order: Int, date: Date)] = []
        for session in sessions {
            guard isUnused(session) else { continue }
            ranked.append((session, session.planOrder, session.date))
        }
        ranked.sort { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.date < rhs.date
        }
        return ranked.map(\.session)
    }

    @MainActor
    static func nextUnused(in sessions: [WorkoutSession]) -> WorkoutSession? {
        unusedSessions(in: sessions).first
    }

    @MainActor
    static func hasAthleteLoggedSets(_ session: WorkoutSession) -> Bool {
        session.exerciseRecordsArray.contains { record in
            record.setsArray.contains { !$0.isTarget }
        }
    }
}
