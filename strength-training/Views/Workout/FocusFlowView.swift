//
//  FocusFlowView.swift
//  strength-training
//
//  Owns the in-session exercise sequence so Focus can jump to the next lift
//  without popping back to the list.
//

import SwiftUI

struct FocusFlowView: View {
    @Bindable var workoutVM: WorkoutViewModel
    let exercises: [Exercise]
    @State private var index: Int

    init(workoutVM: WorkoutViewModel, exercises: [Exercise], startIndex: Int) {
        self.workoutVM = workoutVM
        self.exercises = exercises
        let clamped = exercises.isEmpty ? 0 : min(max(0, startIndex), exercises.count - 1)
        _index = State(initialValue: clamped)
    }

    private var hasNext: Bool {
        index + 1 < exercises.count
    }

    private var hasPrevious: Bool {
        index > 0
    }

    var body: some View {
        Group {
            if exercises.indices.contains(index) {
                FocusView(
                    workoutVM: workoutVM,
                    exercise: exercises[index],
                    liftIndex: index + 1,
                    totalLifts: exercises.count,
                    hasNext: hasNext,
                    hasPrevious: hasPrevious,
                    onNext: goNext,
                    onPrevious: goPrevious
                )
                .id(exercises[index].id)
            } else {
                Color.uplift.bgElev.ignoresSafeArea()
            }
        }
        .onChange(of: exercises.map(\.id)) { _, ids in
            // List reordered / shortened while focused — keep index in range.
            if index >= ids.count {
                index = max(0, ids.count - 1)
            }
        }
    }

    private func goNext() {
        guard hasNext else { return }
        index += 1
    }

    private func goPrevious() {
        guard hasPrevious else { return }
        index -= 1
    }
}
