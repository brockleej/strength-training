//
//  ActiveWorkoutBar.swift
//  RockLog
//
//  Timer and rest countdown that stay visible on every tab.
//

import SwiftUI

enum ActiveWorkoutBarCopy {
    /// Rest wins while a countdown is running. Otherwise the open workout's elapsed time.
    static func line(sessionStarted: Date?, restEnd: Date?, now: Date) -> String? {
        if let restEnd, restEnd > now {
            let seconds = max(0, Int(restEnd.timeIntervalSince(now).rounded(.up)))
            return "Rest \(seconds)s"
        }
        guard let sessionStarted else { return nil }
        let elapsed = max(0, Int(now.timeIntervalSince(sessionStarted)))
        return String(format: "Workout %d:%02d", elapsed / 60, elapsed % 60)
    }
}

struct ActiveWorkoutBar: View {
    @Bindable var viewModel: WorkoutViewModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let line = ActiveWorkoutBarCopy.line(
                sessionStarted: viewModel.activeSession?.date,
                restEnd: viewModel.restEndDate,
                now: context.date
            )
            if let line {
                Text(line)
                    .font(.uplift.mono(13, weight: .semibold))
                    .foregroundStyle(Color.uplift.fg)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.uplift.surface2)
                    .accessibilityIdentifier(AccessibilityID.activeWorkoutBar)
                    .accessibilityLabel(line)
            }
        }
    }
}
