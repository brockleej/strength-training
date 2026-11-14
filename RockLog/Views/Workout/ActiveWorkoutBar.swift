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
        if viewModel.activeSession == nil && viewModel.restEndDate == nil {
            EmptyView()
        } else {
            tickingBar
        }
    }

    private var tickingBar: some View {
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
                    // Stops at the bar: no fill behind the floating tab bar.
                    .background(Color.uplift.surface2, ignoresSafeAreaEdges: [])
                    .accessibilityIdentifier(AccessibilityID.activeWorkoutBar)
                    .accessibilityLabel(line)
            }
        }
    }
}

extension View {
    /// Puts the bar at the bottom of a tab's own content, so it sits above the tab bar.
    ///
    /// It used to be a safe-area inset on the TabView itself. The iOS 26+ floating
    /// tab bar does not move for that inset, so the bar was drawn over the tabs:
    /// on a Pro Max every tab button was covered (1.2 bug, Lee Nov 10 2026, "the
    /// rest footer gets in the way of navigation"). Focus does not add it: its rest
    /// card already shows the countdown, and the small-phone footer has no room.
    func activeWorkoutBar(_ viewModel: WorkoutViewModel) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            ActiveWorkoutBar(viewModel: viewModel)
        }
    }
}
