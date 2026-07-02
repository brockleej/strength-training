//
//  PRDetection.swift
//  strength-training
//
//  Pure celebration rule for all-time e1RM PRs (spec §6.2):
//  fire iff there IS prior history, the new set strictly beats the all-time
//  best e1RM, and this exercise hasn't already celebrated this session.
//

import Foundation

enum PRDetection {

    /// The set holding the all-time best e1RM across completed sessions.
    struct PriorBest: Equatable {
        let weight: Double
        let reps: Int
        let e1RM: Double
        let date: Date
    }

    struct Outcome: Equatable {
        let newE1RM: Double
        let weightDelta: Double   // new weight − prior-best set's weight
    }

    static func celebration(
        newWeight: Double,
        newReps: Int,
        priorBest: PriorBest?,
        alreadyCelebrated: Bool
    ) -> Outcome? {
        guard !alreadyCelebrated, let priorBest else { return nil }
        let newE1RM = E1RM.estimate(weightLbs: newWeight, reps: newReps)
        guard newE1RM > priorBest.e1RM else { return nil }
        return Outcome(newE1RM: newE1RM, weightDelta: newWeight - priorBest.weight)
    }
}
