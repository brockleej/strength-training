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

                    // Task 7 will add: scoreCardsRow, prsCard, muscleGroupCard,
                    // modeSplitCard, liftProgressionSection, exerciseListSection.

                    // LEGACY: replaced in Task 7
                    legacyBlock
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

    // LEGACY: replaced in Task 7
    private var legacyBlock: some View {
        VStack(spacing: 20) {
            // Headline metric cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
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

            // Balance & Coverage
            GroupBox("Muscle Group Volume") {
                MuscleGroupVolumeChart(data: viewModel.muscleGroupVolumes)
            }

            GroupBox("Training Mode Split") {
                ModeSplitChart(
                    data: viewModel.modeSplit,
                    period: $viewModel.modeSplitPeriod
                )
            }

            // Exercise drill-down list
            ExerciseListSection(
                groupedExercises: viewModel.exercisesGroupedByDayType(),
                modelContext: viewModel.modelContext
            )
        }
        .padding(.top, 20)
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
