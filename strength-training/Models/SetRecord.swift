//
//  SetRecord.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import Foundation
import SwiftData

@Model
final class SetRecord {
    var id: UUID = UUID()
    var setNumber: Int = 0
    /// Loaded weight, or **assistance** amount when `isAssisted` (machine “−100 lb”).
    var weightLbs: Double = 0
    var reps: Int = 0
    var isWarmup: Bool = false
    /// Reps are performed on each side (e.g. 20 left + 20 right). Volume counts both sides.
    var isEachSide: Bool = false
    /// Assisted bodyweight movement: `weightLbs` is assistance, not bar load.
    var isAssisted: Bool = false
    var completedAt: Date = Date.now
    /// Imported plan target, not yet logged. Default false so existing sets stay trained work.
    var isTarget: Bool = false

    var exerciseRecord: ExerciseRecord?

    init(
        setNumber: Int,
        weightLbs: Double,
        reps: Int,
        isWarmup: Bool = false,
        isEachSide: Bool = false,
        isAssisted: Bool = false,
        isTarget: Bool = false
    ) {
        self.id = UUID()
        self.setNumber = setNumber
        self.weightLbs = weightLbs
        self.reps = reps
        self.isWarmup = isWarmup
        self.isEachSide = isEachSide
        self.isAssisted = isAssisted
        self.completedAt = .now
        self.isTarget = isTarget
    }

    /// Load used for tonnage / e1RM. Assisted: max(0, bodyWeight − assistance). Never negative.
    func effectiveLoadLbs(bodyWeight: Double = BodyWeightPreferences.pounds) -> Double {
        if isAssisted {
            guard bodyWeight > 0 else { return 0 }
            return max(0, bodyWeight - weightLbs)
        }
        return max(0, weightLbs)
    }

    /// Effective load × reps × (2 if each side). Assisted with no body weight set contributes 0.
    var volumeContribution: Double {
        effectiveLoadLbs() * Double(reps) * (isEachSide ? 2 : 1)
    }

    /// Working-set e1RM from effective load (assistance never counts as bar weight).
    var estimatedE1RM: Double {
        E1RM.estimate(weightLbs: effectiveLoadLbs(), reps: reps)
    }

    /// Display string for weight column, e.g. "225" or "−100".
    var weightDisplay: String {
        if isAssisted {
            return "−\(StepperLogic.format(weightLbs))"
        }
        return StepperLogic.format(weightLbs)
    }
}
