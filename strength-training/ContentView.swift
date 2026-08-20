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
    @State private var awakenedTabs: Set<String> = ["workout"]
    @AppStorage(FirstRunPreferences.completedKey) private var hasCompletedFirstRun = false
    @State private var showFirstUseSplitSetup = false
    /// While true the TabView (including Focus / workout list) is torn down
    /// so restore can delete SwiftData rows without those views reading them.
    @State private var storeReplaceInProgress = false

    var body: some View {
        Group {
            if storeReplaceInProgress {
                RockLogLaunchPlaceholder(showsProgress: true)
            } else if let vm = workoutViewModel {
                // Classic TabView (iOS 17+). The iOS 18 `Tab { }` API is not used so we keep
                // the minimum deployment at 17.0 for broader TestFlight reach.
                TabView(selection: $selectedTab) {
                    WorkoutTabView(viewModel: vm)
                        .tabItem { Label("Workout", systemImage: "dumbbell") }
                        .tag("workout")
                    tab("history") {
                        HistoryListView(workoutVM: vm)
                    }
                    .tabItem { Label("History", systemImage: "clock") }
                    .tag("history")
                    tab("progress") {
                        ProgressDashboardView()
                    }
                    .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                    .tag("progress")
                    tab("exercises") {
                        ExerciseLibraryView()
                    }
                    .tabItem { Label("Exercises", systemImage: "list.bullet") }
                    .tag("exercises")
                    tab("settings") {
                        SettingsView(healthKitService: healthKitService, cloudKitSyncService: cloudKitSyncService)
                    }
                    .tabItem { Label("Settings", systemImage: "gear") }
                    .tag("settings")
                }
                .onChange(of: selectedTab) { _, tab in
                    awakenedTabs.insert(tab)
                }
            } else {
                RockLogLaunchPlaceholder(showsProgress: false)
            }
        }
        .tint(Color.uplift.accent)
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: Binding(
            get: { workoutViewModel != nil && !hasCompletedFirstRun },
            set: { if !$0 { hasCompletedFirstRun = true } }
        )) {
            FirstRunView(showsSplitSetup: showFirstUseSplitSetup) {
                hasCompletedFirstRun = true
            }
        }
        .task {
            // Hydrate iCloud split prefs before first-run UI, so a reinstall
            // does not ask to pick a split that already lives in KVS.
            SeedData.hydrateSplitPreferencesFromICloud()
            GymMembershipStore.shared.hydrateFromICloud()
            BodyProfileStore.shared.hydrateFromICloud()
            showFirstUseSplitSetup = SeedData.needsFirstUseSplitSetup(context: modelContext)

            // Show tabs immediately — don't wait on CloudKit / seed.
            DayTypeRegistry.shared.reload(context: modelContext)
            if workoutViewModel == nil {
                workoutViewModel = WorkoutViewModel(
                    modelContext: modelContext,
                    healthKitService: healthKitService
                )
            }
            await Task.yield()

            SeedData.migrateExerciseNames(context: modelContext)
            SeedData.migrateCompoundMuscleGroups(context: modelContext)
            // Dedupe walks every lift's history — only after CloudKit import.

            let exerciseCount = (try? modelContext.fetchCount(FetchDescriptor<Exercise>())) ?? 0
            let hasRemoteSplit = UserDefaults.standard.bool(forKey: SeedData.hasConfiguredSplitKey)
                || SeedData.loadSplitSnapshot() != nil
                || SeedData.loadDayPlanSnapshot() != nil
            if exerciseCount == 0 && hasRemoteSplit {
                await cloudKitSyncService.waitBeforeInitialSeedIfNeeded(modelContext: modelContext)
            }

            SeedData.reconcileSplitToSnapshot(context: modelContext)
            SeedData.seedIfNeeded(
                context: modelContext,
                allowEmptyCatalogSeed: true
            )
            DayTypeRegistry.shared.reload(context: modelContext)
            SeedData.persistSplitSnapshotIfAuthoritative(context: modelContext)
            healthKitService.checkAuthorization()
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NSUbiquitousKeyValueStore.didChangeExternallyNotification
        )) { _ in
            SeedData.hydrateSplitPreferencesFromICloud()
            SeedData.reconcileSplitToSnapshot(context: modelContext)
            DayTypeRegistry.shared.reload(context: modelContext)
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
        .onReceive(NotificationCenter.default.publisher(for: .rockLogStoreWillReplace)) { _ in
            workoutViewModel?.resetAfterStoreReplace()
            storeReplaceInProgress = true
            selectedTab = "settings"
            awakenedTabs = ["settings"]
        }
        .onReceive(NotificationCenter.default.publisher(for: .rockLogStoreReplaced)) { _ in
            if let hk = workoutViewModel?.healthKitService {
                workoutViewModel = WorkoutViewModel(
                    modelContext: modelContext,
                    healthKitService: hk
                )
            } else {
                workoutViewModel?.resetAfterStoreReplace()
            }
            storeReplaceInProgress = false
            selectedTab = "workout"
            awakenedTabs = ["workout"]
        }
        // Don't auto-prompt HealthKit on cold launch — that dialog can stall the
        // first frame. Settings (and starting a workout) request access instead.
    }

    @ViewBuilder
    private func tab<Content: View>(_ id: String, @ViewBuilder content: () -> Content) -> some View {
        if awakenedTabs.contains(id) {
            content()
        } else {
            Color.uplift.bgElev.ignoresSafeArea()
        }
    }
}

/// Matches LaunchScreen.storyboard so the handoff does not flash.
struct RockLogLaunchPlaceholder: View {
    var showsProgress: Bool

    var body: some View {
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
                if showsProgress {
                    ProgressView()
                        .tint(Color.uplift.accent)
                        .padding(.top, 8)
                }
            }
            .offset(y: -12)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(previewContainer)
}
