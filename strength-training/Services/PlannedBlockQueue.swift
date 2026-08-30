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

    /// Today / Settings copy while unused planned sessions are waiting.
    nonisolated static let whatsNextEyebrow = "What's next"
    nonisolated static let splitPausedWhileQueued =
        "You have planned workouts waiting. Today shows that list instead of your training split. The split comes back when the list is empty."

    /// Planned queue owns “what’s next.” The rolling split stays stored but is not the Today driver.
    nonisolated static func ownsToday(unusedCount: Int) -> Bool {
        unusedCount > 0
    }

    /// WorkoutSession / records are MainActor (SwiftData + default isolation).
    /// Do not pass `isUnused` as a function reference into Array.filter — that
    /// API is nonisolated and is the PR 7 compile error.
    @MainActor
    static func ownsToday(_ sessions: [WorkoutSession]) -> Bool {
        ownsToday(unusedCount: unusedSessions(in: sessions).count)
    }

    /// Still waiting in the block: not trained, not started for real.
    @MainActor
    static func isUnused(_ session: WorkoutSession) -> Bool {
        guard !session.isCompleted else { return false }
        if hasAthleteLoggedSets(session) { return false }
        if session.isPlanned || session.isSkippedPlan { return true }
        return session.trainingBlock != nil && session.followsSessionRoster
    }

    @MainActor
    static func unusedSessions(in sessions: [WorkoutSession]) -> [WorkoutSession] {
        sessions
            .filter { isUnused($0) }
            .sorted { isBeforeInQueue($0, $1) }
    }

    @MainActor
    static func nextUnused(in sessions: [WorkoutSession]) -> WorkoutSession? {
        unusedSessions(in: sessions).first
    }

    /// File order first (`planOrder`), then the session’s stored date.
    @MainActor
    static func isBeforeInQueue(_ lhs: WorkoutSession, _ rhs: WorkoutSession) -> Bool {
        if lhs.planOrder != rhs.planOrder {
            return lhs.planOrder < rhs.planOrder
        }
        return lhs.date < rhs.date
    }

    @MainActor
    static func hasAthleteLoggedSets(_ session: WorkoutSession) -> Bool {
        session.exerciseRecordsArray.contains { record in
            record.setsArray.contains { !$0.isTarget }
        }
    }
}
