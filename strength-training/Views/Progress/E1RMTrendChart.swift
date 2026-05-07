//
//  E1RMTrendChart.swift
//  strength-training
//

import SwiftUI
import Charts

struct E1RMTrendChart: View {
    let data: [AnnotatedChartDataPoint]

    var body: some View {
        Group {
            if data.isEmpty {
                ContentUnavailableView(
                    "No Data Yet",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Complete workouts to see your estimated 1RM trend.")
                )
                .foregroundStyle(Color.uplift.fgMuted)
                .frame(height: 220)
            } else {
                Chart {
                    ForEach(data) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("e1RM", point.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.uplift.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                        if point.isPR {
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("e1RM", point.value)
                            )
                            .symbol(.asterisk)
                            .symbolSize(120)
                            .foregroundStyle(Color.uplift.pr)
                            .annotation(position: .top, spacing: 4) {
                                Text("PR")
                                    .font(.uplift.text(10, weight: .bold))
                                    .foregroundStyle(Color.uplift.pr)
                            }
                        } else {
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("e1RM", point.value)
                            )
                            .symbolSize(30)
                            .foregroundStyle(Color.uplift.accent)
                        }
                    }
                }
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
