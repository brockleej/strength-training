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
            periodPicker

            if data.isEmpty {
                ContentUnavailableView(
                    "No Data Yet",
                    systemImage: "chart.pie",
                    description: Text("Complete workouts to see training mode split.")
                )
                .foregroundStyle(Color.uplift.fgMuted)
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
                            .font(.uplift.mono(11, weight: .bold))
                            .foregroundStyle(item.mode == .highWeightLowReps ? Color.uplift.bg : Color.uplift.fg)
                    }
                }
                .chartForegroundStyleScale([
                    TrainingMode.highWeightLowReps.rawValue: Color.uplift.strength,
                    TrainingMode.lowWeightHighReps.rawValue: Color.uplift.endurance
                ])
                .chartLegend(position: .bottom)
                .frame(height: 200)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.uplift.surface1)
        )
    }

    private var periodPicker: some View {
        HStack(spacing: 4) {
            ForEach(ProgressDashboardViewModel.ModeSplitPeriod.allCases, id: \.self) { p in
                periodSegment(p)
            }
        }
        .padding(4)
        .background(Color.uplift.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func periodSegment(_ p: ProgressDashboardViewModel.ModeSplitPeriod) -> some View {
        let active = (p == period)
        return Button {
            period = p
        } label: {
            Text(p.rawValue)
                .font(.uplift.text(12, weight: .semibold))
                .foregroundStyle(active ? Color.uplift.fg : Color.uplift.fgMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    active ? Color.uplift.surface3 : Color.clear,
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }
}
