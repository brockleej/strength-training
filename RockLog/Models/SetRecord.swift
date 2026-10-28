//
//  SetRecord.swift
//  RockLog
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
    /// The weight this working set was going to open on, stored only when he logged something else.
    var offeredWeightLbs: Double? = nil
    /// "" means legacy: assist when `isAssisted` is set, otherwise bar.
    var loadModeRaw: String = ""
    /// Body weight used for assist / added on the day he logged. 0 means "look it up".
    var bodyWeightUsedLbs: Double = 0
    var plannedRestSeconds: Int = 0
    var actualRestSeconds: Int = 0
    /// "lb" or "kg". Empty means a legacy set stored only as pounds.
    var enteredUnitRaw: String = ""
    /// The number typed or stepped in `enteredUnitRaw`.
    var enteredValue: Double = 0

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

    var resolvedLoadMode: LoadMode {
        LoadMode(stored: loadModeRaw, isAssisted: isAssisted)
    }

    /// Load used for tonnage / e1RM. Assist and added use body weight. Never negative.
    func effectiveLoadLbs(bodyWeight: Double = BodyWeightPreferences.pounds) -> Double {
        let weight = bodyWeightUsedLbs > 0 ? bodyWeightUsedLbs : bodyWeight
        return LoadMath.effective(mode: resolvedLoadMode, entered: weightLbs, bodyWeight: weight)
    }

    /// Effective load × reps × (2 if each side). Assisted with no body weight set contributes 0.
    var volumeContribution: Double {
        effectiveLoadLbs() * Double(reps) * (isEachSide ? 2 : 1)
    }

    /// Working-set e1RM from effective load (assistance never counts as bar weight).
    var estimatedE1RM: Double {
        E1RM.estimate(weightLbs: effectiveLoadLbs(), reps: reps)
    }

    var enteredUnit: MassUnit? { MassUnit(rawValue: enteredUnitRaw) }

    /// Canonical pounds plus the original entry. Matching units show the entry.
    func displayValue(in unit: MassUnit = MassUnitPreferences.unit) -> Double {
        MassMath.shown(
            enteredValue: enteredUnit == nil ? nil : enteredValue,
            enteredUnit: enteredUnit,
            canonicalPounds: weightLbs,
            display: unit
        )
    }

    /// Remember the number the lifter used and the pound equivalent.
    func stampEntered(_ value: Double, unit: MassUnit) {
        enteredUnitRaw = unit.rawValue
        enteredValue = value
        weightLbs = MassMath.pounds(fromDisplay: value, unit: unit)
    }

    /// Display string for weight column, e.g. "225" or "−100".
    var weightDisplay: String {
        let shown = StepperLogic.format(displayValue())
        if isAssisted {
            return "−\(shown)"
        }
        return shown
    }
}
