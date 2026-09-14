//
//  ContentView.swift
//  RockLog
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
    @State private var pendingIncomingProgram: ProgramDocument?
    @State private var incomingProgramPrompt = RestorePrompt(
        title: "Add planned workouts?",
        message: ProgramImportService.confirmationMessage(weekCount: 8),
        confirmTitle: "Add workouts",
        cancelTitle: "Don't add"
    )
    @State private var showIncomingProgramConfirm = false
    @State private var pendingReplaceSplitDocument: ProgramDocument?
    @State private var pendingReplaceSplitSummary: ProgramImportSummary?
    @State private var showReplaceSplitConfirm = false
    @State private var pendingIncomingSplit: ProgramDocument?
    @State private var showIncomingSplitConfirm = false
    @State private var showIncomingKeepPlannedConfirm = false
    @State private var incomingFileMessage = ""
    @State private var showIncomingFileMessage = false

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
            FirstRunView(onFinished: {
                hasCompletedFirstRun = true
            }, showsSplitSetup: showFirstUseSplitSetup)
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
        .onOpenURL { url in
            handleIncomingURL(url)
        }
        .alert(
            incomingProgramPrompt.title,
            isPresented: $showIncomingProgramConfirm
        ) {
            Button(incomingProgramPrompt.cancelTitle) {
                pendingIncomingProgram = nil
            }
            Button(incomingProgramPrompt.confirmTitle) {
                if let document = pendingIncomingProgram {
                    importIncomingProgram(document, shiftStartToToday: false)
                }
                pendingIncomingProgram = nil
            }
            Button(ProgramImportService.replaceUnusedPlanTitle, role: .destructive) {
                if let document = pendingIncomingProgram {
                    importIncomingProgram(
                        document,
                        shiftStartToToday: false,
                        replaceUnusedPlan: true
                    )
                }
                pendingIncomingProgram = nil
            }
            Button(ProgramImportService.startThisBlockTodayTitle) {
                if let document = pendingIncomingProgram {
                    importIncomingProgram(document, shiftStartToToday: true)
                }
                pendingIncomingProgram = nil
            }
        } message: {
            Text(incomingProgramPrompt.message)
        }
        .alert(
            ProgramImportService.useThisSplitTitle,
            isPresented: $showReplaceSplitConfirm
        ) {
            Button(ProgramImportService.keepCurrentSplitTitle, role: .cancel) {
                finishIncomingProgramImport(replacedSplit: false)
            }
            Button(ProgramImportService.useThisSplitConfirmTitle) {
                if let document = pendingReplaceSplitDocument {
                    ProgramImportService.replaceSplit(from: document, context: modelContext)
                }
                finishIncomingProgramImport(replacedSplit: true)
            }
        } message: {
            Text(ProgramImportService.replaceSplitMessage())
        }
        .alert(
            ProgramImportService.importSplitTitle,
            isPresented: $showIncomingSplitConfirm
        ) {
            Button(ProgramImportService.importSplitCancelTitle, role: .cancel) {
                pendingIncomingSplit = nil
            }
            Button(ProgramImportService.importSplitConfirmTitle) {
                if let document = pendingIncomingSplit {
                    importIncomingSplit(document)
                }
                pendingIncomingSplit = nil
            }
        } message: {
            Text(ProgramImportService.importSplitMessage())
        }
        .alert(
            ProgramImportService.keepPlannedAfterSplitTitle,
            isPresented: $showIncomingKeepPlannedConfirm
        ) {
            Button(ProgramImportService.keepPlannedAfterSplitConfirmTitle) {
                finishIncomingSplitImport(removedUnusedPlan: false)
            }
            Button(ProgramImportService.removePlannedAfterSplitTitle, role: .destructive) {
                ProgramImportService.removeUnusedPlannedSessions(context: modelContext)
                finishIncomingSplitImport(removedUnusedPlan: true)
            }
        } message: {
            Text(ProgramImportService.keepPlannedAfterSplitMessage())
        }
        .alert("RockLog", isPresented: $showIncomingFileMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(incomingFileMessage)
        }
        // Don't auto-prompt HealthKit on cold launch — that dialog can stall the
        // first frame. Settings (and starting a workout) request access instead.
    }

    private func handleIncomingURL(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let data = try Data(contentsOf: url)
            switch try IncomingRockLogFile.parse(data) {
            case .program(let document):
                pendingIncomingProgram = document
                incomingProgramPrompt = ProgramImportService.summarize(document).confirmationPrompt
                showIncomingProgramConfirm = true
            case .split(let document):
                pendingIncomingSplit = document
                showIncomingSplitConfirm = true
            case .backup:
                incomingFileMessage = "This looks like a backup. Open Settings → Restore from backup to replace data on this phone."
                showIncomingFileMessage = true
            }
        } catch {
            incomingFileMessage = error.localizedDescription
            showIncomingFileMessage = true
        }
    }

    private func importIncomingSplit(_ document: ProgramDocument) {
        do {
            try ProgramImportService.importSplit(document, context: modelContext)
            if ProgramImportService.hasUnusedPlannedSessions(context: modelContext) {
                Task { @MainActor in
                    showIncomingKeepPlannedConfirm = true
                }
            } else {
                finishIncomingSplitImport(removedUnusedPlan: false)
            }
        } catch {
            incomingFileMessage = error.localizedDescription
            showIncomingFileMessage = true
        }
    }

    private func finishIncomingSplitImport(removedUnusedPlan: Bool) {
        incomingFileMessage = ProgramImportService.importSplitResultMessage(
            removedUnusedPlan: removedUnusedPlan
        )
        Task { @MainActor in
            showIncomingFileMessage = true
        }
    }

    private func importIncomingProgram(
        _ document: ProgramDocument,
        shiftStartToToday: Bool,
        replaceUnusedPlan: Bool = false
    ) {
        do {
            let result = try ProgramImportService.importDocument(
                document,
                context: modelContext,
                shiftingStartTo: shiftStartToToday ? Calendar.current.startOfDay(for: .now) : nil,
                replaceUnusedPlan: replaceUnusedPlan
            )
            pendingReplaceSplitDocument = document
            pendingReplaceSplitSummary = result.summary
            // Next run loop so this alert can replace the import confirm.
            Task { @MainActor in
                showReplaceSplitConfirm = true
            }
        } catch {
            incomingFileMessage = error.localizedDescription
            showIncomingFileMessage = true
        }
    }

    private func finishIncomingProgramImport(replacedSplit: Bool) {
        let summary = pendingReplaceSplitSummary
        pendingReplaceSplitDocument = nil
        pendingReplaceSplitSummary = nil
        guard let summary else { return }
        let message = ProgramImportService.resultMessage(
            summary: summary,
            replacedSplit: replacedSplit
        )
        Task { @MainActor in
            incomingFileMessage = message
            showIncomingFileMessage = true
        }
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
