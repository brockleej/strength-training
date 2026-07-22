//
//  ExerciseListRow.swift
//  strength-training
//

import SwiftUI

/// One exercise in the in-workout overview list.
/// pending = numbered circle · active (last-visited) = accent dress · completed = check + strikethrough.
///
/// Secondary line shows either last-session recipe or progression target;
/// parent owns the shared toggle (tap the line to flip).
struct ExerciseListRow: View {
    enum RowState: Equatable {
        case pending(number: Int)
        case active
        case completed
    }

    enum SecondaryMode: String {
        case recipe
        case target
    }

    let name: String
    let state: RowState
    var trackBadge: String? = nil
    /// Compact last-session recipe, e.g. "135×5 · 225×4 · 305×5".
    var lastSessionSummary: String? = nil
    var targetWeight: Double? = nil
    var targetReps: Int? = nil
    var secondaryMode: SecondaryMode = .recipe
    var onToggleSecondary: (() -> Void)? = nil

    private var isActive: Bool { state == .active }
    private var isCompleted: Bool { state == .completed }

    var body: some View {
        HStack(spacing: 12) {
            statusCircle
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.uplift.text(15, weight: .semibold))
                        .kerning(-0.2)
                        .foregroundStyle(Color.uplift.fg)
                        .strikethrough(isCompleted, color: Color.uplift.fgDim)
                    if let trackBadge {
                        Text(trackBadge)
                            .font(.uplift.text(10, weight: .bold))
                            .foregroundStyle(Color.uplift.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.uplift.accent.opacity(0.16)))
                    }
                }
                secondaryLine
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var secondaryLine: some View {
        let content = secondaryContent
        secondaryLabel(content)
            .contentShape(Rectangle())
            .accessibilityLabel(content.accessibility)
            .accessibilityHint(
                onToggleSecondary == nil
                    ? ""
                    : (secondaryMode == .recipe
                        ? "Shows last session. Activate to show progression target."
                        : "Shows progression target. Activate to show last session.")
            )
            .accessibilityAddTraits(onToggleSecondary == nil ? [] : .isButton)
            // highPriorityGesture wins over parent NavigationLink for this strip only.
            .highPriorityGesture(
                TapGesture().onEnded {
                    onToggleSecondary?()
                }
            )
    }

    private func secondaryLabel(_ content: SecondaryContent) -> some View {
        HStack(spacing: 6) {
            if content.hasContent {
                Text(content.modeLabel)
                    .font(.uplift.text(10, weight: .semibold))
                    .foregroundStyle(Color.uplift.fgDim)
                    .textCase(.uppercase)
                    .tracking(0.3)
            }
            Group {
                if let attributed = content.attributed {
                    attributed
                } else {
                    Text(content.plain ?? "—")
                        .foregroundStyle(Color.uplift.fgMuted)
                }
            }
            .font(.uplift.mono(12, weight: .medium))
            .lineLimit(2)
            .minimumScaleFactor(0.85)
        }
    }

    private struct SecondaryContent {
        var plain: String?
        var attributed: Text?
        var modeLabel: String
        var accessibility: String
        var hasContent: Bool
    }

    private var secondaryContent: SecondaryContent {
        switch secondaryMode {
        case .recipe:
            if let lastSessionSummary, !lastSessionSummary.isEmpty {
                return SecondaryContent(
                    plain: lastSessionSummary,
                    attributed: Text(lastSessionSummary).foregroundColor(.uplift.fgMuted),
                    modeLabel: "Last",
                    accessibility: "Last session \(lastSessionSummary)",
                    hasContent: true
                )
            }
            // No recipe — fall back to target if available
            return targetContent(modeLabel: "Target", emptyFallback: true)
        case .target:
            return targetContent(modeLabel: "Target", emptyFallback: false)
        }
    }

    private func targetContent(modeLabel: String, emptyFallback: Bool) -> SecondaryContent {
        if targetWeight == nil && targetReps == nil {
            if emptyFallback {
                return SecondaryContent(
                    plain: "—",
                    attributed: Text("—").foregroundColor(.uplift.fgMuted),
                    modeLabel: "",
                    accessibility: "No history",
                    hasContent: false
                )
            }
            // No target: show recipe if we have it when toggled to target
            if let lastSessionSummary, !lastSessionSummary.isEmpty {
                return SecondaryContent(
                    plain: lastSessionSummary,
                    attributed: Text(lastSessionSummary).foregroundColor(.uplift.fgMuted),
                    modeLabel: "Last",
                    accessibility: "Last session \(lastSessionSummary)",
                    hasContent: true
                )
            }
            return SecondaryContent(
                plain: "—",
                attributed: Text("—").foregroundColor(.uplift.fgMuted),
                modeLabel: "",
                accessibility: "No target",
                hasContent: false
            )
        }

        let attributed: Text
        let a11y: String
        if let targetWeight, let targetReps {
            attributed = PairText.pair(
                weight: targetWeight,
                reps: targetReps,
                font: .uplift.mono(12, weight: .medium)
            )
            a11y = "Target \(StepperLogic.format(targetWeight)) pounds by \(targetReps)"
        } else if let targetReps {
            attributed = Text("\(targetReps)").foregroundColor(.uplift.repsTint)
            a11y = "Target \(targetReps) reps"
        } else if let targetWeight {
            attributed = Text(StepperLogic.format(targetWeight)).foregroundColor(.uplift.weightTint)
            a11y = "Target \(StepperLogic.format(targetWeight)) pounds"
        } else {
            attributed = Text("—").foregroundColor(.uplift.fgMuted)
            a11y = "No target"
        }
        return SecondaryContent(
            plain: nil,
            attributed: attributed,
            modeLabel: modeLabel,
            accessibility: a11y,
            hasContent: true
        )
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
        return "\(name), \(secondaryContent.accessibility), \(stateText)"
    }
}

#Preview("ExerciseListRow") {
    VStack(spacing: 8) {
        ExerciseListRow(
            name: "Back Squat",
            state: .completed,
            lastSessionSummary: "135×5 · 225×4 · 305×5",
            targetWeight: 310,
            targetReps: 5,
            secondaryMode: .recipe
        )
        ExerciseListRow(
            name: "Walking Lunge",
            state: .active,
            lastSessionSummary: "40×12 · 40×12",
            targetWeight: 45,
            targetReps: 12,
            secondaryMode: .target
        )
        ExerciseListRow(
            name: "Nordic Curl",
            state: .pending(number: 5),
            secondaryMode: .recipe
        )
    }
    .padding(20)
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
}
