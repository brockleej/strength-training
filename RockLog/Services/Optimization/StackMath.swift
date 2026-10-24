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
        let lower: Double
        let upper: Double
        if rangeMax > rangeMin {
            lower = rangeMin
            upper = rangeMax
        } else {
            let span = max(target, step) * 2 + step * 4
            lower = step
            upper = max(span, step * 20)
        }
        var values: [Double] = []
        var cursor = lower
        // Guard a runaway loop on a tiny step.
        let limit = 400
        while cursor <= upper + 0.001 && values.count < limit {
            values.append((cursor * 1000).rounded() / 1000)
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

nonisolated enum StackLearning {
    static let candidates: [Double] = [20, 15, 10]

    static func fits(_ weight: Double, step: Double) -> Bool {
        guard step > 0, weight.isFinite else { return false }
        let nearest = (weight / step).rounded() * step
        return abs(weight - nearest) <= 0.5
    }

    /// Largest of 20 / 15 / 10 that fits every corrected weight.
    /// Otherwise the greatest common divisor when it is above 5 lb.
    static func sessionStep(correctedPounds: [Double]) -> Double? {
        let weights = correctedPounds.filter { $0 > 0 && $0.isFinite }
        guard !weights.isEmpty else { return nil }
        for step in candidates where weights.allSatisfy({ fits($0, step: step) }) {
            return step
        }
        let divisor = greatestCommonDivisor(weights)
        if divisor > 5.001 { return divisor }
        return nil
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
    static func learnedStep(
        sessions: [StackSessionSample],
        clearedAt: Date?,
        currentStep: Double?,
        origin: StackOrigin?,
        learningEnabled: Bool
    ) -> (step: Double, sessionIDs: [UUID])? {
        guard learningEnabled, origin != .typed else { return nil }
        let qualifying = sessions
            .filter { sample in
                guard !sample.correctedPounds.isEmpty else { return false }
                if let clearedAt, sample.date <= clearedAt { return false }
                return true
            }
            .sorted { $0.date < $1.date }
        guard qualifying.count >= 3 else { return nil }
        let last = Array(qualifying.suffix(3))
        let ids = last.map(\.id)
        let steps = last.map { sessionStep(correctedPounds: $0.correctedPounds) }
        if let first = steps[0], steps.allSatisfy({ $0 == first }) {
            if let currentStep, abs(currentStep - first) < 0.01 { return nil }
            return (first, ids)
        }
        // No learned step yet: a shared pin across the three sessions still counts,
        // even when each session's own largest step differs (140 / 150 / 160 → 10).
        guard currentStep == nil else { return nil }
        let union = last.flatMap(\.correctedPounds)
        guard let common = sessionStep(correctedPounds: union) else { return nil }
        return (common, ids)
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
