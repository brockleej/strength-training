//
//  VolumeChart.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI
import Charts

struct VolumeChart: View {
    let data: [ChartsViewModel.DataPoint]

    var body: some View {
        if data.isEmpty {
            emptyState
        } else {
            Chart(data) { point in
                BarMark(
                    x: .value("Date", point.date),
                    y: .value("Volume", point.value)
                )
            }
            .foregroundStyle(.tint)
            .chartYAxisLabel("Volume (lbs)")
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
            systemImage: "chart.bar",
            description: Text("Complete workouts to see your volume progression.")
        )
        .frame(height: 250)
    }
}
