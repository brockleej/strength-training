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
    @State private var healthKitService = HealthKitWorkoutService()
    @State private var cloudKitSyncService = CloudKitSyncService()
    @State private var selectedTab = "workout"
    @State private var sessionToReview: WorkoutSession?

    var body: some View {
        Group {
            if let vm = workoutViewModel {
                TabView(selection: $selectedTab) {
                    Tab("Workout", systemImage: "dumbbell", value: "workout") {
                        WorkoutTabView(viewModel: vm)
                    }
                    Tab("History", systemImage: "clock", value: "history") {
                        HistoryListView(reviewSession: $sessionToReview)
                    }
                    Tab("Progress", systemImage: "chart.line.uptrend.xyaxis", value: "progress") {
                        ProgressDashboardView()
                    }
                    Tab("Exercises", systemImage: "list.bullet", value: "exercises") {
                        ExerciseLibraryView()
                    }
                    Tab("Settings", systemImage: "gear", value: "settings") {
                        SettingsView(healthKitService: healthKitService, cloudKitSyncService: cloudKitSyncService)
                    }
                }
                .tint(Color.uplift.accent)
                .preferredColorScheme(.dark)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            SeedData.deduplicateExercises(context: modelContext)
            SeedData.seedIfNeeded(context: modelContext)
            if workoutViewModel == nil {
                workoutViewModel = WorkoutViewModel(modelContext: modelContext, healthKitService: healthKitService)
            }
        }
        .task {
            if healthKitService.isAvailable && healthKitService.authorizationStatus == nil {
                _ = await healthKitService.requestAuthorization()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(previewContainer)
}
