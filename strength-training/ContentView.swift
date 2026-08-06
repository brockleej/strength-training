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
        .task {
            // Migrations are safe anytime; full catalog seed waits for iCloud when empty.
            SeedData.hydrateSplitPreferencesFromICloud()
            SeedData.migrateExerciseNames(context: modelContext)
            SeedData.deduplicateExercises(context: modelContext)
            SeedData.deduplicateSplitDays(context: modelContext)

            let exerciseCount = (try? modelContext.fetchCount(FetchDescriptor<Exercise>())) ?? 0
            let splitCount = (try? modelContext.fetchCount(FetchDescriptor<SplitDay>())) ?? 0
            let storeLooksEmpty = exerciseCount == 0 && splitCount == 0

            if storeLooksEmpty {
                await cloudKitSyncService.waitBeforeInitialSeedIfNeeded(modelContext: modelContext)
            }

            // After wait: seed only if still empty (no remote library). Never re-fill
            // deleted catalog lifts on every launch (see SeedData.topUpCatalogIfNeeded).
            SeedData.seedIfNeeded(
                context: modelContext,
                allowEmptyCatalogSeed: true
            )
            // If user had configured a split but store is still empty (sync lag),
            // seedIfNeeded already skipped re-seeding bro when hasConfiguredSplit is set.
            DayTypeRegistry.shared.reload(context: modelContext)

            if workoutViewModel == nil {
                workoutViewModel = WorkoutViewModel(
                    modelContext: modelContext,
                    healthKitService: healthKitService
                )
            }
            healthKitService.checkAuthorization()
        }
        // Second device often seeds before iCloud import finishes — re-dedupe after sync.
        .onChange(of: cloudKitSyncService.lastSyncDate) { _, newDate in
            guard newDate != nil else { return }
            SeedData.reconcileAfterCloudKitImport(context: modelContext)
            DayTypeRegistry.shared.reload(context: modelContext)
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
