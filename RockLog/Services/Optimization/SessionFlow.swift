//
//  SessionFlow.swift
//  RockLog
//
//  Focus navigation, starting weight, circuits, session order, warm-up, and
//  the per-lift rest seed. Screens call these; they do not own the rules.
//

import Foundation

// MARK: - Previous mirrors Next

nonisolated enum FocusNavigation {
    /// Next unfinished lift, wrapping. If every other lift is done, one step
    /// forward without wrapping, so a finished lift can still be reviewed.
    static func nextIndex(count: Int, index: Int, isDone: (Int) -> Bool) -> Int? {
        guard count > 0, index >= 0, index < count else { return nil }
        if count > 1 {
            for step in 1..<count {
                let i = (index + step) % count
                if !isDone(i) { return i }
            }
        }
        if index + 1 < count { return index + 1 }
        return nil
    }

    /// Same rule, walking backward. The review fallback does not wrap.
    static func previousIndex(count: Int, index: Int, isDone: (Int) -> Bool) -> Int? {
        guard count > 0, index >= 0, index < count else { return nil }
        if count > 1 {
            for step in 1..<count {
                let i = (index - step + count) % count
                if !isDone(i) { return i }
            }
        }
        if index - 1 >= 0 { return index - 1 }
        return nil
    }
}

// MARK: - Starting weight

nonisolated enum StartingWeightChoice: String, CaseIterable, Sendable {
    case lastTime
    case suggested

    var title: String {
        switch self {
        case .lastTime: "Last time"
        case .suggested: "Suggested"
        }
    }
}

nonisolated enum StartingWeightPreferences {
    static let key = "startingWeightChoice"

    static var choice: StartingWeightChoice {
        get { StartingWeightChoice(rawValue: AppDefaults.local.string(forKey: key) ?? "") ?? .lastTime }
        set { AppDefaults.local.set(newValue.rawValue, forKey: key) }
    }
}

nonisolated struct WeightReps: Equatable, Sendable {
    var weight: Double
    var reps: Int
    var isWarmup: Bool = false
}

nonisolated struct OpeningLine: Equatable, Sendable {
    var last: WeightReps?
    var suggested: WeightReps?
    /// The travel gym has no history of its own yet, so last time is Home's.
    var lastAtHome: Bool = false

    func text(unit: MassUnit = .pounds) -> String {
        var parts: [String] = []
        if let last {
            let place = lastAtHome ? " at Home" : ""
            parts.append("Last time \(Self.pair(last, unit: unit))\(place)")
        }
        if let suggested {
            parts.append("Suggested \(Self.pair(suggested, unit: unit))")
        }
        return parts.joined(separator: " · ")
    }

    private static func pair(_ value: WeightReps, unit: MassUnit) -> String {
        let shown = MassMath.display(fromPounds: value.weight, unit: unit)
        return "\(MassMath.formatDisplay(shown))×\(value.reps)"
    }
}

nonisolated enum StartingWeight {
    struct Input: Sendable {
        var setNumber: Int
        var loggedCount: Int
        var plan: WeightReps?
        /// Same set number from the last completed session.
        var lastTimeSameSet: WeightReps?
        /// Best working set when last time had fewer sets.
        var lastTimeBest: WeightReps?
        var suggestion: WeightReps?
        var sessionLast: WeightReps?
        /// True when Next set default is “Last set”. False is “Last session”.
        var repeatLastSet: Bool
        var starting: StartingWeightChoice
        var stack: StackDefinition?
        var lastAtHome: Bool = false
        var emptyWeight: Double = 0
        var emptyReps: Int = 10
    }

    struct Result: Equatable, Sendable {
        var weight: Double
        var reps: Int
        /// Warm-up only when this set's own plan says so. Never copied from the set just logged.
        var isWarmup: Bool
        var line: OpeningLine
    }

    static func resolve(_ input: Input) -> Result {
        let suggested = snapped(input.suggestion, stack: input.stack)
        let last = input.lastTimeSameSet ?? (input.loggedCount == 0 ? input.lastTimeBest : nil)
        let line = OpeningLine(last: last ?? input.lastTimeSameSet, suggested: suggested, lastAtHome: input.lastAtHome)

        if let plan = input.plan {
            let snappedPlan = snapped(plan, stack: input.stack) ?? plan
            return Result(
                weight: snappedPlan.weight,
                reps: snappedPlan.reps,
                isWarmup: plan.isWarmup,
                line: line
            )
        }

        let opensFirst = input.setNumber <= 1 || input.loggedCount == 0
        let chosen: WeightReps?
        if opensFirst {
            switch input.starting {
            case .lastTime:
                chosen = input.lastTimeSameSet ?? input.lastTimeBest ?? input.suggestion
            case .suggested:
                chosen = input.suggestion
            }
        } else {
            if input.repeatLastSet {
                chosen = input.sessionLast ?? input.suggestion
            } else {
                chosen = input.lastTimeSameSet ?? input.lastTimeBest ?? input.sessionLast ?? input.suggestion
            }
        }
        let snappedChoice = snapped(chosen, stack: input.stack) ?? chosen
        return Result(
            weight: snappedChoice?.weight ?? input.emptyWeight,
            reps: snappedChoice?.reps ?? input.emptyReps,
            isWarmup: false,
            line: line
        )
    }

    private static func snapped(_ pair: WeightReps?, stack: StackDefinition?) -> WeightReps? {
        guard let pair else { return nil }
        guard let stack, stack.isActive else { return pair }
        let offer = StackMath.snap(weightPounds: pair.weight, reps: pair.reps, stack: stack)
        return WeightReps(weight: offer.weightPounds, reps: offer.reps, isWarmup: pair.isWarmup)
    }
}

