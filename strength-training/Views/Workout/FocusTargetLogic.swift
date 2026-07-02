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
    }

    static func prefill(suggestion: ProgressionSuggestion?, recent: RecentAverage?) -> Prefill {
        guard let suggestion else {
            return Prefill(weight: recent?.weight ?? 0, reps: recent?.reps ?? 10,
                           weightDelta: nil, repsDelta: nil)
        }

        var weightDelta: String?
        var repsDelta: String?
        if let recent {
            switch suggestion.basis {
            case .consistent:
                let delta = suggestion.targetWeight - recent.weight
                if delta > 0 { weightDelta = "+\(StepperLogic.format(delta)) lb" }
            case .improving:
                let delta = suggestion.targetReps - recent.reps
                if delta > 0 { repsDelta = "+\(delta)" }
            case .notEnoughData:
                break
            }
        }
        return Prefill(weight: suggestion.targetWeight, reps: suggestion.targetReps,
                       weightDelta: weightDelta, repsDelta: repsDelta)
    }
}
