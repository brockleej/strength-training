//
//  StrengthScore.swift
//  strength-training
//
//  Progress headline. One slot per primary muscle so BB bench and DB bench
//  do not stack — only the stronger estimated 1RM counts.
//  Each-side sets (the Side tag) count both limbs so a 50 lb DB curl can
//  sit next to a 100 lb barbell curl.
//

import Foundation

nonisolated enum StrengthScore {
    static let ungroupedSlot = "Other"

    static func slot(for primaryMuscle: String) -> String {
        let trimmed = primaryMuscle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? ungroupedSlot : trimmed
    }

    /// Side tag means the logged weight is one limb. Double it for a
    /// two-limb comparison. Name guessing is not used — tag only.
    static func comparableE1RM(weightLbs: Double, reps: Int, isEachSide: Bool) -> Double {
        let load = isEachSide ? weightLbs * 2 : weightLbs
        return E1RM.estimate(weightLbs: load, reps: reps)
    }

    static func absorb(e1rm: Double, muscle: String, into best: inout [String: Double]) {
        guard e1rm > 0 else { return }
        let key = slot(for: muscle)
        if e1rm > (best[key] ?? 0) {
            best[key] = e1rm
        }
    }

    static func total(_ bestByMuscle: [String: Double]) -> Double {
        bestByMuscle.values.reduce(0, +)
    }
}
