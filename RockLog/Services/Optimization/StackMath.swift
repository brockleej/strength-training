//
//  StackMath.swift
//  RockLog
//
//  Machine pins, Epley rep adjustment, and the step learned from corrections.
//  A missing profile means the normal 5 lb / 2.5 kg snap — callers do that.
//

import Foundation

nonisolated enum StackPolicy: String, Codable, CaseIterable, Sendable {
    case nearest
    case down
    case up
}

nonisolated enum StackOrigin: String, Codable, Sendable {
    case learned
    case typed
}

nonisolated struct StackDefinition: Equatable, Sendable {
    var step: Double?
    /// Pounds (or the pin unit) left over after whole steps. 10 lb with offset 5 is 145, 155, 165.
    var offset: Double = 0
    var pins: [Double]
    var pinUnit: MassUnit
    var addOns: [Double]
    /// Inclusive range for a fixed step. 0...0 means "generate around the target".
    var rangeMin: Double
    var rangeMax: Double
    var policy: StackPolicy
    var origin: StackOrigin?
    var learningEnabled: Bool
    var clearedAt: Date?
    var learnedSessionIDs: [UUID]

    static let empty = StackDefinition(
        step: nil,
        offset: 0,
        pins: [],
        pinUnit: .pounds,
        addOns: [],
        rangeMin: 0,
        rangeMax: 0,
        policy: .nearest,
        origin: nil,
        learningEnabled: true,
        clearedAt: nil,
        learnedSessionIDs: []
    )

    var isActive: Bool { step != nil || !pins.isEmpty }

    /// Fixed step, or the explicit pin list, in the pin unit.
    func basePins(around target: Double = 0) -> [Double] {
        if !pins.isEmpty {
            return pins.sorted()
        }
        guard let step, step > 0 else { return [] }
        let offset = Self.normalizedOffset(self.offset, step: step)
        let lower: Double
        let upper: Double
        if rangeMax > rangeMin {
            lower = rangeMin
            upper = rangeMax
        } else {
            let span = max(target, step) * 2 + step * 4
            lower = 0
            upper = max(span, step * 20)
        }
        var cursor = offset
        if cursor + 0.001 < lower {
            let jumps = ((lower - offset) / step).rounded(.up)
            cursor = offset + jumps * step
        }
        var values: [Double] = []
        // Guard a runaway loop on a tiny step.
        let limit = 400
        while cursor <= upper + 0.001 && values.count < limit {
            if cursor > 0.001 {
                values.append((cursor * 1000).rounded() / 1000)
            }
            cursor += step
        }
        return values
    }

    /// A pin, or a pin plus one add-on. Several magnets at once are not offered.
    func availableWeights(around target: Double = 0) -> [Double] {
        let bases = basePins(around: target)
        var set = Set<Double>()
        for pin in bases {
            set.insert(pin)
            for add in addOns where add > 0 {
                set.insert(pin + add)
            }
        }
        return set.sorted()
    }

    static func normalizedOffset(_ offset: Double, step: Double) -> Double {
        guard step > 0, offset.isFinite else { return 0 }
        var value = offset.truncatingRemainder(dividingBy: step)
        if value < 0 { value += step }
        if value > step - 0.001 { value = 0 }
        return value
    }
}

nonisolated struct StackOffer: Equatable, Sendable {
    var weightPounds: Double
    var reps: Int
}

