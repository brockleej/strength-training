//
//  SameWeightCarry.swift
//  RockLog
//
//  Editing one working set's weight updates only later unlogged working sets
//  that were planned at that same weight. Ramps keep their plan. Warm-ups
//  stay put. One undo restores the unlogged rows this edit changed.
//

import Foundation

nonisolated struct CarrySet: Equatable, Sendable {
    var setNumber: Int
    var planWeight: Double
    var reps: Int
    var isWarmup: Bool
    var isLogged: Bool
    /// The weight the row will open on (plan, suggestion, or a previous carry).
    var displayWeight: Double
}

nonisolated struct CarryUndo: Equatable, Sendable {
    /// Unlogged rows to put back, including a snap this edit caused.
    var previous: [Int: (weight: Double, reps: Int)] {
        stored.mapValues { ($0.weight, $0.reps) }
    }
    var stored: [Int: CarrySnapshot]

    struct CarrySnapshot: Equatable, Sendable {
        var weight: Double
        var reps: Int
    }
}

nonisolated struct CarryResult: Equatable, Sendable {
    var sets: [CarrySet]
    var changedSetNumbers: [Int]
    var undo: CarryUndo?
    /// "Set 2 set to 140" — nil when nothing moved.
    var line: String?
}

nonisolated enum SameWeightCarry {
    struct Edit: Equatable, Sendable {
        var setNumber: Int
        var newWeight: Double
        var isWarmup: Bool
        /// Logging the weight the set already offered.
        var loggedTheOffer: Bool
        /// Reps moved and the weight did not.
        var repsOnly: Bool
    }

    static func apply(sets: [CarrySet], edit: Edit) -> CarryResult {
        guard !edit.loggedTheOffer, !edit.repsOnly, !edit.isWarmup else {
            return CarryResult(sets: sets, changedSetNumbers: [], undo: nil, line: nil)
        }
        guard let source = sets.first(where: { $0.setNumber == edit.setNumber }) else {
            return CarryResult(sets: sets, changedSetNumbers: [], undo: nil, line: nil)
        }
        let plan = source.planWeight
        var next = sets
        var previous: [Int: CarryUndo.CarrySnapshot] = [:]
        var changed: [Int] = []
        for index in next.indices {
            let row = next[index]
            guard row.setNumber > edit.setNumber else { continue }
            guard !row.isLogged, !row.isWarmup else { continue }
            guard same(row.planWeight, plan) else { continue }
            previous[row.setNumber] = CarryUndo.CarrySnapshot(weight: row.displayWeight, reps: row.reps)
            next[index].displayWeight = edit.newWeight
            changed.append(row.setNumber)
        }
        // The edited row keeps the typed weight. Undo does not put it back.
        if let sourceIndex = next.firstIndex(where: { $0.setNumber == edit.setNumber }) {
            next[sourceIndex].displayWeight = edit.newWeight
        }
        let line = announcement(changed: changed, weight: edit.newWeight)
        let undo = changed.isEmpty ? nil : CarryUndo(stored: previous)
        return CarryResult(sets: next, changedSetNumbers: changed, undo: undo, line: line)
    }

    /// Puts the carried rows back. The set he edited stays at the new weight.
    static func undo(sets: [CarrySet], undo: CarryUndo) -> [CarrySet] {
        sets.map { row in
            guard let snap = undo.stored[row.setNumber], !row.isLogged else { return row }
            var copy = row
            copy.displayWeight = snap.weight
            copy.reps = snap.reps
            return copy
        }
    }

    /// Plan weights he did not just overwrite snap onto the stack. Carried copies stay.
    static func snapUnprotected(
        sets: [CarrySet],
        stack: StackDefinition?,
        protected: Set<Int>,
        maxReps: Int? = nil
    ) -> (sets: [CarrySet], snapped: [Int]) {
        guard let stack, stack.isActive else { return (sets, []) }
        var next = sets
        var snapped: [Int] = []
        for index in next.indices {
            let row = next[index]
            guard !row.isLogged, !protected.contains(row.setNumber), !row.isWarmup else { continue }
            let offer = StackMath.snap(
                weightPounds: row.displayWeight,
                reps: row.reps,
                stack: stack,
                maxReps: maxReps
            )
            if abs(offer.weightPounds - row.displayWeight) > 0.2 || offer.reps != row.reps {
                next[index].displayWeight = offer.weightPounds
                next[index].reps = offer.reps
                snapped.append(row.setNumber)
            }
        }
        return (next, snapped)
    }

    static func announcement(changed: [Int], weight: Double) -> String? {
        guard !changed.isEmpty else { return nil }
        let names = changed.map { "Set \($0)" }.joined(separator: ", ")
        let verb = changed.count == 1 ? "set" : "set"
        return "\(names) \(verb) to \(MassMath.formatDisplay(weight))"
    }

    private static func same(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < 0.25
    }
}
