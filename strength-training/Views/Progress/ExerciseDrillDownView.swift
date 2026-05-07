//
//  ExerciseDrillDownView.swift
//  strength-training
//

import SwiftUI
import SwiftData

struct ExerciseDrillDownView: View {
    let exercise: Exercise
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ExerciseDrillDownViewModel?

    var body: some View {
        VStack(spacing: 0) {
            NavBar(
                title: exercise.name,
                style: .compact,
                leading: { CircleButton(icon: "chevron.left") { dismiss() } },
                trailing: { CircleButton(icon: "ellipsis") {} }     // overflow menu — Phase 7 candidate
            )
            if let vm = viewModel {
                ExerciseDrillDownContent(viewModel: vm)
            } else {
                ProgressView().frame(maxHeight: .infinity)
            }
        }
        .background(Color.uplift.bgElev)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if viewModel == nil {
                viewModel = ExerciseDrillDownViewModel(
                    modelContext: modelContext,
                    exercise: exercise
                )
            }
        }
    }
}

private struct ExerciseDrillDownContent: View {
    @Bindable var viewModel: ExerciseDrillDownViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                heroCard
                personalBestCard
                miniChartCard
                recentSessionsSection

                // Range picker scopes the long-form trend charts below.
                UpliftRangePicker(selection: $viewModel.selectedTimeRange)
                    .padding(.top, 12)

                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader("Estimated 1RM")
                    E1RMTrendChart(data: viewModel.e1rmTrendData)
                }

                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader("Volume per session")
                    VolumePerSessionChart(data: viewModel.volumePerSessionData)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Hero card

    private var heroCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(dayWash)
                    .frame(width: 80, height: 80)
                Image(systemName: viewModel.exercise.dayType.systemImage)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(dayInk)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrowLabel)
                    .font(.uplift.text(11, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(dayInk)
                Text(viewModel.exercise.name)
                    .font(.uplift.display(22, weight: .bold))
                    .kerning(-0.5)
                    .foregroundStyle(Color.uplift.fg)
                if !viewModel.exercise.muscleGroup.isEmpty {
                    HStack(spacing: 6) {
                        muscleTag(viewModel.exercise.muscleGroup, muted: false)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.uplift.surface1))
    }

    private var dayInk: Color {
        switch viewModel.exercise.dayType {
        case .arms: .uplift.armsInk
        case .legs: .uplift.legsInk
        case .fullBody: .uplift.fullInk
        }
    }
    private var dayWash: Color {
        switch viewModel.exercise.dayType {
        case .arms: .uplift.armsWash
        case .legs: .uplift.legsWash
        case .fullBody: .uplift.fullWash
        }
    }

    private var eyebrowLabel: String {
        // Compose "{DayType uppercased} day · {custom or built-in}"
        let custom = viewModel.exercise.isCustom ? "Custom" : "Built-in"
        return "\(viewModel.exercise.dayType.rawValue.uppercased()) DAY · \(custom.uppercased())"
    }

    private func muscleTag(_ text: String, muted: Bool) -> some View {
        Text(text)
            .font(.uplift.text(11, weight: .semibold))
            .kerning(-0.1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(muted ? Color.uplift.surface2 : dayWash)
            .foregroundStyle(muted ? Color.uplift.fgMuted : dayInk)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    // MARK: - Personal Best card

    @ViewBuilder
    private var personalBestCard: some View {
        if let best = viewModel.personalBest {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.uplift.pr.opacity(0.16)).frame(width: 40, height: 40)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.uplift.pr)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("PERSONAL BEST")
                        .font(.uplift.text(11, weight: .semibold))
                        .tracking(0.3)
                        .foregroundStyle(Color.uplift.fgMuted)
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Num("\(formattedWeight(best.weight)) × \(best.reps)", size: 22, weight: .bold, color: .uplift.fg)
                        Text("· \(relativeBestLabel(best))")
                            .font(.uplift.text(12, weight: .medium))
                            .foregroundStyle(Color.uplift.fgMuted)
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("1RM EST.")
                        .font(.uplift.text(11, weight: .semibold))
                        .tracking(0.3)
                        .foregroundStyle(Color.uplift.fgMuted)
                    Num("\(formattedWeight(best.e1RM))", size: 18, weight: .semibold, color: .uplift.fg)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.uplift.surface1))
        }
    }

    private func relativeBestLabel(_ best: ExerciseDrillDownStats.Best) -> String {
        if best.isToday { return "today" }
        return ExerciseDrillDownStats.relativeLabel(for: best.sessionDate, now: .now, calendar: .current)
    }

    private func formattedWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", w)
            : String(format: "%.1f", w)
    }

    // MARK: - Mini chart card (Task 9)

    private var miniChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top set")
                    .font(.uplift.text(13, weight: .semibold))
                    .foregroundStyle(Color.uplift.fg)
                Spacer()
                Text("Last 10 sessions")
                    .font(.uplift.text(12, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
            }
            // Metric selector folded in (Weight / Reps / Est. 1RM)
            miniMetricSelector
            MiniBarChart(bars: viewModel.lastTenBars, metric: viewModel.topSetMetric)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.uplift.surface1))
    }

    private var miniMetricSelector: some View {
        HStack(spacing: 4) {
            ForEach(ExerciseDrillDownViewModel.TopSetMetric.allCases) { metric in
                let active = (metric == viewModel.topSetMetric)
                Button { viewModel.topSetMetric = metric } label: {
                    Text(metric.rawValue)
                        .font(.uplift.text(11, weight: .semibold))
                        .foregroundStyle(active ? Color.uplift.fg : Color.uplift.fgMuted)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(active ? Color.uplift.surface3 : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.uplift.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Recent sessions (Task 9)

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Recent sessions")
            VStack(spacing: 6) {
                ForEach(viewModel.recentSessionRows) { row in
                    recentRow(row)
                }
            }
        }
    }

    private func recentRow(_ row: ExerciseDrillDownStats.RecentRow) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(row.dateLabel)
                        .font(.uplift.text(14, weight: .semibold))
                        .kerning(-0.1)
                        .foregroundStyle(Color.uplift.fg)
                    if row.isPR {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.uplift.pr)
                    }
                }
                Text("\(row.setsCount) × \(row.topReps)")
                    .font(.uplift.text(12, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
            }
            Spacer(minLength: 0)
            Num("\(formattedWeight(row.topWeightLb)) × \(row.topReps)", size: 14, weight: .semibold, color: .uplift.fg)
        }
        .padding(13)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.uplift.surface1))
    }

}