nonisolated enum StackMath {
    /// Available pin weights in pounds, for comparison with stored sets.
    static func availablePounds(_ stack: StackDefinition, aroundPounds: Double = 0) -> [Double] {
        let around = MassMath.exactDisplay(fromPounds: aroundPounds, unit: stack.pinUnit)
        return stack.availableWeights(around: around).map {
            MassMath.pounds(fromDisplay: $0, unit: stack.pinUnit)
        }
    }

    /// Nearest / down / up. A nearest tie rounds down so the lifter is not handed more than they asked.
    static func select(target: Double, available: [Double], policy: StackPolicy) -> Double? {
        let pins = available.filter { $0.isFinite }.sorted()
        guard !pins.isEmpty else { return nil }
        switch policy {
        case .down:
            return pins.last(where: { $0 <= target + 0.001 }) ?? pins.first
        case .up:
            return pins.first(where: { $0 >= target - 0.001 }) ?? pins.last
        case .nearest:
            return pins.min { lhs, rhs in
                let dl = abs(lhs - target)
                let dr = abs(rhs - target)
                if abs(dl - dr) > 0.001 { return dl < dr }
                return lhs < rhs
            }
        }
    }

    /// Move reps so the Epley estimate stays as close as it can to the original.
    /// `maxReps` is the strength cap when the caller has one.
    static func adjustedReps(
        originalWeight: Double,
        originalReps: Int,
        newWeight: Double,
        maxReps: Int? = nil
    ) -> Int {
        guard originalWeight > 0, newWeight > 0, originalReps > 0 else { return max(1, originalReps) }
        let estimate = originalWeight * (1 + Double(originalReps) / 30)
        let ceiling = min(30, max(1, maxReps ?? 30))
        let ideal = min(max(30 * (estimate / newWeight - 1), 1), Double(ceiling))
        var rounded = Int(ideal.rounded())
        rounded = max(1, rounded)
        if let maxReps { rounded = min(maxReps, rounded) }
        let neighbor = ideal >= Double(rounded) ? rounded + 1 : rounded - 1
        guard neighbor >= 1 else { return rounded }
        let cappedNeighbor = min(ceiling, maxReps.map { min($0, neighbor) } ?? neighbor)
        guard cappedNeighbor != rounded, cappedNeighbor >= 1 else { return rounded }
        let roundedDistance = abs(epley(newWeight, rounded) - estimate)
        let neighborDistance = abs(epley(newWeight, cappedNeighbor) - estimate)
        if neighborDistance + 0.001 < roundedDistance { return cappedNeighbor }
        return rounded
    }

    static func epley(_ weight: Double, _ reps: Int) -> Double {
        weight * (1 + Double(reps) / 30)
    }

    /// Snap a prescribed pair onto the stack. The weight he just typed is not passed here.
    static func snap(
        weightPounds: Double,
        reps: Int,
        stack: StackDefinition,
        maxReps: Int? = nil
    ) -> StackOffer {
        guard stack.isActive else {
            return StackOffer(weightPounds: weightPounds, reps: reps)
        }
        // Choose the pin in its own unit, then convert that pin to pounds.
        let target = MassMath.exactDisplay(fromPounds: weightPounds, unit: stack.pinUnit)
        let available = stack.availableWeights(around: target)
        guard let chosenDisplay = select(target: target, available: available, policy: stack.policy) else {
            return StackOffer(weightPounds: weightPounds, reps: reps)
        }
        let chosen = MassMath.pounds(fromDisplay: chosenDisplay, unit: stack.pinUnit)
        if MassMath.sameStoredPounds(chosen, weightPounds) {
            return StackOffer(weightPounds: weightPounds, reps: reps)
        }
        let newReps = adjustedReps(
            originalWeight: weightPounds,
            originalReps: reps,
            newWeight: chosen,
            maxReps: maxReps
        )
        return StackOffer(weightPounds: chosen, reps: newReps)
    }
}

// MARK: - Learning

nonisolated struct StackSessionSample: Equatable, Sendable {
    var id: UUID
    var date: Date
    /// Corrected working weights, in pounds. Warm-ups are not included.
    var correctedPounds: [Double]
}

nonisolated struct LearnedProfile: Equatable, Sendable {
    var step: Double
    var offset: Double
    var sessionIDs: [UUID]
}

