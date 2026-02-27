//
//  TopSetTrendChart.swift
//  strength-training
//

import SwiftUI
import Charts

struct TopSetTrendChart: View {
    let data: [ModeChartDataPoint]

    var body: some View {
        if data.isEmpty {
            ContentUnavailableView(
                "No Data Yet",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Complete workouts to see your top set progression.")
            )
            .frame(height: 220)
        } else {
            Chart(data) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(by: .value("Mode", point.mode.rawValue))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(by: .value("Mode", point.mode.rawValue))
            }
            .chartForegroundStyleScale([
                TrainingMode.highWeightLowReps.rawValue: Color.blue,
                TrainingMode.lowWeightHighReps.rawValue: Color.pink
            ])
            .chartLegend(position: .bottom)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) {
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    AxisGridLine()
                }
            }
            .frame(height: 220)
        }
    }
}
