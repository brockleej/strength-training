//
//  LiveHealthKitCard.swift
//  strength-training
//

import SwiftUI

/// HealthKitCard fed by the live workout service. Renders only while a
/// HealthKit session is active or has accumulated time (same visibility
/// rule as the old metrics banner). Ticks via TimelineView every second.
struct LiveHealthKitCard: View {
    let service: HealthKitWorkoutService

    var body: some View {
        if service.isSessionActive || service.elapsedSeconds > 0 {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                HealthKitCard(
                    bpm: service.heartRate.map { Int($0.rounded()) },
                    kcal: Int(service.activeCalories.rounded()),
                    elapsed: WorkoutFormat.elapsed(service.elapsedSeconds)
                )
            }
        }
    }
}

#Preview("LiveHealthKitCard (static values)") {
    // Live service has no data in previews — showing the underlying card states.
    VStack(spacing: 12) {
        HealthKitCard(bpm: 142, kcal: 234, elapsed: "18:42")
        HealthKitCard(bpm: nil, kcal: 0, elapsed: "0:12")
    }
    .padding(20)
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
}