nonisolated enum StackLearning {
    static let candidates: [Double] = [20, 15, 10]
    /// A weight is on the grid when it is within half a pound of offset + n × step.
    static let tolerance = 0.5

    static func fits(_ weight: Double, step: Double, offset: Double = 0) -> Bool {
        distance(weight, step: step, offset: offset) <= tolerance + 0.001
    }

    static func distance(_ weight: Double, step: Double, offset: Double) -> Double {
        guard step > 0, weight.isFinite, offset.isFinite else { return .infinity }
        let shifted = weight - StackDefinition.normalizedOffset(offset, step: step)
        let nearest = (shifted / step).rounded() * step
        return abs(shifted - nearest)
    }

    /// Largest of 20 / 15 / 10 whose pooled weights share one remainder.
    /// Otherwise the greatest common divisor when it is above 5 lb.
    static func pair(correctedPounds: [Double]) -> (step: Double, offset: Double)? {
        let weights = correctedPounds.filter { $0 > 0 && $0.isFinite }
        guard !weights.isEmpty else { return nil }
        for step in candidates {
            if let offset = sharedOffset(weights, step: step) {
                return (step, offset)
            }
        }
        let divisor = greatestCommonDivisor(weights)
        guard divisor > 5.001, let offset = sharedOffset(weights, step: divisor) else { return nil }
        return (divisor, offset)
    }

    /// Kept so older call sites can ask for the step alone.
    static func sessionStep(correctedPounds: [Double]) -> Double? {
        pair(correctedPounds: correctedPounds)?.step
    }

    static func sharedOffset(_ weights: [Double], step: Double) -> Double? {
        guard step > 0 else { return nil }
        var candidates = weights.map { positiveRemainder($0, step: step) }
        candidates.append(0)
        var best: (offset: Double, worst: Double)?
        for candidate in candidates {
            let worst = weights.map { distance($0, step: step, offset: candidate) }.max() ?? .infinity
            guard worst <= tolerance + 0.001 else { continue }
            if let best {
                if worst > best.worst + 0.001 { continue }
                if abs(worst - best.worst) <= 0.001 && candidate >= best.offset - 0.001 { continue }
            }
            best = (candidate, worst)
        }
        return best?.offset
    }

    static func positiveRemainder(_ weight: Double, step: Double) -> Double {
        guard step > 0 else { return 0 }
        var rem = weight - (weight / step).rounded(.down) * step
        if rem < 0 { rem += step }
        if abs(rem - step) <= 0.001 || rem > step - tolerance { return 0 }
        return rem
    }

    static func greatestCommonDivisor(_ weights: [Double]) -> Double {
        let scale = 10
        var acc = 0
        for weight in weights {
            let scaled = Int((weight * Double(scale)).rounded())
            acc = acc == 0 ? abs(scaled) : gcd(acc, abs(scaled))
        }
        return Double(acc) / Double(scale)
    }

    /// What to store after this session. Nil means "leave the profile alone".
    /// A learned pair stays until three newer qualifying sessions, pooled, no longer fit it.
    static func learnedStep(
        sessions: [StackSessionSample],
        clearedAt: Date?,
        currentStep: Double?,
        currentOffset: Double = 0,
        origin: StackOrigin?,
        learningEnabled: Bool,
        learnedSessionIDs: [UUID] = []
    ) -> LearnedProfile? {
        guard learningEnabled, origin != .typed else { return nil }
        let qualifying = sessions
            .filter { sample in
                guard !sample.correctedPounds.isEmpty else { return false }
                if let clearedAt, sample.date <= clearedAt { return false }
                return true
            }
            .sorted { $0.date < $1.date }
        guard qualifying.count >= 3 else { return nil }

        let window: [StackSessionSample]
        if origin == .learned, currentStep != nil {
            let known = Set(learnedSessionIDs)
            let anchor = qualifying.filter { known.contains($0.id) }.map(\.date).max()
            let newer = qualifying.filter { sample in
                if known.contains(sample.id) { return false }
                if let anchor { return sample.date > anchor }
                return true
            }
            let source = known.isEmpty ? qualifying : newer
            guard source.count >= 3 else { return nil }
            window = Array(source.suffix(3))
            let pool = window.flatMap(\.correctedPounds)
            if fitsPool(pool, step: currentStep ?? 0, offset: currentOffset) { return nil }
        } else {
            window = Array(qualifying.suffix(3))
        }

        let pool = window.flatMap(\.correctedPounds)
        guard let found = pair(correctedPounds: pool) else { return nil }
        if let currentStep, origin == .learned,
           abs(currentStep - found.step) < 0.01,
           abs(currentOffset - found.offset) < 0.01 {
            return nil
        }
        return LearnedProfile(step: found.step, offset: found.offset, sessionIDs: window.map(\.id))
    }

    static func fitsPool(_ weights: [Double], step: Double, offset: Double) -> Bool {
        let kept = weights.filter { $0 > 0 && $0.isFinite }
        guard !kept.isEmpty else { return false }
        return kept.allSatisfy { fits($0, step: step, offset: offset) }
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        var a = a, b = b
        while b != 0 { (a, b) = (b, a % b) }
        return a
    }
}

