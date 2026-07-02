//
//  ProgressDashboardView.swift
//  strength-training
//

import SwiftUI
import SwiftData

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
            VStack(spacing: 20) {
                Picker("Time Range", selection: $viewModel.selectedTimeRange) {
                    ForEach(ProgressTimeRange.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Headline metric cards
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StrengthScoreCard(
                        score: viewModel.strengthScore,
                        trend: viewModel.strengthScoreTrend,
                        delta: viewModel.strengthScoreDelta
                    )
                }
                .padding(.horizontal)

                PRsThisMonthCard(prs: viewModel.prsThisMonth)
                    .padding(.horizontal)

                // Balance & Coverage
                GroupBox("Muscle Group Volume") {
                    MuscleGroupVolumeChart(data: viewModel.muscleGroupVolumes)
                }
                .padding(.horizontal)

                GroupBox("Training Mode Split") {
                    ModeSplitChart(
                        data: viewModel.modeSplit,
                        period: $viewModel.modeSplitPeriod
                    )
                }
                .padding(.horizontal)

                // Exercise drill-down list
                ExerciseListSection(
                    groupedExercises: viewModel.exercisesGroupedByDayType(),
                    modelContext: viewModel.modelContext
                )
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

#Preview {
    ProgressDashboardView()
        .modelContainer(previewContainer)
}
