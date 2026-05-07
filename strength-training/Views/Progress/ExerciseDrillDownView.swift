//
//  ExerciseDrillDownView.swift
//  strength-training
//

import SwiftUI
import SwiftData

struct ExerciseDrillDownView: View {
    let exercise: Exercise
    let modelContext: ModelContext
    @State private var viewModel: ExerciseDrillDownViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                ExerciseDrillDownContent(viewModel: vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(exercise.name)
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
            VStack(spacing: 20) {
                UpliftRangePicker(selection: $viewModel.selectedTimeRange)
                    .padding(.horizontal)

                // Summary header
                ExerciseSummaryHeader(viewModel: viewModel)
                    .padding(.horizontal)

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
                .padding(.horizontal)

                // Estimated 1RM Trend
                GroupBox("Estimated 1RM") {
                    E1RMTrendChart(data: viewModel.e1rmTrendData)
                }
                .padding(.horizontal)

                // Volume per Session
                GroupBox("Volume per Session") {
                    VolumePerSessionChart(data: viewModel.volumePerSessionData)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
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
