//
//  VolumePerSessionChart.swift
//  strength-training
//

import SwiftUI
import Charts

struct VolumePerSessionChart: View {
    let data: [ModeChartDataPoint]

    var body: some View {
        if data.isEmpty {
            ContentUnavailableView(
                "No Data Yet",
                systemImage: "chart.bar",
                description: Text("Complete workouts to see volume per session.")
            )
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
                TrainingMode.highWeightLowReps.rawValue: Color.blue,
                TrainingMode.lowWeightHighReps.rawValue: Color.orange
            ])
            .chartLegend(position: .bottom)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) {
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    AxisGridLine()
                }
            }
            .chartYAxisLabel("Volume (lbs)")
            .frame(height: 220)
        }
    }
}
