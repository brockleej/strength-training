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

    /// Today / Settings copy while unused planned sessions are waiting.
    static let whatsNextEyebrow = "What's next"
    static let splitPausedWhileQueued =
        "You have planned workouts waiting. Today shows that list instead of your training split. The split comes back when the list is empty."

    /// Planned queue owns “what’s next.” The rolling split stays stored but is not the Today driver.
    static func ownsToday(unusedCount: Int) -> Bool {
        unusedCount > 0
    }

    static func ownsToday(_ sessions: [WorkoutSession]) -> Bool {
        ownsToday(unusedCount: unusedSessions(in: sessions).count)
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
