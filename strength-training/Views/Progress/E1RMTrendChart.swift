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
                Text("Complete workouts to see your estimated 1RM trend")
                    .font(.uplift.text(13, weight: .medium))
                    .foregroundStyle(Color.uplift.fgDim)
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
            } else {
                Chart {
                    ForEach(data) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("e1RM", point.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.uplift.accent)

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
                    AxisMarks(values: .stride(by: .day, count: 7)) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.uplift.text(11, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                        AxisGridLine()
                    }
                }
                .chartYAxis {
                    AxisMarks {
                        AxisValueLabel()
                            .font(.uplift.text(11, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                    }
                }
                .frame(height: 180)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.uplift.surface1)
        }
    }
}