// MARK: - Gym fallback

nonisolated struct StackCandidate: Equatable, Sendable {
    var id: UUID
    var gymID: UUID
    var exerciseID: UUID
    var updatedAt: Date?
    var stack: StackDefinition
}

nonisolated enum StackConflict {
    /// A typed step beats a learned one, even when the learned row is newer.
    /// Two rows of the same kind: the later `updatedAt` wins. A tie keeps the
    /// greater id so both phones choose the same row. The other row stays.
    static func winner(_ rows: [StackCandidate]) -> StackCandidate? {
        rows.reduce(nil as StackCandidate?) { best, row in
            guard let best else { return row }
            return prefer(row, over: best) ? row : best
        }
    }

    static func prefer(_ row: StackCandidate, over other: StackCandidate) -> Bool {
        let rank = originRank(row.stack.origin)
        let otherRank = originRank(other.stack.origin)
        if rank != otherRank { return rank > otherRank }
        let time = row.updatedAt ?? .distantPast
        let otherTime = other.updatedAt ?? .distantPast
        if time != otherTime { return time > otherTime }
        return row.id.uuidString > other.id.uuidString
    }

    private static func originRank(_ origin: StackOrigin?) -> Int {
        switch origin {
        case .typed: 2
        case .learned: 1
        case nil: 0
        }
    }
}

nonisolated enum GymStackLookup {
    /// Current gym, then Home, then no profile (the caller uses the 5 lb snap).
    /// Several rows for one gym and lift collapse through `StackConflict`.
    static func resolve(
        exerciseID: UUID,
        gymID: UUID,
        homeGymID: UUID?,
        profiles: [StackCandidate]
    ) -> StackDefinition? {
        func chosen(_ gym: UUID) -> StackDefinition? {
            let rows = profiles.filter { $0.gymID == gym && $0.exerciseID == exerciseID && $0.stack.isActive }
            return StackConflict.winner(rows)?.stack
        }
        if let current = chosen(gymID) { return current }
        if let homeGymID, homeGymID != gymID, let home = chosen(homeGymID) { return home }
        return nil
    }
}

// MARK: - Same-gym history

nonisolated enum GymHistory {
    struct Row: Equatable, Sendable {
        var id: UUID
        /// Nil counts as Home. Sessions from before the gym field are Home.
        var gymID: UUID?
    }

    struct Selection: Equatable, Sendable {
        var ids: Set<UUID>
        /// True when a travel gym still has fewer than two sessions, so the line uses Home.
        var usedHome: Bool
    }

    static func select(rows: [Row], activeGymID: UUID, homeGymID: UUID) -> Selection {
        func isHome(_ id: UUID?) -> Bool { id == nil || id == homeGymID }
        if activeGymID == homeGymID {
            return Selection(ids: Set(rows.filter { isHome($0.gymID) }.map(\.id)), usedHome: false)
        }
        let travel = rows.filter { $0.gymID == activeGymID }
        if travel.count >= 2 {
            return Selection(ids: Set(travel.map(\.id)), usedHome: false)
        }
        return Selection(ids: Set(rows.filter { isHome($0.gymID) }.map(\.id)), usedHome: true)
    }
}
