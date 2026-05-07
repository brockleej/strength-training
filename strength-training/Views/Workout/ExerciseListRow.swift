// strength-training/Views/Workout/ExerciseListRow.swift
import SwiftUI

/// One row in `ExerciseListView`. Three visual states:
/// - **pending** (`.pending`): numbered circle, surface1 bg, full opacity
/// - **active** (`.active`): accent dot in soft circle, surface3 bg, accent border, accent chevron
/// - **completed** (`.completed`): green checkmark in soft green circle, surface1 bg, 0.6 opacity, strikethrough name
///
/// Tap handling lives at the call site (`ExerciseListView`).
struct ExerciseListRow: View {
    enum State {
        case pending(index: Int)
        case active
        case completed
    }

    let exercise: Exercise
    let state: State
    let setSummary: String      // "4 × 5" / "3 × 8"
    let targetWeight: String?   // "225 lb" — nil if no history

    var body: some View {
        HStack(spacing: 12) {
            statusIndicator
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.uplift.text(15, weight: .semibold))
                    .kerning(-0.2)
                    .foregroundStyle(Color.uplift.fg)
                    .strikethrough(isCompleted, color: Color.uplift.fgDim)
                Text(subtitleText)
                    .font(.uplift.text(12, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isActive {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.uplift.accent)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isActive ? Color.uplift.surface3 : Color.uplift.surface1)
        }
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.uplift.accent, lineWidth: 1.5)
            }
        }
        .opacity(isCompleted ? 0.6 : 1.0)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - State helpers

    private var isActive: Bool {
        if case .active = state { return true } else { return false }
    }

    private var isCompleted: Bool {
        if case .completed = state { return true } else { return false }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch state {
        case .pending(let index):
            ZStack {
                Circle().fill(Color.uplift.surface2)
                Num(index, size: 12, color: .uplift.fgDim)
            }
            .frame(width: 28, height: 28)
        case .active:
            ZStack {
                Circle().fill(Color.uplift.accentSoft)
                Circle().fill(Color.uplift.accent).frame(width: 8, height: 8)
            }
            .frame(width: 28, height: 28)
        case .completed:
            ZStack {
                Circle().fill(Color.uplift.up.opacity(0.16))
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.uplift.up)
            }
            .frame(width: 28, height: 28)
        }
    }

    private var subtitleText: String {
        if let targetWeight {
            return "\(setSummary) · \(targetWeight)"
        }
        return setSummary
    }
}

#Preview("ExerciseListRow — variants") {
    VStack(spacing: 8) {
        ExerciseListRow(
            exercise: Exercise(name: "Back Squat", dayType: .legs),
            state: .completed,
            setSummary: "4 × 5",
            targetWeight: "225 lb"
        )
        ExerciseListRow(
            exercise: Exercise(name: "Walking Lunge", dayType: .legs),
            state: .active,
            setSummary: "3 × 12",
            targetWeight: "40 lb"
        )
        ExerciseListRow(
            exercise: Exercise(name: "Leg Press", dayType: .legs),
            state: .pending(index: 4),
            setSummary: "3 × 10",
            targetWeight: "360 lb"
        )
        ExerciseListRow(
            exercise: Exercise(name: "Hip Thrust", dayType: .legs),
            state: .pending(index: 5),
            setSummary: "3 × 12",
            targetWeight: nil
        )
    }
    .padding(20)
    .background(Color.uplift.bgElev)
}
