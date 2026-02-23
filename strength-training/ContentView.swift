//
//  ContentView.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var workoutViewModel: WorkoutViewModel?

    var body: some View {
        if let vm = workoutViewModel {
            TabView {
                Tab("Workout", systemImage: "dumbbell") {
                    WorkoutTabView(viewModel: vm)
                }
                Tab("History", systemImage: "clock") {
                    HistoryListView()
                }
                Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") {
                    ChartsOverviewView()
                }
                Tab("Exercises", systemImage: "list.bullet") {
                    ExerciseLibraryView()
                }
                Tab("Settings", systemImage: "gear") {
                    SettingsView()
                }
            }
        } else {
            VStack(spacing: 16) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                ProgressView()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                SeedData.seedIfNeeded(context: modelContext)
                workoutViewModel = WorkoutViewModel(modelContext: modelContext)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(previewContainer)
}
