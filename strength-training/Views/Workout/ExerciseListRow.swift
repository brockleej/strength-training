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
    let lastSets: Int?        // last session's working-set count
    let targetWeight: Double? // progression target (fallback: recent avg weight)
    let targetReps: Int?      // recent avg reps
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
                subtitleText
                    .font(.uplift.mono(12, weight: .medium))
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

    private var subtitleText: Text {
        guard targetWeight != nil || targetReps != nil else {
            return Text("—").foregroundColor(.uplift.fgMuted)
        }
        let setsPrefix: Text = lastSets.map { Text("\($0) sets · ").foregroundColor(.uplift.fgMuted) } ?? Text("")
        if let targetWeight, let targetReps {
            return setsPrefix + PairText.pair(weight: targetWeight, reps: targetReps, font: .uplift.mono(12, weight: .medium))
        } else if let targetReps {
            return setsPrefix + Text("\(targetReps)").foregroundColor(.uplift.repsTint)
        } else if let targetWeight {
            return setsPrefix + Text(StepperLogic.format(targetWeight)).foregroundColor(.uplift.weightTint)
        }
        return setsPrefix + Text("—").foregroundColor(.uplift.fgMuted)
    }

    private var accessibilitySubtitle: String {
        let setsPart = lastSets.map { "\($0) sets, " } ?? ""
        if let targetWeight, let targetReps {
            return "\(setsPart)\(StepperLogic.format(targetWeight)) pounds by \(targetReps)"
        } else if let targetReps {
            return "\(setsPart)\(targetReps) reps"
        } else if let targetWeight {
            return "\(setsPart)\(StepperLogic.format(targetWeight)) pounds"
        }
        return "no history"
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
        return "\(name), \(accessibilitySubtitle), \(stateText)"
    }
}

#Preview("ExerciseListRow") {
    VStack(spacing: 8) {
        ExerciseListRow(name: "Back Squat", lastSets: 4, targetWeight: 225, targetReps: 5, state: .completed)
        ExerciseListRow(name: "Walking Lunge", lastSets: 3, targetWeight: 40, targetReps: 12, state: .active)
        ExerciseListRow(name: "Leg Press", lastSets: 3, targetWeight: 360, targetReps: 10, state: .pending(number: 4))
        ExerciseListRow(name: "Nordic Curl", lastSets: nil, targetWeight: nil, targetReps: nil, state: .pending(number: 5))
    }
    .padding(20)
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
}
