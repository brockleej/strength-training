//
//  TimeRangePicker.swift
//  strength-training
//

import SwiftUI

struct TimeRangePicker: View {
    @Binding var selection: ProgressTimeRange

    var body: some View {
        Picker("Time Range", selection: $selection) {
            ForEach(ProgressTimeRange.allCases) {
                Text($0.rawValue).tag($0)
            }
        }
        .pickerStyle(.segmented)
    }
}
