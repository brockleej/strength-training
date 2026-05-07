//
//  WorkoutTabView.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI

struct WorkoutTabView: View {
    @Bindable var viewModel: WorkoutViewModel

    var body: some View {
        Group {
            if viewModel.activeSession != nil {
                ExerciseListView(workoutVM: viewModel)
            } else {
                TodayView(workoutVM: viewModel)
            }
        }
        .sheet(item: $viewModel.sessionPendingEffortRating) { _ in
            EffortRatingView(
                onSave: { rating in viewModel.saveEffortRating(rating) },
                onSkip: { viewModel.skipEffortRating() }
            )
        }
        .sheet(item: $viewModel.sessionPendingSummary) { session in
            WorkoutSummaryWrapper(
                session: session,
                prCount: viewModel.prCountThisSession,
                healthKitService: viewModel.healthKitService,
                onDone: {
                    viewModel.sessionPendingSummary = nil
                    viewModel.activeSession = nil
                },
                onDetail: {
                    viewModel.sessionPendingSummary = nil
                    viewModel.activeSession = nil
                    // Trigger ContentView's existing onChange to switch to History + push detail.
                    viewModel.completedSessionToReview = session
                }
            )
        }
    }
}

/// Wraps WorkoutSummaryView with an async HealthKit stats fetch.
/// Lets the inner view remain pure-presentation (taking stats as a parameter).
private struct WorkoutSummaryWrapper: View {
    let session: WorkoutSession
    let prCount: Int
    let healthKitService: HealthKitWorkoutService
    let onDone: () -> Void
    let onDetail: () -> Void

    @State private var healthKitStats: HealthKitWorkoutStats?

    var body: some View {
        WorkoutSummaryView(
            session: session,
            prCount: prCount,
            healthKitStats: healthKitStats,
            onDone: onDone,
            onDetail: onDetail
        )
        .task {
            // Only fetch if the session has an HK workout linked.
            if let uuid = session.healthKitWorkoutUUID {
                healthKitStats = await healthKitService.fetchWorkoutStats(for: uuid)
            }
        }
    }
}
