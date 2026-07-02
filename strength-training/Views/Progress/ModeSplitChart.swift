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
            UpliftSegmentedControl(
                segments: ProgressDashboardViewModel.ModeSplitPeriod.allCases.map {
                    UpliftSegment(id: $0.rawValue, label: $0.rawValue)
                },
                selection: Binding(
                    get: { period.rawValue },
                    set: { period = ProgressDashboardViewModel.ModeSplitPeriod(rawValue: $0) ?? .week }
                )
            )

            if data.isEmpty {
                Text("Complete workouts to see training mode split")
                    .font(.uplift.text(13, weight: .medium))
                    .foregroundStyle(Color.uplift.fgDim)
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
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
                            .font(.uplift.text(11, weight: .bold))
                            .foregroundStyle(Color.uplift.fg)
                    }
                }
                .chartForegroundStyleScale([
                    TrainingMode.highWeightLowReps.rawValue: Color.uplift.accent,
                    TrainingMode.lowWeightHighReps.rawValue: Color.uplift.endurance
                ])
                .chartLegend(.hidden)
                .frame(height: 200)

                HStack(spacing: 16) {
                    ForEach(data) { item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(item.mode == .highWeightLowReps ? Color.uplift.accent : Color.uplift.endurance)
                                .frame(width: 8, height: 8)
                            Text(item.mode.rawValue)
                                .font(.uplift.text(12, weight: .medium))
                                .foregroundStyle(Color.uplift.fgMuted)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.uplift.surface1)
        }
    }
}
