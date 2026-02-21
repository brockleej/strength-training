//
//  ChartsOverviewView.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI

enum ChartType: String, CaseIterable, Identifiable {
    case weight = "Weight"
    case reps = "Reps"
    case volume = "Volume"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .weight: "scalemass"
        case .reps: "number"
        case .volume: "chart.bar"
        }
    }
}

struct ChartsOverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ChartsViewModel?
    @State private var selectedChartType: ChartType = .weight

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    ChartsContent(viewModel: vm, selectedChartType: $selectedChartType)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Progress")
            .onAppear {
                if viewModel == nil {
                    viewModel = ChartsViewModel(modelContext: modelContext)
                }
            }
        }
    }
}

private struct ChartsContent: View {
    @Bindable var viewModel: ChartsViewModel
    @Binding var selectedChartType: ChartType

    var body: some View {
        List {
            // Day type picker
            Section {
                Picker("Day Type", selection: $viewModel.selectedDayType) {
                    ForEach(DayType.allCases) { dayType in
                        Text(dayType.rawValue).tag(dayType)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.selectedDayType) {
                    // Reset exercise selection when day type changes
                    viewModel.selectedExercise = nil
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            // Exercise picker
            Section {
                let exercises = viewModel.allExercises(for: viewModel.selectedDayType)

                Picker("Exercise", selection: $viewModel.selectedExercise) {
                    Text("Select Exercise")
                        .tag(nil as Exercise?)
                    ForEach(exercises) { exercise in
                        Text(exercise.name).tag(exercise as Exercise?)
                    }
                }

                // Mode picker
                Picker("Mode", selection: $viewModel.selectedMode) {
                    ForEach(TrainingMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode.systemImage)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Chart type picker
            Section {
                Picker("Chart", selection: $selectedChartType) {
                    ForEach(ChartType.allCases) { chartType in
                        Label(chartType.rawValue, systemImage: chartType.systemImage)
                            .tag(chartType)
                    }
                }
                .pickerStyle(.segmented)
            }

            // The chart
            Section {
                switch selectedChartType {
                case .weight:
                    WeightProgressChart(data: viewModel.weightProgression())
                case .reps:
                    RepsProgressChart(data: viewModel.repsProgression())
                case .volume:
                    VolumeChart(data: viewModel.volumeProgression())
                }
            }
        }
    }
}
