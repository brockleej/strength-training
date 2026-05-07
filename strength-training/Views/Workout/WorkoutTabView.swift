//
//  WorkoutTabView.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI

struct WorkoutTabView: View {
    @Bindable var viewModel: WorkoutViewModel

    /// DEBUG-only flag — flip to `true` to use the new Phase 2 ExerciseListView in place
    /// of the old ActiveWorkoutView. The new flow is unreachable in release builds during
    /// Chunks 1–2 (the entire toggle compiles out via #if DEBUG, avoiding "unused"
    /// warnings on ExerciseListView). Chunk 4 hardcodes the new flow + drops this flag.
    #if DEBUG
    @AppStorage("uplift_phase2_useNewWorkoutFlow") private var useNewFlow: Bool = true
    #endif

    var body: some View {
        Group {
            if viewModel.activeSession != nil {
                #if DEBUG
                if useNewFlow {
                    ExerciseListView(workoutVM: viewModel)
                } else {
                    ActiveWorkoutView(viewModel: viewModel)
                }
                #else
                ActiveWorkoutView(viewModel: viewModel)
                #endif
            } else {
                TodayView(workoutVM: viewModel)
            }
        }
        .sheet(item: $viewModel.sessionPendingEffortRating) { _ in
            EffortRatingView(
                onSave: { rating in viewModel.saveEffortRating(rating) },
                onSkip: { viewModel.skipEffortRating() }
            )
        }
    }
}
