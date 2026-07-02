//
//  MuscleGroupVolumeChart.swift
//  strength-training
//

import SwiftUI
import Charts

struct MuscleGroupVolumeChart: View {
    let volumes: [MuscleGroupVolume]

    var body: some View {
        Group {
            if volumes.isEmpty {
                Text("Complete workouts to see muscle group volume")
                    .font(.uplift.text(13, weight: .medium))
                    .foregroundStyle(Color.uplift.fgDim)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
            } else {
                Chart(volumes) { item in
                    BarMark(
                        x: .value("Volume", item.volume),
                        y: .value("Muscle", item.muscleGroup)
                    )
                    .foregroundStyle(Color.uplift.accent)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks {
                        AxisValueLabel()
                            .font(.uplift.text(11, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                    }
                }
                .chartYAxis {
                    AxisMarks {
                        AxisValueLabel()
                            .font(.uplift.text(11, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                    }
                }
                .frame(height: max(CGFloat(volumes.count) * 36, 120))
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.uplift.surface1)
        }
    }
}
