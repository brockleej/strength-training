//
//  CircuitRounds.swift
//  RockLog
//
//  In-workout circuit rounds (mockup circuit-flow). Log set inside a round goes
//  straight to the next lift with no rest; rest runs once after each round.
//

import Foundation

// MARK: - Rounds in a workout

nonisolated struct CircuitRoundMember: Equatable, Sendable {
    var exerciseID: UUID
    var position: Int
    var loggedWorkingSets: Int
    /// Planned working sets. Nil when the day has no targets for this lift.
    var plannedWorkingSets: Int?
    var isDone: Bool = false
}

nonisolated struct CircuitRoundStep: Equatable, Sendable {
    /// Lift to open next. Nil when the circuit is finished.
    var next: UUID?
    /// True only when a round just ended. Inside a round there is no rest.
    var restAfterRound: Bool
    /// Round that just ended (1-based) when `restAfterRound` is true.
    var completedRound: Int?
}

nonisolated enum CircuitRounds {
    /// Rounds = the most planned working sets of any member; 3 when nothing is planned.
    static let defaultRounds = 3

    static func totalRounds(_ members: [CircuitRoundMember]) -> Int {
        let planned = members.compactMap(\.plannedWorkingSets).filter { $0 > 0 }
        let logged = members.map(\.loggedWorkingSets).max() ?? 0
        return max(planned.max() ?? defaultRounds, logged, 1)
    }

    private static func rounds(for member: CircuitRoundMember, total: Int) -> Int {
        member.plannedWorkingSets.flatMap { $0 > 0 ? $0 : nil } ?? total
    }

    private static func isFinished(_ member: CircuitRoundMember, total: Int) -> Bool {
        member.isDone || member.loggedWorkingSets >= rounds(for: member, total: total)
    }

    /// The round he is on: one past the fewest rounds any unfinished member has done.
    static func currentRound(_ members: [CircuitRoundMember]) -> Int {
        let total = totalRounds(members)
        let open = members.filter { !isFinished($0, total: total) }
        guard let fewest = open.map(\.loggedWorkingSets).min() else { return total }
        return min(total, fewest + 1)
    }

    /// Lifts that have their set for the current round.
    static func doneThisRound(_ members: [CircuitRoundMember]) -> Set<UUID> {
        let total = totalRounds(members)
        let round = currentRound(members)
        return Set(members.filter { $0.loggedWorkingSets >= round || isFinished($0, total: total) }.map(\.exerciseID))
    }

    /// After a working set on `exerciseID` (counts already include it).
    static func stepAfterLogging(_ exerciseID: UUID, members: [CircuitRoundMember]) -> CircuitRoundStep {
        let ordered = members.sorted { $0.position < $1.position }
        guard ordered.count >= CircuitAdvance.minimumCount,
              let index = ordered.firstIndex(where: { $0.exerciseID == exerciseID }) else {
            return CircuitRoundStep(next: nil, restAfterRound: true, completedRound: nil)
        }
        let total = totalRounds(ordered)
        let round = ordered[index].loggedWorkingSets
        // Later lifts in this round that still owe a set: go straight there, no rest.
        for member in ordered[(index + 1)...] where !isFinished(member, total: total) && member.loggedWorkingSets < round {
            return CircuitRoundStep(next: member.exerciseID, restAfterRound: false, completedRound: nil)
        }
        // Earlier lifts that skipped this round (he jumped ahead): also no rest.
        for member in ordered[..<index] where !isFinished(member, total: total) && member.loggedWorkingSets < round {
            return CircuitRoundStep(next: member.exerciseID, restAfterRound: false, completedRound: nil)
        }
        // Round over. Rest once, then the first lift that still has rounds left.
        let next = ordered.first { !isFinished($0, total: total) }?.exerciseID
        return CircuitRoundStep(next: next, restAfterRound: true, completedRound: round)
    }
}

// MARK: - Between rounds, end early, start (1.2 gaps c–e)

/// Rest between two rounds of one circuit. Same rest timer and End alert as any lift.
nonisolated struct CircuitBreak: Equatable, Sendable {
    var group: UUID
    var completedRound: Int
    var totalRounds: Int
    /// First lift of the next round.
    var nextExerciseID: UUID?
}

extension CircuitRounds {
    /// Every open lift has done the same round, and more rounds are left.
    static func roundBreak(group: UUID, members: [CircuitRoundMember]) -> CircuitBreak? {
        let ordered = members.sorted { $0.position < $1.position }
        let total = totalRounds(ordered)
        let open = ordered.filter { !isFinishedPublic($0, total: total) }
        guard let first = open.first else { return nil }
        let counts = Set(open.map(\.loggedWorkingSets))
        guard counts.count == 1, let done = counts.first, done >= 1, done < total else { return nil }
        return CircuitBreak(group: group, completedRound: done, totalRounds: total, nextExerciseID: first.exerciseID)
    }

    /// After a relaunch or a long background: the break, if its rest has time left.
    static func resumableBreak(group: UUID, members: [CircuitRoundMember], lastSetAt: Date?,
                               restSeconds: Int, now: Date) -> (break: CircuitBreak, remaining: TimeInterval)? {
        guard let lastSetAt, let found = roundBreak(group: group, members: members) else { return nil }
        let remaining = lastSetAt.addingTimeInterval(TimeInterval(restSeconds)).timeIntervalSince(now)
        guard remaining > 0 else { return nil }
        return (found, remaining)
    }

    /// "End circuit early" marks these lifts done (the ones that still owe sets).
    static func liftsToCloseEarly(_ members: [CircuitRoundMember]) -> [UUID] {
        let total = totalRounds(members)
        return members.sorted { $0.position < $1.position }
            .filter { !isFinishedPublic($0, total: total) }
            .map(\.exerciseID)
    }

    /// Lift "Start Circuit A" opens: first lift that still owes a set this round.
    static func startLift(_ members: [CircuitRoundMember]) -> UUID? {
        let ordered = members.sorted { $0.position < $1.position }
        let total = totalRounds(ordered)
        let round = currentRound(ordered)
        let open = ordered.filter { !isFinishedPublic($0, total: total) }
        return (open.first { $0.loggedWorkingSets < round } ?? open.first)?.exerciseID
    }

    static func startTitle(letter: String, members: [CircuitRoundMember]) -> String {
        guard startLift(members) != nil else { return "Circuit \(letter) done" }
        if members.allSatisfy({ $0.loggedWorkingSets == 0 }) { return "Start Circuit \(letter)" }
        return "Continue Circuit \(letter) · Round \(currentRound(members)) of \(totalRounds(members))"
    }

    static func isFinishedPublic(_ member: CircuitRoundMember, total: Int) -> Bool {
        member.isDone || member.loggedWorkingSets >= (member.plannedWorkingSets.flatMap { $0 > 0 ? $0 : nil } ?? total)
    }
}
