//
//  FocusViewModel.swift
//  strength-training
//
//  Per-exercise-visit state for the Focus screen: stepper values, target
//  dress, weight step size, and optional edit of a logged set.
//  Rest timer lives on WorkoutViewModel so supersets keep the countdown.
//

import SwiftUI

@Observable
final class FocusViewModel {
    /// Weight step sizes for gym plates / fractional plates.
    static let weightSteps: [Double] = [5, 1, 0.5]

    var weight: Double
    var reps: Double                       // UpliftStepper drives Doubles; log as Int
    var isWarmup: Bool = false             // tagged warm-up set (excluded from PRs / progression)
    var isEachSide: Bool = false           // reps performed on each side (volume ×2)
    /// Weight field is assistance (machine “−100 lb”), not bar load.
    var isAssisted: Bool = false
    /// Current weight stepper increment (5 / 1 / 0.5). Persists while Focus is alive.
    var weightStep: Double = 5
    private(set) var weightDelta: String?  // non-nil → weight stepper target dress
    private(set) var repsDelta: String?    // non-nil → reps stepper target dress

    /// When non-nil, steppers edit this set and the primary button is "Update set".
    private(set) var editingSetID: UUID?

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
    }

    /// Any manual +/− clears BOTH target dresses (spec §6.1).
    func userEdited() {
        weightDelta = nil
        repsDelta = nil
    }

    /// Cycle 5 → 1 → 0.5 → 5. Snaps current weight onto the new grid when possible.
    func cycleWeightStep() {
        let steps = Self.weightSteps
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
    func apply(prefill: FocusTargetLogic.Prefill) {
        editingSetID = nil
        weight = prefill.weight
        reps = Double(prefill.reps)
        isWarmup = prefill.isWarmup
        isEachSide = prefill.isEachSide
        isAssisted = prefill.isAssisted
        weightDelta = prefill.weightDelta
        repsDelta = prefill.repsDelta
    }

    // MARK: - Edit logged set

    func toggleEdit(set: SetRecord, prefillIfCancel: FocusTargetLogic.Prefill) {
        if editingSetID == set.id {
            cancelEdit(restore: prefillIfCancel)
            return
        }
        beginEdit(set: set)
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
        editingSetID = nil
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
        if !isWarmup {
            isWarmup = false
        }
        // Assist + each-side stay on for consecutive sets of the same pattern.
    }
}
