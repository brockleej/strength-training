// strength-training/Views/Workout/FocusStepperFooter.swift
import SwiftUI

/// Sticky footer (above the action bar) containing the two UpliftSteppers for
/// weight + reps. Bumped state (blue + delta overline) lights up when the
/// system has suggested a target and the user hasn't manually edited yet.
struct FocusStepperFooter: View {
    @Bindable var focusVM: FocusViewModel

    var body: some View {
        HStack(spacing: 10) {
            UpliftStepper(
                label: "Weight",
                unit: "lb",
                value: $focusVM.weight,
                step: 5,
                range: 0...1000,
                targetDelta: weightDelta,
                onUserEdit: { focusVM.userEditedWeight() }
            )
            UpliftStepper(
                label: "Reps",
                value: Binding(
                    get: { Double(focusVM.reps) },
                    set: { focusVM.reps = Int($0) }
                ),
                step: 1,
                range: 1...100,
                targetDelta: repsDelta,
                onUserEdit: { focusVM.userEditedReps() }
            )
        }
        .padding(.horizontal, 12)
    }

    private var weightDelta: UpliftStepper.TargetDelta? {
        guard focusVM.isTargetActive, focusVM.weightDelta > 0 else { return nil }
        return .weight(plus: focusVM.weightDelta)
    }

    private var repsDelta: UpliftStepper.TargetDelta? {
        guard focusVM.isTargetActive, focusVM.repsDelta > 0 else { return nil }
        return .reps(plus: focusVM.repsDelta)
    }
}
