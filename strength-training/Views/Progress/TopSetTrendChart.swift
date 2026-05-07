//
//  TopSetTrendChart.swift
//  strength-training
//

import SwiftUI
import Charts

struct TopSetTrendChart: View {
    let data: [ModeChartDataPoint]

    var body: some View {
        Group {
            if data.isEmpty {
                ContentUnavailableView(
                    "No Data Yet",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Complete workouts to see your top set progression.")
                )
                .foregroundStyle(Color.uplift.fgMuted)
                .frame(height: 220)
            } else {
                Chart(data) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(by: .value("Mode", point.mode.rawValue))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
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
