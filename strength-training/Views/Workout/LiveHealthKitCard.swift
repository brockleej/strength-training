// strength-training/Views/Workout/LiveHealthKitCard.swift
import SwiftUI

/// Reads live BPM / kcal / elapsed from `HealthKitWorkoutService` and feeds them
/// into the Phase 0 `HealthKitCard` primitive.
///
/// Renders nothing if the HealthKit session isn't active and there's no elapsed
/// time — the card only makes sense when there's something live to show.
struct LiveHealthKitCard: View {
    @Bindable var service: HealthKitWorkoutService

    var body: some View {
        if shouldShow {
            HealthKitCard(
                bpm: Int(service.heartRate ?? 0),
                kcal: Int(service.activeCalories.rounded()),
                elapsed: formatElapsed(service.elapsedSeconds)
            )
        } else {
            EmptyView()
        }
    }

    /// Show when there's an active session OR there's any elapsed time
    /// (e.g., paused but mid-workout). Hidden if HK never started.
    private var shouldShow: Bool {
        service.isSessionActive || service.elapsedSeconds > 0
    }

    /// "MM:SS" up to 60 minutes; "HH:MM:SS" past that. SF Mono renders this monospace.
    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

#Preview("LiveHealthKitCard — service mock") {
    let service = HealthKitWorkoutService()
    // Can't easily simulate live values in preview without exposing internals.
    // Real verification happens during a live workout in the simulator.
    return VStack {
        LiveHealthKitCard(service: service)
        Text("(Renders only during an active HK session)")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .padding(20)
    .background(Color.uplift.bgElev)
}
