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

    var body: some View {
        Group {
            if let vm = workoutViewModel {
                TabView(selection: $selectedTab) {
                    Tab("Workout", systemImage: "dumbbell", value: "workout") {
                        WorkoutTabView(viewModel: vm)
                    }
                    Tab("History", systemImage: "clock", value: "history") {
                        HistoryListView(workoutVM: vm)
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
            } else {
                // Mirrors LaunchScreen.storyboard so the handoff is seamless.
                ZStack {
                    Color.uplift.bgElev.ignoresSafeArea()
                    VStack(spacing: 18) {
                        Image("LaunchGlyph")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 132, height: 63)
                        Text("IronLog")
                            .font(.system(size: 34, weight: .bold, design: .default))
                            .tracking(-0.6)
                            .foregroundStyle(Color.uplift.accent)
                        Text("STRENGTH · PHYSIQUE")
                            .font(.system(size: 11, weight: .medium))
                            .tracking(1.2)
                            .foregroundStyle(Color.uplift.fgDim)
                    }
                    .offset(y: -12)
                }
            }
        }
        .tint(Color.uplift.accent)
        .preferredColorScheme(.dark)
        .onAppear {
            // Keep launch work light: seed + VM first so the tab UI appears.
            // Never call CloudKit here — without iCloud entitlements it can hang.
            SeedData.migrateExerciseNames(context: modelContext)
            SeedData.deduplicateExercises(context: modelContext)
            // Fresh install seeds; existing installs top up any missing catalog lifts.
            SeedData.seedIfNeeded(context: modelContext)
            DayTypeRegistry.shared.reload(context: modelContext)
            if workoutViewModel == nil {
                workoutViewModel = WorkoutViewModel(modelContext: modelContext, healthKitService: healthKitService)
            }
            healthKitService.checkAuthorization()
        }
        .onChange(of: workoutViewModel?.wantsFocusOnWorkoutTab) { _, wants in
            guard wants == true else { return }
            selectedTab = "workout"
            workoutViewModel?.wantsFocusOnWorkoutTab = false
        }
        // Don't auto-prompt HealthKit on cold launch — that dialog can stall the
        // first frame. Settings (and starting a workout) request access instead.

    }
}

#Preview {
    ContentView()
        .modelContainer(previewContainer)
}
