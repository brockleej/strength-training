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
    @State private var selectedTab: UpliftTab = .today
    @State private var sessionToReview: WorkoutSession?

    var body: some View {
        Group {
            if let vm = workoutViewModel {
                ZStack(alignment: .bottom) {
                    tabContent(vm: vm)
                    TabBar(selection: $selectedTab)
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .onChange(of: vm.completedSessionToReview) { _, session in
                    if let session {
                        sessionToReview = session
                        selectedTab = .history
                        vm.activeSession = nil
                        vm.completedSessionToReview = nil
                    }
                }
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

    @ViewBuilder
    private func tabContent(vm: WorkoutViewModel) -> some View {
        switch selectedTab {
        case .today:
            WorkoutTabView(viewModel: vm)
        case .history:
            HistoryListView(reviewSession: $sessionToReview)
        case .progress:
            ProgressDashboardView()
        case .exercises:
            ExerciseLibraryView()
        case .settings:
            SettingsView(healthKitService: healthKitService, cloudKitSyncService: cloudKitSyncService)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(previewContainer)
}
