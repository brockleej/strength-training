//
//  FocusViewModel.swift
//  strength-training
//
//  Per-exercise-visit state for the Focus screen: stepper values, target
//  dress, and the rest-timer anchor. Recreated on each Focus entry.
//

import SwiftUI

@Observable
final class FocusViewModel {
    var weight: Double
    var reps: Double                       // UpliftStepper drives Doubles; log as Int
    private(set) var weightDelta: String?  // non-nil → weight stepper target dress
    private(set) var repsDelta: String?    // non-nil → reps stepper target dress
    /// Rest-chip anchor: Focus entry, then reset on every logged set.
    private(set) var restAnchor: Date = .now

    init(prefill: FocusTargetLogic.Prefill) {
        weight = prefill.weight
        reps = Double(prefill.reps)
        weightDelta = prefill.weightDelta
        repsDelta = prefill.repsDelta
    }

    /// Any manual +/− clears BOTH target dresses (spec §6.1).
    func userEdited() {
        weightDelta = nil
        repsDelta = nil
    }

    /// Mode switch re-prefills values and dress from the new mode's suggestion.
    func apply(prefill: FocusTargetLogic.Prefill) {
        weight = prefill.weight
        reps = Double(prefill.reps)
        weightDelta = prefill.weightDelta
        repsDelta = prefill.repsDelta
    }

    func setLogged() {
        restAnchor = .now
    }
}
