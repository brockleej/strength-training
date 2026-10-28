//
//  PRDetection.swift
//  RockLog
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
        alreadyCelebrated: Bool,
        unit: MassUnit = MassUnitPreferences.unit
    ) -> Outcome? {
        guard !alreadyCelebrated, let priorBest else { return nil }
        // Compare the weights the lifter sees. A kg round-trip can sit ~0.4 lb
        // off the stored number and still display as the same load.
        let shownNew = MassMath.storedPounds(
            fromEntered: MassMath.display(fromPounds: newWeight, unit: unit),
            unit: unit
        )
        let shownPrior = MassMath.storedPounds(
            fromEntered: MassMath.display(fromPounds: priorBest.weight, unit: unit),
            unit: unit
        )
        let newE1RM = E1RM.estimate(weightLbs: shownNew, reps: newReps)
        let priorE1RM = E1RM.estimate(weightLbs: shownPrior, reps: priorBest.reps)
        // Strict > by design: a tie doesn't re-fire the fireworks, even though
        // the History/Today PR badges use >= (a tying set still DISPLAYS as PR).
        guard newE1RM > priorE1RM else { return nil }
        return Outcome(newE1RM: newE1RM, weightDelta: shownNew - shownPrior)
    }
}
