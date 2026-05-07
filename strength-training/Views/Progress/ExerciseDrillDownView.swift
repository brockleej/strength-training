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
                // Task 9: miniChartCard, recentSessionsSection
                // Task 10: e1rmTrendCard, volumePerSessionCard

                // LEGACY: replaced in Tasks 9-10
                legacyChartsSection
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

    // MARK: - LEGACY: replaced in Tasks 9-10

    private var legacyChartsSection: some View {
        VStack(spacing: 20) {
            UpliftRangePicker(selection: $viewModel.selectedTimeRange)

            // Summary header
            ExerciseSummaryHeader(viewModel: viewModel)

            // Top Set Trend
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Top Set Trend")
                            .font(.headline)
                        Spacer()
                        Picker("Metric", selection: $viewModel.topSetMetric) {
                            ForEach(ExerciseDrillDownViewModel.TopSetMetric.allCases) {
                                Text($0.rawValue).tag($0)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 200)
                    }
                    TopSetTrendChart(data: viewModel.topSetTrendData)
                }
            }

            // Estimated 1RM Trend
            GroupBox("Estimated 1RM") {
                E1RMTrendChart(data: viewModel.e1rmTrendData)
            }

            // Volume per Session
            GroupBox("Volume per Session") {
                VolumePerSessionChart(data: viewModel.volumePerSessionData)
            }
        }
        .padding(.top, 20)
    }
}

private struct ExerciseSummaryHeader: View {
    let viewModel: ExerciseDrillDownViewModel

    var body: some View {
        HStack(spacing: 16) {
            SummaryTile(
                label: "Best e1RM",
                value: viewModel.allTimeE1RM.map { String(format: "%.0f lbs", $0) } ?? "—"
            )
            SummaryTile(
                label: "Sessions",
                value: "\(viewModel.totalSessions)"
            )
            SummaryTile(
                label: "Last Trained",
                value: viewModel.lastSessionDate.map {
                    $0.formatted(.dateTime.month(.abbreviated).day())
                } ?? "—"
            )
        }
    }
}

private struct SummaryTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
