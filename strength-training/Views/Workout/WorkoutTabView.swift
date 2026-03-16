//
//  WorkoutTabView.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI

struct WorkoutTabView: View {
    @Bindable var viewModel: WorkoutViewModel
    var recoveryViewModel: RecoveryViewModel

    var body: some View {
        if viewModel.activeSession != nil {
            ActiveWorkoutView(viewModel: viewModel, recoveryViewModel: recoveryViewModel)
        } else {
            WorkoutDayPickerView(viewModel: viewModel, recoveryViewModel: recoveryViewModel)
        }
    }
}
