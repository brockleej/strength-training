//
//  TrainingModePickerView.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI

struct TrainingModePickerView: View {
    @Binding var selectedMode: TrainingMode

    var body: some View {
        Picker("Mode", selection: $selectedMode) {
            ForEach(TrainingMode.allCases) { mode in
                Label(mode.rawValue, systemImage: mode.systemImage)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }
}
