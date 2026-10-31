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