// MARK: - MiniBarChart (Task 9)

private struct MiniBarChart: View {
    let bars: [ExerciseDrillDownStats.Bar]
    /// Selected metric used to pick the bar's height value. The chart
    /// auto-scales between min/max of that metric.
    let metric: ExerciseDrillDownViewModel.TopSetMetric

    private var values: [Double] {
        bars.map { bar in
            switch metric {
            case .weight: return bar.weight
            case .reps:   return Double(bar.reps)
            case .e1RM:   return ProgressionService.e1RM(weight: bar.weight, reps: bar.reps)
            }
        }
    }
    private var minVal: Double { values.min() ?? 0 }
    private var maxVal: Double { values.max() ?? 1 }

    var body: some View {
        if bars.isEmpty {
            ContentUnavailableView("No history yet", systemImage: "chart.bar")
                .foregroundStyle(Color.uplift.fgMuted)
                .frame(height: 90)
        } else {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(bars.enumerated()), id: \.element.id) { idx, item in
                    let v = values[idx]
                    let h = max(0.05, (v - minVal) / max(0.001, maxVal - minVal))
                    barView(for: item, heightFraction: h)
                }
            }
            .frame(height: 90)
        }
    }

    /// Renamed from `bar(...)` to avoid shadowing the ForEach closure parameter.
    private func barView(for item: ExerciseDrillDownStats.Bar, heightFraction: Double) -> some View {
        let color: Color
        if item.isLatest        { color = .uplift.pr }
        else if item.isPR       { color = .uplift.accent }
        else                    { color = .uplift.fgFaint }
        return GeometryReader { geo in
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color)
                    .frame(height: max(2, geo.size.height * heightFraction))
                    .opacity(item.isLatest ? 1.0 : 0.85)
            }
        }
    }
}
