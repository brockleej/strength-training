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
        Group {
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
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            SeedData.seedIfNeeded(context: modelContext)
            if workoutViewModel == nil {
                workoutViewModel = WorkoutViewModel(modelContext: modelContext)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(previewContainer)
}
