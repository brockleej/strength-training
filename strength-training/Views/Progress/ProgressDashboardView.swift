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
            .background(Color.uplift.bgElev)
            .toolbar(.hidden, for: .navigationBar)
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
        VStack(spacing: 0) {
            NavBar(title: "Progress", style: .large(size: 38),
                leading: { CircleButton(icon: "chevron.left") {} },     // no-op for now
                trailing: { CircleButton(icon: "ellipsis") {} }          // no-op for now
            )
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    UpliftRangePicker(selection: $viewModel.selectedTimeRange)
                        .padding(.bottom, 4)
                    headlineBlock
                    volumeChartCard

                    trainingScoresSection
                    volumeBreakdownSection
                    liftProgressionSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.uplift.bgElev)
    }

    private var headlineBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TOTAL VOLUME")
                .font(.uplift.text(11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Color.uplift.fgMuted)
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Num(formattedTotalVolume(viewModel.totalVolumeInRange), size: 42, weight: .bold, color: .uplift.fg)
                Text("lb")
                    .font(.uplift.text(18, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
                Spacer(minLength: 0)
                if let delta = viewModel.totalVolumeDeltaPct {
                    deltaPill(delta)
                }
            }
        }
    }

    private func deltaPill(_ pct: Double) -> some View {
        let positive = pct >= 0
        let color = positive ? Color.uplift.up : Color.uplift.down
        let arrow = positive ? "arrow.up" : "arrow.down"
        // For negative pct, Int(pct.rounded()) already includes the "-" sign.
        // Prepend "+" only on positive deltas.
        let prefix = positive ? "+" : ""
        return HStack(spacing: 3) {
            Image(systemName: arrow).font(.system(size: 11, weight: .semibold))
            Text("\(prefix)\(Int(pct.rounded()))%")
                .font(.uplift.mono(12, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var volumeChartCard: some View {
        VolumeAreaChart(points: viewModel.volumeSeriesPoints)
            .frame(height: 160)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.uplift.surface1))
    }

    private func formattedTotalVolume(_ v: Double) -> String {
        if v >= 1_000_000 { return String(format: "%.1fM", v / 1_000_000) }
        return Int(v).formatted(.number)
    }

    private var trainingScoresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Training scores")
            HStack(spacing: 12) {
                StrengthScoreCard(
                    score: viewModel.strengthScore,
                    trend: viewModel.strengthScoreTrend,
                    delta: viewModel.strengthScoreDelta
                )
                VolumeScoreCard(
                    score: viewModel.volumeScore,
                    trend: viewModel.volumeScoreTrend,
                    delta: viewModel.volumeScoreDelta,
                    filterMode: $viewModel.volumeFilterMode
                )
            }
            PRsThisMonthCard(prs: viewModel.prsThisMonth)
        }
    }

    private var volumeBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Volume breakdown")
            MuscleGroupVolumeChart(data: viewModel.muscleGroupVolumes)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.uplift.surface1))
            ModeSplitChart(
                data: viewModel.modeSplit,
                period: $viewModel.modeSplitPeriod
            )
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.uplift.surface1))
        }
    }

    private var liftProgressionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Lift progression")
            ForEach(viewModel.liftProgressionRows) { row in
                if let exercise = viewModel.exercise(forID: row.id) {
                    NavigationLink {
                        ExerciseDrillDownView(
                            exercise: exercise,
                            modelContext: viewModel.modelContext
                        )
                    } label: {
                        LiftProgressionRow(row: row)
                    }
                    .buttonStyle(.plain)
                } else {
                    LiftProgressionRow(row: row)
                }
            }
        }
    }
}

private struct LiftProgressionRow: View {
    let row: LiftProgressionStats.Row

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(row.exerciseName)
                        .font(.uplift.text(14, weight: .semibold))
                        .kerning(-0.2)
                        .foregroundStyle(Color.uplift.fg)
                    if row.isPR {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.uplift.pr)
                    }
                }
                progressBar
            }
            VStack(alignment: .trailing, spacing: 2) {
                Num("\(formattedWeight(row.topWeightLb))", size: 16, weight: .semibold, color: .uplift.fg)
                deltaLabel
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.uplift.surface1))
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(Color.uplift.fgFaint)
                RoundedRectangle(cornerRadius: 2).fill(Color.uplift.accent)
                    .frame(width: geo.size.width * row.progressPct)
            }
        }
        .frame(height: 4)
    }

    @ViewBuilder
    private var deltaLabel: some View {
        if let d = row.deltaVsLastSessionLb, d != 0 {
            let sign = d > 0 ? "+" : ""
            Text("\(sign)\(formattedWeight(d)) lb")
                .font(.uplift.mono(11, weight: .semibold))
                .foregroundStyle(d > 0 ? Color.uplift.up : Color.uplift.down)
        } else {
            Text("—")
                .font(.uplift.mono(11, weight: .semibold))
                .foregroundStyle(Color.uplift.fgDim)
        }
    }

    private func formattedWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", w)
            : String(format: "%.1f", w)
    }
}

private struct VolumeAreaChart: View {
    let points: [ProgressVolumeStats.VolumePoint]

    var body: some View {
        if points.isEmpty {
            ContentUnavailableView("No volume yet", systemImage: "chart.line.uptrend.xyaxis")
                .foregroundStyle(Color.uplift.fgMuted)
        } else {
            Chart {
                ForEach(points) { p in
                    AreaMark(
                        x: .value("Date", p.date),
                        y: .value("Volume", p.volume)
                    )
                    .foregroundStyle(LinearGradient(
                        colors: [Color.uplift.accent.opacity(0.4), Color.uplift.accent.opacity(0)],
                        startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("Volume", p.volume)
                    )
                    .foregroundStyle(Color.uplift.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }
                if let last = points.last {
                    PointMark(
                        x: .value("Date", last.date),
                        y: .value("Volume", last.volume)
                    )
                    .symbolSize(64)
                    .foregroundStyle(Color.uplift.accent)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel()
                        .foregroundStyle(Color.uplift.fgDim)
                }
            }
            .chartYAxis(.hidden)
        }
    }
}

#Preview {
    ProgressDashboardView()
        .modelContainer(previewContainer)
}
