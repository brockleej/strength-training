//
//  VolumePerSessionChart.swift
//  strength-training
//

import SwiftUI
import Charts

struct VolumePerSessionChart: View {
    let data: [ModeChartDataPoint]

    var body: some View {
        Group {
            if data.isEmpty {
                ContentUnavailableView(
                    "No Data Yet",
                    systemImage: "chart.bar",
                    description: Text("Complete workouts to see volume per session.")
                )
                .foregroundStyle(Color.uplift.fgMuted)
                .frame(height: 220)
            } else {
                Chart(data) { point in
                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Volume", point.value)
                    )
                    .foregroundStyle(by: .value("Mode", point.mode.rawValue))
                }
                .chartForegroundStyleScale([
                    TrainingMode.highWeightLowReps.rawValue: Color.uplift.strength,
                    TrainingMode.lowWeightHighReps.rawValue: Color.uplift.endurance
                ])
                .chartLegend(position: .bottom)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(Color.uplift.fgMuted)
                        AxisGridLine()
                            .foregroundStyle(Color.uplift.hairline)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .foregroundStyle(Color.uplift.fgMuted)
                        AxisGridLine()
                            .foregroundStyle(Color.uplift.hairline)
                    }
                }
                .frame(height: 220)
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
