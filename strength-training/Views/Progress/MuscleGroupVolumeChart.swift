//
//  MuscleGroupVolumeChart.swift
//  strength-training
//
//  Working-set counts by primary muscle — “what got attention,” not tonnage.
//

import SwiftUI
import Charts

struct MuscleGroupVolumeChart: View {
    let volumes: [MuscleGroupSetCount]

    var body: some View {
        Group {
            if volumes.isEmpty {
                Text("Complete workouts to see which muscles you trained")
                    .font(.uplift.text(13, weight: .medium))
                    .foregroundStyle(Color.uplift.fgDim)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
            } else {
                Chart(volumes) { item in
                    BarMark(
                        x: .value("Sets", item.setCount),
                        y: .value("Muscle", item.muscleGroup)
                    )
                    .foregroundStyle(Color.uplift.accent)
                    .cornerRadius(4)
                    .annotation(position: .trailing, alignment: .leading, spacing: 4) {
                        Text("\(item.setCount)")
                            .font(.uplift.mono(11, weight: .semibold))
                            .foregroundStyle(Color.uplift.fgDim)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) {
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        if volumes.isEmpty { return "No muscle set data" }
        let parts = volumes.prefix(6).map { "\($0.muscleGroup) \($0.setCount) sets" }
        return "Working sets by muscle: " + parts.joined(separator: ", ")
    }
}
