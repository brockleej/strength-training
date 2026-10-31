//
//  FocusViewModel.swift
//  RockLog
//
//  Per-exercise-visit state for the Focus screen: stepper values, target
//  dress, weight step size, and optional edit of a logged set.
//  Rest timer lives on WorkoutViewModel so supersets keep the countdown.
//

import SwiftUI

@Observable
final class FocusViewModel {
    /// Weight step sizes for the active unit. 5 / 1 / 0.5 lb, or 2.5 / 1 / 0.5 kg.
    static var weightSteps: [Double] { MassUnitPreferences.unit.stepperSteps }

    var weight: Double
    var reps: Double                       // UpliftStepper drives Doubles; log as Int
    var isWarmup: Bool = false             // tagged warm-up set (excluded from PRs / progression)
    var isEachSide: Bool = false           // reps performed on each side (volume ×2)
    /// Weight field is assistance (machine “−100 lb”), not bar load.
    var isAssisted: Bool = false
    /// Current weight stepper increment (5 / 1 / 0.5). Persists while Focus is alive.
    var weightStep: Double = MassUnitPreferences.unit.defaultStepperStep
    private(set) var weightDelta: String?  // non-nil → weight stepper target dress
    private(set) var repsDelta: String?    // non-nil → reps stepper target dress

    /// When non-nil, steppers edit this set and the primary button is "Update set".
    private(set) var editingSetID: UUID?
    /// Repeat delivery of the same set inside this window is ignored.
    /// It does not cancel edit. Cancel edit is the only way off.
    static let repeatToggleSuppression: TimeInterval = 0.3
    private var lastToggleAt = Date.distantPast
    private var lastToggleID: UUID?
    /// Last time vs suggestion. Stepper edits do not rewrite it.
    var openingLineText: String = ""
    /// Weight the steppers opened on. Logging this exact number is not a carry.
    var offeredWeight: Double = 0

    var isEditingSet: Bool { editingSetID != nil }

    /// - prefersAssist: exercise-level default when no session last set (e.g. pull-ups).
    init(prefill: FocusTargetLogic.Prefill, prefersAssist: Bool = false) {
        weight = prefill.weight
        reps = Double(prefill.reps)
        weightDelta = prefill.weightDelta
        repsDelta = prefill.repsDelta
        isWarmup = prefill.isWarmup
        isEachSide = prefill.isEachSide
        isAssisted = prefill.isAssisted || prefersAssist
        offeredWeight = prefill.weight
        weightStep = MassUnitPreferences.unit.defaultStepperStep
    }

    /// Keep the typed number in the new unit and snap the increment onto that unit's grid.
    func adoptUnit(_ unit: MassUnit, from old: MassUnit) {
        if old != unit {
            let pounds = MassMath.pounds(fromDisplay: weight, unit: old)
            weight = MassMath.display(fromPounds: pounds, unit: unit)
            let offeredPounds = MassMath.pounds(fromDisplay: offeredWeight, unit: old)
            offeredWeight = MassMath.display(fromPounds: offeredPounds, unit: unit)
        }
        if !unit.stepperSteps.contains(weightStep) {
            weightStep = unit.defaultStepperStep
        }
    }

    /// Any manual +/− clears BOTH target dresses (spec §6.1).
    func userEdited() {
        weightDelta = nil
        repsDelta = nil
    }

    /// Cycle through the unit steps (lb 5 → 1 → 0.5, kg 5 → 2.5 → 1 → 0.5). Snaps current weight onto the new grid when possible.
    func cycleWeightStep() {
        let steps = MassUnitPreferences.unit.stepperSteps
        guard let idx = steps.firstIndex(of: weightStep) else {
            weightStep = steps[0]
            return
        }
        weightStep = steps[(idx + 1) % steps.count]
        let step = weightStep
        weight = (weight / step).rounded() * step
        userEdited()
    }

    /// Prefill steppers from a prior session’s set (tap on “Last time”).
    func loadFromHistory(
        weight: Double,
        reps: Int,
        isWarmup: Bool = false,
        isEachSide: Bool = false,
        isAssisted: Bool = false
    ) {
        editingSetID = nil
        self.weight = weight
        self.reps = Double(max(1, reps))
        self.isWarmup = isWarmup
        self.isEachSide = isEachSide
        self.isAssisted = isAssisted
        weightDelta = nil
        repsDelta = nil
    }

    /// Mode switch re-prefills values and dress from the new mode's suggestion.
    func apply(prefill: FocusTargetLogic.Prefill, openingLine: String? = nil) {
        editingSetID = nil
        weight = prefill.weight
        reps = Double(prefill.reps)
        isWarmup = WarmupPolicy.nextTag(planSaysWarmup: prefill.isWarmup)
        isEachSide = prefill.isEachSide
        isAssisted = prefill.isAssisted
        weightDelta = prefill.weightDelta
        repsDelta = prefill.repsDelta
        offeredWeight = prefill.weight
        if let openingLine { openingLineText = openingLine }
    }

    // MARK: - Edit logged set

    /// Puts this set into edit. A second call stays in edit and never cancels.
    /// A repeat inside `repeatToggleSuppression` is dropped. Leaving edit is
    /// `cancelEdit`, from the Cancel edit control.
    func enterEdit(set: SetRecord) {
        let now = Date()
        if lastToggleID == set.id, now.timeIntervalSince(lastToggleAt) < Self.repeatToggleSuppression {
            return
        }
        lastToggleAt = now
        lastToggleID = set.id
        beginEdit(set: set)
    }

    /// Drops edit when that set is no longer logged. Covers removals that
    /// never go through the row's onDelete.
    func clearEditIfSetNoLongerListed(_ ids: some Sequence<UUID>, restore prefill: FocusTargetLogic.Prefill) {
        guard let editingSetID else { return }
        guard !ids.contains(editingSetID) else { return }
        cancelEdit(restore: prefill)
    }

    func beginEdit(set: SetRecord) {
        editingSetID = set.id
        weight = set.weightLbs
        reps = Double(set.reps)
        isWarmup = set.isWarmup
        isEachSide = set.isEachSide
        isAssisted = set.isAssisted
        weightDelta = nil
        repsDelta = nil
    }

    func cancelEdit(restore prefill: FocusTargetLogic.Prefill) {
        apply(prefill: prefill)
    }

    func clearSelectionAfterSave() {
        editingSetID = nil
        weightDelta = nil
        repsDelta = nil
    }

    func clearEditIfMatching(_ set: SetRecord, restore prefill: FocusTargetLogic.Prefill) {
        guard editingSetID == set.id else { return }
        cancelEdit(restore: prefill)
    }

    /// After logging a new set: clear target dress; keep weight/reps/flags for supersets.
    func setLogged() {
        weightDelta = nil
        repsDelta = nil
        // The tag belongs to the set just logged. It does not travel forward.
        isWarmup = false
    }
}

/// Log versus Update on the focus footer. Editing hides the log identifier.
enum FocusLogControl {
    static func identifier(isEditing: Bool) -> String {
        isEditing ? AccessibilityID.focusUpdateSet : AccessibilityID.focusLogSet
    }
}
