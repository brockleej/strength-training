//
//  ProgressDashboardView.swift
//  strength-training
//

import SwiftUI
import SwiftData
import Charts

struct ProgressDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ProgressDashboardViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    ProgressDashboardContent(viewModel: vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Progress")
            .onAppear {
                if viewModel == nil {
                    viewModel = ProgressDashboardViewModel(modelContext: modelContext)
                }
            }
        }
    }
}

private struct ProgressDashboardContent: View {
    @Bindable var viewModel: ProgressDashboardViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                rangePicker
                strengthHeadline
                    .padding(.top, 18)
                activityStats
                    .padding(.top, 14)
                SectionHeader("Workouts")
                SessionActivityChart(data: viewModel.sessionChartData)
                BodyMetricsCard()
                    .padding(.top, 8)
                PRsThisMonthCard(prs: viewModel.prsThisMonth)
                    .padding(.top, 8)
                SectionHeader("Sets by muscle")
                MuscleGroupVolumeChart(volumes: viewModel.muscleGroupSetCounts)
                SectionHeader("Strength vs endurance")
                ModeSplitChart(
                    data: viewModel.modeSplit,
                    period: $viewModel.modeSplitPeriod
                )
                SectionHeader("Lift progression")
                liftProgressionSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color.uplift.bgElev)
        .scrollIndicators(.hidden)
    }

    private var rangePicker: some View {
        UpliftSegmentedControl(
            segments: ProgressTimeRange.allCases.map {
                UpliftSegment(id: $0.rawValue, label: $0.rawValue)
            },
            selection: Binding(
                get: { viewModel.selectedTimeRange.rawValue },
                set: { viewModel.selectedTimeRange = ProgressTimeRange(rawValue: $0) ?? .threeMonths }
            )
        )
        .padding(.top, 4)
    }

    /// Overall strength: sum of best estimated 1RMs (clearer than “total volume”).
    private var strengthHeadline: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Strength score")
                .textCase(.uppercase)
                .font(.uplift.text(11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Color.uplift.fgMuted)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Num(TodayStats.formatVolume(viewModel.strengthScore), size: 42)
                Text("lb")
                    .font(.uplift.text(18, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
                Spacer()
                let trend = viewModel.strengthScoreTrend
                HStack(spacing: 3) {
                    Image(systemName: trend.systemImage)
                        .font(.system(size: 11, weight: .bold))
                    Text("\(viewModel.strengthScoreDelta >= 0 ? "+" : "")\(Int(viewModel.strengthScoreDelta.rounded()))")
                        .font(.uplift.mono(12, weight: .semibold))
                }
                .foregroundStyle(trendColor(trend))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(trendColor(trend).opacity(0.16)))
                .accessibilityLabel("Change vs one month ago: \(Int(viewModel.strengthScoreDelta.rounded())) pounds")
            }
            Text("Sum of your best estimated 1-rep max on each lift. Goes up when top sets get stronger.")
                .font(.uplift.text(12, weight: .medium))
                .foregroundStyle(Color.uplift.fgDim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Strength score \(TodayStats.formatVolume(viewModel.strengthScore)) pounds estimated 1 rep max total, change \(Int(viewModel.strengthScoreDelta.rounded())) versus one month ago"
        )
    }

    private var activityStats: some View {
        HStack(spacing: 10) {
            activityStat(
                label: "Workouts",
                value: "\(viewModel.workoutCount)",
                detail: workoutDeltaLabel
            )
            activityStat(
                label: "Working sets",
                value: "\(viewModel.workingSetCount)",
                detail: "In this range"
            )
        }
    }

    private var workoutDeltaLabel: String {
        guard let delta = viewModel.workoutCountDelta else { return "In this range" }
        if delta == 0 { return "Same as prior period" }
        return delta > 0 ? "+\(delta) vs prior period" : "\(delta) vs prior period"
    }

    private func activityStat(label: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .textCase(.uppercase)
                .font(.uplift.text(10, weight: .semibold))
                .tracking(0.3)
                .foregroundStyle(Color.uplift.fgDim)
            Text(value)
                .font(.uplift.mono(28, weight: .bold))
                .foregroundStyle(Color.uplift.fg)
            Text(detail)
                .font(.uplift.text(11, weight: .medium))
                .foregroundStyle(Color.uplift.fgMuted)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.uplift.surface1)
        }
    }

    private func trendColor(_ trend: TrendDirection) -> Color {
        switch trend {
        case .up: .uplift.up
        case .down: .uplift.down
        case .flat, .insufficientData: .uplift.flat
        }
    }

    private var liftProgressionSection: some View {
        let rows = viewModel.liftProgression()
        let grouped = DayTypeRegistry.shared.exerciseHomeDays.compactMap { dayType -> (DayType, [ProgressDashboardViewModel.LiftProgress])? in
            let matching = rows.filter { $0.exercise.belongs(to: dayType) }
            return matching.isEmpty ? nil : (dayType, matching)
        }
        return VStack(alignment: .leading, spacing: 8) {
            if grouped.isEmpty {
                Text("Log workouts to see lift progression")
                    .font(.uplift.text(13, weight: .medium))
                    .foregroundStyle(Color.uplift.fgDim)
                    .padding(.vertical, 8)
            }
            ForEach(grouped, id: \.0) { dayType, lifts in
                Text("\(dayType.rawValue)")
                    .textCase(.uppercase)
                    .font(.uplift.text(11, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(dayType.upliftInk)
                    .padding(.top, 6)
                ForEach(lifts) { lift in
                    NavigationLink {
                        ExerciseDrillDownView(exercise: lift.exercise, modelContext: viewModel.modelContext)
                    } label: {
                        LiftProgressRow(lift: lift)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Lift progression row

private struct LiftProgressRow: View {
    let lift: ProgressDashboardViewModel.LiftProgress

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(lift.exercise.name)
                        .font(.uplift.text(14, weight: .semibold))
                        .kerning(-0.2)
                        .foregroundStyle(Color.uplift.fg)
                    if lift.hasPRInRange {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.uplift.pr)
                            .accessibilityLabel("Personal record in range")
                    }
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.uplift.fgFaint)
                        Capsule().fill(Color.uplift.accent)
                            .frame(width: geo.size.width * progressFraction)
                    }
                }
                .frame(height: 4)
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text(StepperLogic.format(lift.topWeight))
                    .font(.uplift.mono(16, weight: .semibold))
                    .foregroundStyle(Color.uplift.fg)
                if let delta = lift.deltaInRange, delta != 0 {
                    Text("\(delta > 0 ? "+" : "")\(StepperLogic.format(delta)) lb")
                        .font(.uplift.mono(11, weight: .semibold))
                        .foregroundStyle(delta > 0 ? Color.uplift.up : Color.uplift.down)
                } else {
                    Text("—")
                        .font(.uplift.mono(11, weight: .semibold))
                        .foregroundStyle(Color.uplift.fgDim)
                }
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.uplift.fgDim)
                .accessibilityHidden(true)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.uplift.surface1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowAccessibility)
    }

    private var progressFraction: CGFloat {
        guard lift.allTimeBest > 0 else { return 0 }
        return CGFloat(min(1, lift.topWeight / lift.allTimeBest))
    }

    private var rowAccessibility: String {
        var label = "\(lift.exercise.name), top weight \(StepperLogic.format(lift.topWeight)) pounds"
        if let delta = lift.deltaInRange, delta != 0 {
            label += ", \(delta > 0 ? "up" : "down") \(StepperLogic.format(abs(delta))) pounds in range"
        }
        if lift.hasPRInRange { label += ", personal record" }
        return label
    }
}

// MARK: - Session activity chart (how often you trained)

private struct SessionActivityChart: View {
    let data: [ChartDataPoint]

    var body: some View {
        Group {
            if data.isEmpty {
                Text("No completed workouts in this range yet")
                    .font(.uplift.text(13, weight: .medium))
                    .foregroundStyle(Color.uplift.fgDim)
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
            } else {
                Chart(data) { point in
                    BarMark(
                        x: .value("Date", point.date),
                        y: .value("Workouts", point.value)
                    )
                    .foregroundStyle(Color.uplift.accent)
                    .cornerRadius(4)
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                        AxisValueLabel()
                            .font(.uplift.text(11, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) {
                        AxisValueLabel()
                            .font(.uplift.text(11, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                    }
                }
                .frame(height: 140)
            }
        }
        .padding(16)
        .padding(.bottom, 4)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.uplift.surface1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            data.isEmpty
                ? "No workouts in range"
                : "Workouts over time, \(Int(data.reduce(0) { $0 + $1.value })) total in chart"
        )
    }
}