// MARK: - Circuits

nonisolated struct CircuitMember: Equatable, Sendable, Identifiable {
    var exerciseID: UUID
    var position: Int
    var isDone: Bool
    var loggedWorkingSets: Int
    var plannedWorkingCount: Int?

    var id: UUID { exerciseID }

    var isFinished: Bool {
        if isDone { return true }
        if let plannedWorkingCount, loggedWorkingSets >= plannedWorkingCount { return true }
        return false
    }
}

nonisolated enum CircuitAdvance {
    static let minimumCount = 2
    static let maximumCount = 4

    static func canCreate(count: Int) -> Bool {
        count >= minimumCount && count <= maximumCount
    }

    /// Next unfinished member after a working set. Nil when the group is done
    /// or this lift is not in it. Warm-up logs do not call this.
    static func next(after currentID: UUID, members: [CircuitMember]) -> UUID? {
        let ordered = members.sorted { $0.position < $1.position }
        guard let index = ordered.firstIndex(where: { $0.exerciseID == currentID }) else { return nil }
        let count = ordered.count
        guard count >= minimumCount else { return nil }
        for step in 1..<count {
            let member = ordered[(index + step) % count]
            if !member.isFinished { return member.exerciseID }
        }
        return nil
    }
}

nonisolated struct CircuitSeat: Equatable, Sendable {
    var recordID: UUID
    var exerciseID: UUID
    var groupID: UUID?
    var position: Int
}

nonisolated enum CircuitMembership {
    /// Drop one lift. A group left with fewer than two members is cleared.
    static func removing(exerciseID: UUID, from seats: [CircuitSeat]) -> [CircuitSeat] {
        let groups = Set(seats.filter { $0.exerciseID == exerciseID }.compactMap(\.groupID))
        var next = seats.filter { $0.exerciseID != exerciseID }
        for group in groups {
            next = dissolve(group, in: next)
        }
        return next
    }

    /// A group that is no longer a contiguous block loses the member that left.
    /// A pair that is split is cleared. A group that stays together is unchanged.
    static func afterDrag(orderedExerciseIDs: [UUID], seats: [CircuitSeat]) -> [CircuitSeat] {
        var next = seats
        for group in Set(seats.compactMap(\.groupID)) {
            let members = next.filter { $0.groupID == group }.map(\.exerciseID)
            guard members.count >= 2 else { continue }
            if isContiguous(members, in: orderedExerciseIDs) { continue }
            if members.count == 2 {
                next = clear(group, in: next)
                continue
            }
            let ordered = members.compactMap { id in orderedExerciseIDs.firstIndex(of: id).map { (id, $0) } }
                .sorted { $0.1 < $1.1 }
            var departed: UUID?
            for candidate in ordered {
                let rest = members.filter { $0 != candidate.0 }
                if isContiguous(rest, in: orderedExerciseIDs) {
                    departed = candidate.0
                    break
                }
            }
            if let departed {
                next = next.map { seat in
                    guard seat.exerciseID == departed else { return seat }
                    var copy = seat
                    copy.groupID = nil
                    copy.position = 0
                    return copy
                }
                next = dissolve(group, in: next)
            } else {
                next = clear(group, in: next)
            }
        }
        return next
    }

    private static func isContiguous(_ members: [UUID], in order: [UUID]) -> Bool {
        let indexes = members.compactMap { order.firstIndex(of: $0) }
        guard indexes.count == members.count, let low = indexes.min(), let high = indexes.max() else { return false }
        return high - low + 1 == indexes.count
    }

    private static func dissolve(_ group: UUID, in seats: [CircuitSeat]) -> [CircuitSeat] {
        guard seats.filter({ $0.groupID == group }).count < 2 else { return seats }
        return clear(group, in: seats)
    }

    private static func clear(_ group: UUID, in seats: [CircuitSeat]) -> [CircuitSeat] {
        seats.map { seat in
            guard seat.groupID == group else { return seat }
            var copy = seat
            copy.groupID = nil
            copy.position = 0
            return copy
        }
    }
}

