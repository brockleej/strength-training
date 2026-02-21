//
//  RepsProgressChart.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI
import Charts

struct RepsProgressChart: View {
    let data: [ChartsViewModel.DataPoint]

    var body: some View {
        if data.isEmpty {
            emptyState
        } else {
            Chart(data) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Reps", point.value)
                )
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Reps", point.value)
                )
            }
            .chartYAxisLabel("Total Reps")
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) {
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    AxisGridLine()
                }
            }
            .frame(height: 250)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Data Yet",
            systemImage: "chart.line.uptrend.xyaxis",
            description: Text("Complete workouts to see your reps progression.")
        )
        .frame(height: 250)
    }
}
