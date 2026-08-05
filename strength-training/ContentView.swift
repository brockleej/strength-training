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
                // Classic TabView (iOS 17+). The iOS 18 `Tab { }` API is not used so we keep
                // the minimum deployment at 17.0 for broader TestFlight reach.
                TabView(selection: $selectedTab) {
                    WorkoutTabView(viewModel: vm)
                        .tabItem { Label("Workout", systemImage: "dumbbell") }
                        .tag("workout")
                    HistoryListView(workoutVM: vm)
                        .tabItem { Label("History", systemImage: "clock") }
                        .tag("history")
                    ProgressDashboardView()
                        .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                        .tag("progress")
                    ExerciseLibraryView()
                        .tabItem { Label("Exercises", systemImage: "list.bullet") }
                        .tag("exercises")
                    SettingsView(healthKitService: healthKitService, cloudKitSyncService: cloudKitSyncService)
                        .tabItem { Label("Settings", systemImage: "gear") }
                        .tag("settings")
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
                        Text("RockLog")
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
            // CloudKit account checks run inside CloudKitSyncService, not here.
            SeedData.migrateExerciseNames(context: modelContext)
            SeedData.deduplicateExercises(context: modelContext)
            SeedData.deduplicateSplitDays(context: modelContext)
            // Fresh install seeds; existing installs top up any missing catalog lifts.
            SeedData.seedIfNeeded(context: modelContext)
            DayTypeRegistry.shared.reload(context: modelContext)
            if workoutViewModel == nil {
                workoutViewModel = WorkoutViewModel(modelContext: modelContext, healthKitService: healthKitService)
            }
            healthKitService.checkAuthorization()
        }
        // Second device often seeds before iCloud import finishes — re-dedupe after sync.
        .onChange(of: cloudKitSyncService.lastSyncDate) { _, newDate in
            guard newDate != nil else { return }
            SeedData.reconcileAfterCloudKitImport(context: modelContext)
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
