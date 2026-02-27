//
//  ModeSplitChart.swift
//  strength-training
//

import SwiftUI
import Charts

struct ModeSplitChart: View {
    let data: [ModeSplitData]
    @Binding var period: ProgressDashboardViewModel.ModeSplitPeriod

    var body: some View {
        VStack(spacing: 12) {
            Picker("Period", selection: $period) {
                ForEach(ProgressDashboardViewModel.ModeSplitPeriod.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.segmented)

            if data.isEmpty {
                ContentUnavailableView(
                    "No Data Yet",
                    systemImage: "chart.pie",
                    description: Text("Complete workouts to see training mode split.")
                )
                .frame(height: 200)
            } else {
                Chart(data) { item in
                    SectorMark(
                        angle: .value("Volume", item.value),
                        innerRadius: .ratio(0.6),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Mode", item.mode.rawValue))
                    .annotation(position: .overlay) {
                        Text(item.percentage, format: .percent.precision(.fractionLength(0)))
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                    }
                }
                .chartForegroundStyleScale([
                    TrainingMode.highWeightLowReps.rawValue: Color.blue,
                    TrainingMode.lowWeightHighReps.rawValue: Color.pink
                ])
                .chartLegend(position: .bottom)
                .frame(height: 200)
            }
        }
    }
}
