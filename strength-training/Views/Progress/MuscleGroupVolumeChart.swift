//
//  MuscleGroupVolumeChart.swift
//  strength-training
//

import SwiftUI
import Charts

struct MuscleGroupVolumeChart: View {
    let data: [MuscleGroupVolume]

    var body: some View {
        if data.isEmpty {
            ContentUnavailableView(
                "No Data Yet",
                systemImage: "chart.bar",
                description: Text("Complete workouts to see muscle group volume.")
            )
            .frame(height: 200)
        } else {
            Chart(data) { item in
                BarMark(
                    x: .value("Volume", item.volume),
                    y: .value("Muscle", item.muscleGroup)
                )
                .foregroundStyle(.tint)
                .cornerRadius(4)
            }
            .chartXAxisLabel("Volume (lbs)")
            .frame(height: max(CGFloat(data.count) * 36, 120))
        }
    }
}