// MARK: - Session order

nonisolated enum SessionOrder {
    /// New sort indexes for the visible lifts. Library order is not an input.
    static func sortOrders(orderedIDs: [UUID]) -> [UUID: Int] {
        var result: [UUID: Int] = [:]
        for (index, id) in orderedIDs.enumerated() {
            result[id] = index
        }
        return result
    }
}

// MARK: - Warm-up

nonisolated enum WarmupPolicy {
    /// The tag does not travel onto the next set. A planned warm-up slot may
    /// still open warm, because that flag belongs to the slot, not the tag.
    static func nextTag(planSaysWarmup: Bool) -> Bool {
        planSaysWarmup
    }

    /// Two offers under the first working weight: about half, then about
    /// three quarters. Snapped to the stack when there is one, otherwise 5 lb.
    /// Nothing is logged until the lifter taps an offer.
    static func ramp(workingWeight: Double, stack: StackDefinition?) -> [WeightReps] {
        guard workingWeight > 0 else { return [] }
        return [0.5, 0.75].compactMap { fraction in
            let raw = workingWeight * fraction
            let weight: Double
            if let stack, stack.isActive {
                weight = StackMath.snap(weightPounds: raw, reps: 5, stack: stack).weightPounds
            } else {
                weight = MassMath.snap(raw, quantum: 5)
            }
            guard weight > 0.5, weight + 0.01 < workingWeight else { return nil }
            return WeightReps(weight: weight, reps: 5, isWarmup: true)
        }
    }
}

// MARK: - Rest seed and learning

nonisolated enum RestSeed {
    static func seconds(name: String, muscles: String, settingsFallback: Int) -> Int {
        let haystack = folded(name + " " + muscles)
        if containsAny(haystack, ["squat", "deadlift", "lunge", "leg press"]) { return 180 }
        if containsAny(haystack, ["bench", "row", "overhead", "pull-up", "pullup", "chin-up", "dip"]) { return 120 }
        if containsAny(haystack, ["curl", "raise", "extension", "fly", "flye"]) { return 90 }
        return settingsFallback > 0 ? settingsFallback : 180
    }

    /// Case, accents, and unicode hyphens fold onto the English seed words.
    private static func folded(_ text: String) -> String {
        let hyphens = ["\u{2010}", "\u{2011}", "\u{2013}", "\u{2014}"]
        let plain = hyphens.reduce(text) { $0.replacingOccurrences(of: $1, with: "-") }
        return plain.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    private static func containsAny(_ haystack: String, _ needles: [String]) -> Bool {
        needles.contains { haystack.contains($0) }
    }
}

nonisolated enum RestLearning {
    static let minimumSamples = 8
    static let ignoreBelow = 10
    static let ignoreAbove = 600
    static let minimumShift = 15

    /// Median of the kept samples, when it is far enough from the saved default
    /// to be worth one ask. Nil means stay quiet.
    static func offer(
        samples: [Int],
        savedDefault: Int,
        enabled: Bool,
        alreadyOfferedThisSession: Bool
    ) -> Int? {
        guard enabled, !alreadyOfferedThisSession else { return nil }
        let kept = samples.filter { $0 >= ignoreBelow && $0 <= ignoreAbove }.sorted()
        guard kept.count >= minimumSamples else { return nil }
        let median = kept[kept.count / 2]
        guard abs(median - savedDefault) >= minimumShift else { return nil }
        return median
    }
}
