//
//  WorkoutTabView.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI

struct WorkoutTabView: View {
    @Bindable var viewModel: WorkoutViewModel

    var body: some View {
        Group {
            if viewModel.activeSession != nil {
                ExerciseListView(workoutVM: viewModel)
            } else {
                TodayView(workoutVM: viewModel)
            }
        }
        .sheet(item: $viewModel.sessionPendingEffortRating, onDismiss: {
            if let staged = viewModel.pendingSummaryAfterRating {
                viewModel.pendingSummaryAfterRating = nil
                viewModel.sessionPendingSummary = staged
            }
        }) { _ in
            EffortRatingView(
                onSave: { rating in viewModel.saveEffortRating(rating) },
                onSkip: { viewModel.skipEffortRating() }
            )
        }
        .fullScreenCover(item: $viewModel.sessionPendingSummary) { session in
            WorkoutSummaryView(session: session, workoutVM: viewModel)
        }
        .confirmationDialog(
            viewModel.isRevisitingSavedSession ? "Save changes?" : "Finish this workout?",
            isPresented: $viewModel.offerFinishWorkout,
            titleVisibility: .visible
        ) {
            Button(viewModel.isRevisitingSavedSession ? "Save Changes" : "Finish Workout") {
                viewModel.finishSession()
            }
            Button("Keep training", role: .cancel) {}
        } message: {
            Text("Every lift is marked done.")
        }
    }
}
