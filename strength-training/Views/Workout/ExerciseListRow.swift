//
//  ExerciseListRow.swift
//  strength-training
//

import SwiftUI

/// One exercise in the in-workout overview list.
/// pending = numbered circle · active (last-visited) = accent dress · completed = check + strikethrough.
struct ExerciseListRow: View {
    enum RowState: Equatable {
        case pending(number: Int)
        case active
        case completed
    }

    let name: String
    let subtitle: String     // WorkoutFormat.rowSubtitle output
    let state: RowState

    private var isActive: Bool { state == .active }
    private var isCompleted: Bool { state == .completed }

    var body: some View {
        HStack(spacing: 12) {
            statusCircle
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.uplift.text(15, weight: .semibold))
                    .kerning(-0.2)
                    .foregroundStyle(Color.uplift.fg)
                    .strikethrough(isCompleted, color: Color.uplift.fgDim)
                Text(subtitle)
                    .font(.uplift.mono(12, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
            }
            Spacer(minLength: 8)
            if isActive {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.uplift.accent)
                    .accessibilityHidden(true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(isCompleted ? 0.6 : 1)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isActive ? Color.uplift.surface3 : Color.uplift.surface1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isActive ? Color.uplift.accent : .clear, lineWidth: 1.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var statusCircle: some View {
        ZStack {
            switch state {
            case .completed:
                Circle().fill(Color.uplift.up.opacity(0.16))
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.uplift.up)
            case .active:
                Circle().fill(Color.uplift.accentSoft)
                Circle().fill(Color.uplift.accent).frame(width: 8, height: 8)
            case .pending(let number):
                Circle().fill(Color.uplift.surface2)
                Text("\(number)")
                    .font(.uplift.mono(12, weight: .semibold))
                    .foregroundStyle(Color.uplift.fgDim)
            }
        }
        .frame(width: 28, height: 28)
    }

    private var accessibilityText: String {
        let stateText: String
        switch state {
        case .completed: stateText = "completed"
        case .active: stateText = "current exercise"
        case .pending(let n): stateText = "number \(n)"
        }
        return "\(name), \(subtitle == "—" ? "no history" : subtitle), \(stateText)"
    }
}

#Preview("ExerciseListRow") {
    VStack(spacing: 8) {
        ExerciseListRow(name: "Back Squat", subtitle: "4 × 5 · 225 lb", state: .completed)
        ExerciseListRow(name: "Walking Lunge", subtitle: "3 × 12 · 40 lb", state: .active)
        ExerciseListRow(name: "Leg Press", subtitle: "3 × 10 · 360 lb", state: .pending(number: 4))
        ExerciseListRow(name: "Nordic Curl", subtitle: "—", state: .pending(number: 5))
    }
    .padding(20)
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
}
