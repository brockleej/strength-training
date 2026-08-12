//
//  E1RMTrendChart.swift
//  strength-training
//
//  Primary per-lift progress line: one point per session, PR markers.
//

import SwiftUI
import Charts

struct E1RMTrendChart: View {
    let data: [AnnotatedChartDataPoint]
    /// Axis / empty-state wording (e.g. "e1RM" or "Top weight").
    var valueLabel: String = "e1RM"
    var unitSuffix: String = "lb"
    var emptyMessage: String = "Log working sets to see progress over time"

    var body: some View {
        Group {
            if data.isEmpty {
                Text(emptyMessage)
                    .font(.uplift.text(13, weight: .medium))
                    .foregroundStyle(Color.uplift.fgDim)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
            } else {
                Chart {
                    ForEach(data) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value(valueLabel, point.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.uplift.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value(valueLabel, point.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.uplift.accent.opacity(0.28), Color.uplift.accent.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        if point.isPR {
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value(valueLabel, point.value)
                            )
                            .symbolSize(90)
                            .foregroundStyle(Color.uplift.pr)
                            .annotation(position: .top, spacing: 6) {
                                Text("PR")
                                    .font(.uplift.text(10, weight: .bold))
                                    .foregroundStyle(Color.uplift.pr)
                            }
                        } else {
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value(valueLabel, point.value)
                            )
                            .symbolSize(40)
                            .foregroundStyle(Color.uplift.accent)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) {
                        AxisGridLine().foregroundStyle(Color.uplift.hairline)
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.uplift.text(11, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                        AxisGridLine().foregroundStyle(Color.uplift.hairline)
                        AxisValueLabel()
                            .font(.uplift.text(11, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                    }
                }
                .frame(height: 200)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        guard let last = data.last else { return emptyMessage }
        let prs = data.filter(\.isPR).count
        return "\(valueLabel) trend, latest \(Int(last.value.rounded())) \(unitSuffix), \(prs) personal record\(prs == 1 ? "" : "s") marked"
    }
}
