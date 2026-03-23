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
        if viewModel.activeSession != nil {
            ActiveWorkoutView(viewModel: viewModel)
        } else {
            WorkoutDayPickerView(viewModel: viewModel)
        }
    }
}
