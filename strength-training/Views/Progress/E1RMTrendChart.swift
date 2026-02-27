//
//  E1RMTrendChart.swift
//  strength-training
//

import SwiftUI
import Charts

struct E1RMTrendChart: View {
    let data: [AnnotatedChartDataPoint]

    var body: some View {
        if data.isEmpty {
            ContentUnavailableView(
                "No Data Yet",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Complete workouts to see your estimated 1RM trend.")
            )
            .frame(height: 220)
        } else {
            Chart {
                ForEach(data) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("e1RM", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.blue)

                    if point.isPR {
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("e1RM", point.value)
                        )
                        .symbol(.asterisk)
                        .symbolSize(120)
                        .foregroundStyle(.orange)
                        .annotation(position: .top, spacing: 4) {
                            Text("PR")
                                .font(.caption2.bold())
                                .foregroundStyle(.orange)
                        }
                    } else {
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("e1RM", point.value)
                        )
                        .symbolSize(30)
                        .foregroundStyle(.blue)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) {
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    AxisGridLine()
                }
            }
            .chartYAxisLabel("Est. 1RM (lbs)")
            .frame(height: 220)
        }
    }
}
