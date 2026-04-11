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
                ActiveWorkoutView(viewModel: viewModel)
            } else {
                WorkoutDayPickerView(viewModel: viewModel)
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
