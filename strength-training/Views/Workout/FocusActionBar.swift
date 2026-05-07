// strength-training/Views/Workout/FocusActionBar.swift
import SwiftUI

/// Sticky pill bottom bar — rest timer chip + "Log set" primary action.
/// Timer auto-ticks at 1Hz via `.task`; resets to 0 on each `setLogged()`.
struct FocusActionBar: View {
    @Bindable var focusVM: FocusViewModel
    let onLogSet: () -> Void

    var body: some View {
        PillBottomBar {
            timerChip
            logButton
        }
        .task {
            // Single long-running task — increments restTimerSeconds once per second
            // for the lifetime of this view. setLogged() resets restTimerSeconds to 0;
            // we don't need to restart the task — the very next tick simply increments
            // from 0 again. No `id:` parameter (re-firing .task every second cancels
            // the in-flight sleep, which makes the timer erratic).
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                focusVM.restTimerSeconds += 1
            }
        }
    }

    private var timerChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.uplift.fgMuted)
            Num(FocusViewModel.formatRest(focusVM.restTimerSeconds), size: 14, color: .uplift.fg)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var logButton: some View {
        Button {
            onLogSet()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .semibold))
                Text("Log set")
                    .font(.uplift.text(15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color.uplift.accent, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .foregroundStyle(Color.uplift.onAccent)
        }
        .buttonStyle(.plain)
    }
}
