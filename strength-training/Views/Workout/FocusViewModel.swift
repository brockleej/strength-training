//
//  FocusViewModel.swift
//  strength-training
//
//  Per-exercise-visit state for the Focus screen: stepper values, target
//  dress, rest timer, and optional edit of a logged set.
//

import SwiftUI

@Observable
final class FocusViewModel {
    var weight: Double
    var reps: Double                       // UpliftStepper drives Doubles; log as Int
    var isWarmup: Bool = false             // tagged warm-up set (excluded from PRs / progression)
    private(set) var weightDelta: String?  // non-nil → weight stepper target dress
    private(set) var repsDelta: String?    // non-nil → reps stepper target dress

    /// When non-nil, steppers edit this set and the primary button is "Update set".
    private(set) var editingSetID: UUID?

    var isEditingSet: Bool { editingSetID != nil }

    // MARK: - Rest Timer
    var isRestTimerEnabled: Bool
    var targetRestSeconds: Double
    private(set) var restEndDate: Date? = nil

    /// Whether the countdown is currently running
    var isResting: Bool {
        guard let end = restEndDate else { return false }
        return end > .now
    }

    /// Seconds remaining (0 if not resting)
    var remainingRestSeconds: TimeInterval {
        guard let end = restEndDate else { return 0 }
        return max(0, end.timeIntervalSinceNow)
    }

    init(prefill: FocusTargetLogic.Prefill) {
        weight = prefill.weight
        reps = Double(prefill.reps)
        weightDelta = prefill.weightDelta
        repsDelta = prefill.repsDelta
        isRestTimerEnabled = RestTimerPreferences.isEnabled
        targetRestSeconds = Double(RestTimerPreferences.targetSeconds)
    }

    /// Any manual +/− clears BOTH target dresses (spec §6.1).
    func userEdited() {
        weightDelta = nil
        repsDelta = nil
    }

    /// Prefill steppers from a prior session’s set (tap on “Last time”).
    /// Clears edit-selection and target dress so values are ready to log.
    func loadFromHistory(weight: Double, reps: Int, isWarmup: Bool = false) {
        editingSetID = nil
        self.weight = weight
        self.reps = Double(max(1, reps))
        self.isWarmup = isWarmup
        weightDelta = nil
        repsDelta = nil
    }

    /// Mode switch re-prefills values and dress from the new mode's suggestion.
    func apply(prefill: FocusTargetLogic.Prefill) {
        editingSetID = nil
        weight = prefill.weight
        reps = Double(prefill.reps)
        isWarmup = false
        weightDelta = prefill.weightDelta
        repsDelta = prefill.repsDelta
    }

    // MARK: - Edit logged set

    /// Tap a set row: load its values into steppers. Tap again to cancel edit.
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
        weightDelta = nil
        repsDelta = nil
    }

    /// Exit edit mode and restore next-set prefill (cancel / after deleting the edited set).
    func cancelEdit(restore prefill: FocusTargetLogic.Prefill) {
        editingSetID = nil
        apply(prefill: prefill)
        // apply clears editingSetID again — fine
    }

    /// After a successful update: drop selection, keep weight/reps for the next set.
    func clearSelectionAfterSave() {
        editingSetID = nil
        weightDelta = nil
        repsDelta = nil
    }

    func clearEditIfMatching(_ set: SetRecord, restore prefill: FocusTargetLogic.Prefill) {
        guard editingSetID == set.id else { return }
        cancelEdit(restore: prefill)
    }

    // MARK: - Rest timer

    /// Start rest after logging a *new* set (not after updating).
    func setLogged() {
        if isRestTimerEnabled {
            restEndDate = Date.now.addingTimeInterval(targetRestSeconds)
        } else {
            restEndDate = nil
        }
    }

    func toggleRestTimer() {
        isRestTimerEnabled.toggle()
        if !isRestTimerEnabled {
            restEndDate = nil
        }
    }

    func addRestTime(_ seconds: Double = 30) {
        if let current = restEndDate {
            restEndDate = current.addingTimeInterval(seconds)
        } else if isRestTimerEnabled {
            restEndDate = Date.now.addingTimeInterval(seconds)
        }
    }

    func skipRest() {
        restEndDate = nil
    }
}
