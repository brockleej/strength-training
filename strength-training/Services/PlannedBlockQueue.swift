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
    static func nextUpLabel(dayName: String) -> String {
        "Next up: \(dayName)"
    }

    static func cardSecondary(isNext: Bool, liftCount: Int) -> String {
        let lifts = liftCount == 1 ? "1 lift" : "\(liftCount) lifts"
        return isNext ? "Next up · \(lifts)" : "Then · \(lifts)"
    }

    /// Still waiting in the block: not trained, not started for real.
    static func isUnused(_ session: WorkoutSession) -> Bool {
        guard !session.isCompleted else { return false }
        if hasAthleteLoggedSets(session) { return false }
        if session.isPlanned || session.isSkippedPlan { return true }
        return session.trainingBlock != nil && session.followsSessionRoster
    }

    static func unusedSessions(in sessions: [WorkoutSession]) -> [WorkoutSession] {
        sessions
            .filter(isUnused)
            .sorted(by: isBeforeInQueue)
    }

    static func nextUnused(in sessions: [WorkoutSession]) -> WorkoutSession? {
        unusedSessions(in: sessions).first
    }

    /// File order first (`planOrder`), then the session’s stored date.
    static func isBeforeInQueue(_ lhs: WorkoutSession, _ rhs: WorkoutSession) -> Bool {
        if lhs.planOrder != rhs.planOrder {
            return lhs.planOrder < rhs.planOrder
        }
        return lhs.date < rhs.date
    }

    static func hasAthleteLoggedSets(_ session: WorkoutSession) -> Bool {
        session.exerciseRecordsArray.contains { record in
            record.setsArray.contains { !$0.isTarget }
        }
    }
}
