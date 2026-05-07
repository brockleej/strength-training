//
//  MuscleGroupVolumeChart.swift
//  strength-training
//

import SwiftUI
import Charts

struct MuscleGroupVolumeChart: View {
    let data: [MuscleGroupVolume]

    var body: some View {
        Group {
            if data.isEmpty {
                ContentUnavailableView(
                    "No Data Yet",
                    systemImage: "chart.bar",
                    description: Text("Complete workouts to see muscle group volume.")
                )
                .foregroundStyle(Color.uplift.fgMuted)
                .frame(height: 200)
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Volume", item.volume),
                        y: .value("Muscle", item.muscleGroup)
                    )
                    .foregroundStyle(Color.uplift.accent)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .foregroundStyle(Color.uplift.fgMuted)
                        AxisGridLine()
                            .foregroundStyle(Color.uplift.hairline)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .foregroundStyle(Color.uplift.fgMuted)
                    }
                }
                .frame(height: max(CGFloat(data.count) * 36, 120))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.uplift.surface1)
        )
    }
}
