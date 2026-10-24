//
//  FocusFlowView.swift
//  RockLog
//
//  Owns the in-session exercise sequence so Focus can jump to the next lift
//  without popping back to the list. Next skips lifts the user marked done
//  and wraps to the first unfinished lift from the end of the list.
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

    private var hasPrevious: Bool {
        previousIndex() != nil
    }

    /// True when there is another lift not marked done, or a later list position.
    private var hasNext: Bool {
        nextIndex() != nil
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
                    onPrevious: goPrevious,
                    onMarkDoneAndAdvance: markDoneAndAdvance,
                    onJumpTo: jumpTo
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

    /// Finished = user explicitly marked the lift done (not set-count heuristics).
    private func isFinished(_ exercise: Exercise) -> Bool {
        workoutVM.isExerciseDone(for: exercise)
    }

    private func nextIndex() -> Int? {
        FocusNavigation.nextIndex(count: exercises.count, index: index) { isFinished(exercises[$0]) }
    }

    private func previousIndex() -> Int? {
        FocusNavigation.previousIndex(count: exercises.count, index: index) { isFinished(exercises[$0]) }
    }

    private func goNext() {
        guard let i = nextIndex() else { return }
        index = i
    }

    private func goPrevious() {
        guard let i = previousIndex() else { return }
        index = i
    }

    private func jumpTo(_ exerciseID: UUID) {
        guard let i = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        index = i
    }

    private func markDoneAndAdvance() {
        guard exercises.indices.contains(index) else { return }
        workoutVM.markExerciseDone(exercises[index])
        workoutVM.offerFinishIfAllLiftsDone(in: exercises)
        if workoutVM.offerFinishWorkout { return }
        if let i = nextIndex() {
            index = i
        }
    }
}
