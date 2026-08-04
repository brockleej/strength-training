//
//  FocusTargetLogic.swift
//  strength-training
//
//  Derives the Focus steppers' initial values + target dress from the
//  progression suggestion. `.consistent` dresses the WEIGHT stepper,
//  `.improving` dresses the REPS stepper, everything else is neutral.
//

import Foundation

enum FocusTargetLogic {

    struct Prefill: Equatable {
        let weight: Double
        let reps: Int
        let weightDelta: String?   // "+5 lb" → weight stepper target dress
        let repsDelta: String?     // "+1"    → reps stepper target dress
        var isWarmup: Bool = false
        var isEachSide: Bool = false
        var isAssisted: Bool = false
    }

    /// Last set already logged in *this* session for the exercise (supersets).
    struct SessionLastSet: Equatable {
        let weight: Double
        let reps: Int
        let isWarmup: Bool
        let isEachSide: Bool
        let isAssisted: Bool
    }

    /// Derives stepper prefill + target dress.
    /// Priority for weight/reps values:
    /// 1. Last set already logged this session (same exercise) — supersets
    /// 2. Progression suggestion (with optional target dress vs lastBest)
    /// 3. Rolling average / defaults
    ///
    /// Progression snapshots use *effective* load (BW − assist). When
    /// `preferAssistance` is true, convert effective targets into assistance
    /// amounts for the Assist stepper (`max(0, bodyWeight − effective)`).
    static func prefill(
        suggestion: ProgressionSuggestion?,
        recent: RecentAverage?,
        lastBest: (weight: Double, reps: Int)?,
        sessionLast: SessionLastSet? = nil,
        preferAssistance: Bool = false,
        bodyWeightLbs: Double = 0
    ) -> Prefill {
        // Superset / return-to-exercise: keep the recipe you just used.
        // `weight` is already assistance when `isAssisted` (stored that way).
        if let sessionLast {
            return Prefill(
                weight: sessionLast.weight,
                reps: sessionLast.reps,
                weightDelta: nil,
                repsDelta: nil,
                isWarmup: sessionLast.isWarmup,
                isEachSide: sessionLast.isEachSide,
                isAssisted: sessionLast.isAssisted
            )
        }

        guard let suggestion else {
            let rawWeight = recent?.weight ?? 0
            let weight = assistanceIfNeeded(rawWeight, preferAssistance: preferAssistance, bodyWeight: bodyWeightLbs)
            return Prefill(
                weight: weight,
                reps: recent?.reps ?? 10,
                weightDelta: nil,
                repsDelta: nil,
                isAssisted: preferAssistance
            )
        }

        let targetEffective = suggestion.targetWeight
        let lastEffective = lastBest?.weight

        var weightDelta: String?
        var repsDelta: String?

        if preferAssistance, bodyWeightLbs > 0 {
            let targetAssist = max(0, bodyWeightLbs - targetEffective)
            if let lastEff = lastEffective, suggestion.basis == .consistent {
                let lastAssist = max(0, bodyWeightLbs - lastEff)
                // Progress = lower assistance. Show how much assist drops.
                let delta = lastAssist - targetAssist
                if delta > 0 {
                    weightDelta = "−\(StepperLogic.format(delta)) lb"
                }
            }
            if suggestion.basis == .improving, let last = lastBest {
                let delta = suggestion.targetReps - last.reps
                if delta > 0 { repsDelta = "+\(delta)" }
            }
            return Prefill(
                weight: targetAssist,
                reps: suggestion.targetReps,
                weightDelta: weightDelta,
                repsDelta: repsDelta,
                isAssisted: true
            )
        }

        if let lastBest {
            switch suggestion.basis {
            case .consistent:
                let delta = suggestion.targetWeight - lastBest.weight
                if delta > 0 { weightDelta = "+\(StepperLogic.format(delta)) lb" }
            case .improving:
                let delta = suggestion.targetReps - lastBest.reps
                if delta > 0 { repsDelta = "+\(delta)" }
            case .notEnoughData:
                break
            }
        }
        return Prefill(
            weight: suggestion.targetWeight,
            reps: suggestion.targetReps,
            weightDelta: weightDelta,
            repsDelta: repsDelta,
            isAssisted: preferAssistance
        )
    }

    private static func assistanceIfNeeded(
        _ effectiveLoad: Double,
        preferAssistance: Bool,
        bodyWeight: Double
    ) -> Double {
        guard preferAssistance, bodyWeight > 0 else { return effectiveLoad }
        return max(0, bodyWeight - effectiveLoad)
    }

    /// Heaviest *working* set of a session — the dress baseline. Mirrors
    /// `ProgressionService.bestSet`: warmups excluded, ties broken by first
    /// occurrence (`max(by: <)` keeps the running max on equal weights).
    /// Pass `isWarmup: false` when the source is already working-set-only.
    /// Weights should be effective load (for assisted lifts: BW − assist).
    static func lastBest(from sets: [(weight: Double, reps: Int, isWarmup: Bool)]) -> (weight: Double, reps: Int)? {
        sets
            .filter { !$0.isWarmup }
            .max(by: { $0.weight < $1.weight })
            .map { ($0.weight, $0.reps) }
    }
}
