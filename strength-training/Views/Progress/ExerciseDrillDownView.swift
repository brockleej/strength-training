//
//  ExerciseDrillDownView.swift
//  strength-training
//

import SwiftUI
import SwiftData
import Charts

struct ExerciseDrillDownView: View {
    let exercise: Exercise
    let modelContext: ModelContext

    @State private var viewModel: ExerciseDrillDownViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                DrillDownContent(viewModel: vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil {
                viewModel = ExerciseDrillDownViewModel(modelContext: modelContext, exercise: exercise)
            }
        }
    }
}

private struct DrillDownContent: View {
    @Bindable var viewModel: ExerciseDrillDownViewModel

    private var exercise: Exercise { viewModel.exercise }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroCard
                personalBestCard
                    .padding(.top, 8)
                rangePicker
                    .padding(.top, 14)
                topSetCard
                    .padding(.top, 8)
                SectionHeader("Estimated 1RM trend")
                E1RMTrendChart(data: viewModel.e1rmTrendData)
                SectionHeader("Recent sessions")
                recentSessionRows
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color.uplift.bgElev)
        .scrollIndicators(.hidden)
    }

    // MARK: - Hero

    private var heroCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(exercise.dayType.upliftWash)
                Image(systemName: exercise.dayType.systemImage)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(exercise.dayType.upliftInk)
            }
            .frame(width: 80, height: 80)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(exercise.dayType.rawValue)")
                    .textCase(.uppercase)
                    .font(.uplift.text(11, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(exercise.dayType.upliftInk)
                Text(exercise.name)
                    .font(.uplift.display(22, weight: .bold))
                    .kerning(-0.5)
                    .foregroundStyle(Color.uplift.fg)
                HStack(spacing: 6) {
                    if !exercise.muscleGroup.isEmpty {
                        Text(exercise.muscleGroup)
                            .font(.uplift.text(11, weight: .semibold))
                            .foregroundStyle(exercise.dayType.upliftInk)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(exercise.dayType.upliftWash))
                    }
                    Text("\(viewModel.totalSessions) session\(viewModel.totalSessions == 1 ? "" : "s")\(lastTrainedSuffix)")
                        .font(.uplift.text(11, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.uplift.surface1)
        }
        .padding(.top, 8)
    }

    private var lastTrainedSuffix: String {
        guard let last = viewModel.lastSessionDate else { return "" }
        return " · \(PrevSessionsStripData.relativeLabel(for: last).lowercased())"
    }

    // MARK: - Personal best

    @ViewBuilder
    private var personalBestCard: some View {
        if let best = viewModel.personalBestSet {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.uplift.pr.opacity(0.16))
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.uplift.pr)
                }
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Personal best")
                        .textCase(.uppercase)
                        .font(.uplift.text(11, weight: .semibold))
                        .tracking(0.3)
                        .foregroundStyle(Color.uplift.fgMuted)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Num("\(StepperLogic.format(best.weight)) × \(best.reps)", size: 22, weight: .semibold)
                        Text(PrevSessionsStripData.relativeLabel(for: best.date).lowercased())
                            .font(.uplift.text(12, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("1RM est.")
                        .textCase(.uppercase)
                        .font(.uplift.text(11, weight: .semibold))
                        .tracking(0.3)
                        .foregroundStyle(Color.uplift.fgMuted)
                    Num("\(Int((viewModel.allTimeE1RM ?? 0).rounded()))", size: 18, weight: .semibold)
                }
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.uplift.surface1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Personal best \(StepperLogic.format(best.weight)) pounds for \(best.reps) reps, estimated 1 rep max \(Int((viewModel.allTimeE1RM ?? 0).rounded())) pounds")
        }
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
    }

    // MARK: - Top set bar chart

    private var topSetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top set")
                    .font(.uplift.text(13, weight: .semibold))
                    .foregroundStyle(Color.uplift.fg)
                Spacer()
                Text("per session in range")
                    .font(.uplift.text(12, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
            }
            UpliftSegmentedControl(
                segments: ExerciseDrillDownViewModel.TopSetMetric.allCases.map {
                    UpliftSegment(id: $0.rawValue, label: $0.rawValue)
                },
                selection: Binding(
                    get: { viewModel.topSetMetric.rawValue },
                    set: { viewModel.topSetMetric = ExerciseDrillDownViewModel.TopSetMetric(rawValue: $0) ?? .weight }
                )
            )
            if viewModel.topSetBars.isEmpty {
                Text("No sessions in this range")
                    .font(.uplift.text(13, weight: .medium))
                    .foregroundStyle(Color.uplift.fgDim)
                    .frame(maxWidth: .infinity)
                    .frame(height: 90)
            } else {
                Chart(viewModel.topSetBars) { bar in
                    BarMark(
                        x: .value("Date", bar.date, unit: .day),
                        y: .value("Value", bar.value)
                    )
                    .foregroundStyle(bar.isPR ? Color.uplift.pr : Color.uplift.accent.opacity(0.75))
                    .cornerRadius(3)
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) {
                        AxisGridLine().foregroundStyle(Color.uplift.hairline)
                        AxisValueLabel()
                            .font(.uplift.text(10, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) {
                        AxisValueLabel()
                            .font(.uplift.text(10, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                    }
                }
                .frame(height: 90)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.uplift.surface1)
        }
    }

    // MARK: - Recent sessions

    private var recentSessionRows: some View {
        VStack(spacing: 6) {
            if viewModel.recentSessions.isEmpty {
                Text("No sessions in this range")
                    .font(.uplift.text(13, weight: .medium))
                    .foregroundStyle(Color.uplift.fgDim)
                    .padding(.vertical, 8)
            }
            ForEach(viewModel.recentSessions, id: \.id) { session in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(PrevSessionsStripData.relativeLabel(for: session.date))
                                .font(.uplift.text(14, weight: .semibold))
                                .foregroundStyle(Color.uplift.fg)
                            if session.isPR {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.uplift.pr)
                                    .accessibilityLabel("Personal record")
                            }
                        }
                        Text("\(session.sets) set\(session.sets == 1 ? "" : "s")")
                            .font(.uplift.text(12, weight: .medium))
                            .foregroundStyle(Color.uplift.fgMuted)
                    }
                    Spacer()
                    Text("\(StepperLogic.format(session.topWeight)) × \(session.topReps)")
                        .font(.uplift.mono(14, weight: .semibold))
                        .foregroundStyle(Color.uplift.fg)
                }
                .padding(13)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.uplift.surface1)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(PrevSessionsStripData.relativeLabel(for: session.date)), \(session.sets) sets, top set \(StepperLogic.format(session.topWeight)) pounds for \(session.topReps) reps\(session.isPR ? ", personal record" : "")")
            }
        }
    }
}
