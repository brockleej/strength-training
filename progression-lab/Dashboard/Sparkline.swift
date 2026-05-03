//
//  Sparkline.swift
//  ProgressionLab
//

import SwiftUI
import Charts

/// A small line chart (no axes, no legend) suitable for embedding in a table row.
struct Sparkline: View {
    let points: [(date: Date, value: Double)]
    var width: CGFloat = 80
    var height: CGFloat = 24

    var body: some View {
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.value)
                )
                .foregroundStyle(.primary)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartPlotStyle { plot in
            plot.background(Color.clear)
        }
        .frame(width: width, height: height)
    }
}
