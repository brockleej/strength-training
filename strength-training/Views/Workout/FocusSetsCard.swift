//
//  FocusSetsCard.swift
//  strength-training
//

import SwiftUI

/// Logged-sets table for the Focus screen. Each row can show last session’s
/// matching set (dim) beside this session’s set. Deltas sit as superscripts
/// next to weight or reps on the this-session numbers.
struct FocusSetsCard: View {
    struct PreviousSet: Equatable {
        let weight: Double
        let reps: Int
        let isWarmup: Bool
        var isEachSide: Bool = false
        var isAssisted: Bool = false
    }

    let sets: [SetRecord]              // sorted ascending by setNumber
    /// Prior session sets aligned by order (index 0 = set 1). Longer than
    /// `sets` when you haven’t matched last time’s volume yet.
    var previousSets: [PreviousSet] = []
    var previousDateLabel: String? = nil
    var selectedSetID: UUID? = nil
    var onSelect: (SetRecord) -> Void = { _ in }
    var onDelete: (SetRecord) -> Void = { _ in }
    /// Load a previous set into steppers (weight, reps, warmup, eachSide, assisted).
    var onSelectPrevious: ((PreviousSet) -> Void)? = nil

    private var rowCount: Int {
        max(sets.count, previousSets.count, sets.isEmpty && previousSets.isEmpty ? 0 : 1)
    }

    private var showPreviousColumn: Bool { !previousSets.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            header
            if sets.isEmpty && previousSets.isEmpty {
                Text("No sets yet")
                    .font(.uplift.text(13, weight: .medium))
                    .foregroundStyle(Color.uplift.fgDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else {
                if !sets.isEmpty {
                    Text(ListMutationCopy.setsSwipe)
                        .font(.uplift.text(11, weight: .medium))
                        .foregroundStyle(Color.uplift.fgDim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 6)
                }

                ForEach(0..<rowCount, id: \.self) { index in
                    let thisSet = index < sets.count ? sets[index] : nil
                    let prev = index < previousSets.count ? previousSets[index] : nil
                    row(index: index, thisSet: thisSet, previous: prev)
                    if index < rowCount - 1 {
                        Rectangle()
                            .fill(Color.uplift.hairline)
                            .frame(height: 0.5)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.uplift.surface1)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("SET")
                .frame(width: 44, alignment: .leading)
            if showPreviousColumn {
                VStack(alignment: .leading, spacing: 1) {
                    Text("LAST")
                    if let previousDateLabel {
                        Text(previousDateLabel)
                            .font(.uplift.text(9, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                            .lineLimit(1)
                    }
                }
                .frame(width: 88, alignment: .leading)
                Text("THIS")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                Spacer()
                Text("WEIGHT").frame(width: 64, alignment: .trailing)
                Text("REPS").frame(width: 48, alignment: .trailing)
            }
        }
        .font(.uplift.text(11, weight: .bold))
        .tracking(0.4)
        .foregroundStyle(Color.uplift.fgMuted)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.uplift.hairline).frame(height: 0.5)
        }
    }

    @ViewBuilder
    private func row(index: Int, thisSet: SetRecord?, previous: PreviousSet?) -> some View {
        if showPreviousColumn {
            comparisonRow(index: index, thisSet: thisSet, previous: previous)
        } else if let thisSet {
            simpleRow(thisSet)
        }
    }

    private func comparisonRow(index: Int, thisSet: SetRecord?, previous: PreviousSet?) -> some View {
        let hasLoggedSet = thisSet != nil
        let isSelected = thisSet.map { selectedSetID == $0.id } ?? false
        return HStack(spacing: 10) {
            // Set number + status
            HStack(spacing: 6) {
                if hasLoggedSet {
                    ZStack {
                        Circle().fill(
                            isSelected
                                ? Color.uplift.accent.opacity(0.22)
                                : Color.uplift.up.opacity(0.18)
                        )
                        Image(systemName: isSelected ? "pencil" : "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(isSelected ? Color.uplift.accent : Color.uplift.up)
                    }
                    .frame(width: 22, height: 22)
                } else {
                    Circle()
                        .strokeBorder(Color.uplift.hairline, lineWidth: 1)
                        .frame(width: 22, height: 22)
                }
                Text("\(index + 1)")
                    .font(.uplift.mono(15, weight: .bold))
                    .foregroundStyle(Color.uplift.fg)
            }
            .frame(width: 44, alignment: .leading)

            // Last — compact, muted, tap to load
            if let previous {
                Button {
                    onSelectPrevious?(previous)
                } label: {
                    HStack(spacing: 3) {
                        lastPairLabel(previous)
                        Image(systemName: "arrow.down.left")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(Color.uplift.fgFaint)
                    }
                    .frame(width: 88, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Load last set \(index + 1) into steppers")
            } else {
                Text("—")
                    .font(.uplift.mono(12, weight: .medium))
                    .foregroundStyle(Color.uplift.fgFaint)
                    .frame(width: 88, alignment: .leading)
            }

            Spacer(minLength: 4)

            // This — prominent weight × reps with inline superscript deltas
            if let logged = thisSet {
                thisPairLabel(thisSet: logged, previous: previous)
            } else {
                Text("·")
                    .font(.uplift.mono(16, weight: .medium))
                    .foregroundStyle(Color.uplift.fgDim)
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 4)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.uplift.accent.opacity(0.10) : Color.clear)
        }
        .contentShape(Rectangle())
        .modifier(OptionalSwipe(
            enabled: hasLoggedSet,
            onDelete: {
                guard let logged = thisSet else { return }
                onDelete(logged)
            },
            onTap: {
                guard let logged = thisSet else { return }
                onSelect(logged)
            }
        ))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(comparisonA11y(index: index, thisSet: thisSet, previous: previous, isSelected: isSelected))
    }

    private func simpleRow(_ set: SetRecord) -> some View {
        let isSelected = selectedSetID == set.id
        return HStack {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(
                        isSelected
                            ? Color.uplift.accent.opacity(0.22)
                            : Color.uplift.up.opacity(0.16)
                    )
                    Image(systemName: isSelected ? "pencil" : "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isSelected ? Color.uplift.accent : Color.uplift.up)
                }
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)
                Text("\(set.setNumber)")
                    .font(.uplift.mono(14, weight: .semibold))
                    .foregroundStyle(Color.uplift.fg)
            }
            Spacer()
            flagChips(warmup: set.isWarmup, eachSide: set.isEachSide, assisted: set.isAssisted)
            Text(set.weightDisplay)
                .font(.uplift.mono(14, weight: .semibold))
                .foregroundStyle(Color.uplift.weightTint)
                .frame(width: 64, alignment: .trailing)
            Text(set.isEachSide ? "\(set.reps)×2" : "\(set.reps)")
                .font(.uplift.mono(14, weight: .semibold))
                .foregroundStyle(Color.uplift.repsTint)
                .frame(width: 52, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.uplift.accent.opacity(0.10) : Color.clear)
        }
        .contentShape(Rectangle())
        .swipeToDelete(fullSwipeDeletes: false, onDelete: { onDelete(set) }, onTap: { onSelect(set) })
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(setAccessibilityLabel(set, isSelected: isSelected))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// Compact muted last-session pair.
    private func lastPairLabel(_ previous: PreviousSet) -> some View {
        let wText = previous.isAssisted
            ? "−\(StepperLogic.format(previous.weight))"
            : StepperLogic.format(previous.weight)
        let rText = previous.isEachSide ? "\(previous.reps)×2" : "\(previous.reps)"
        return HStack(spacing: 2) {
            Text("\(wText)×\(rText)")
                .font(.uplift.mono(12, weight: .medium))
                .foregroundStyle(Color.uplift.fgDim)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if previous.isWarmup {
                Text("W")
                    .font(.uplift.text(8, weight: .bold))
                    .foregroundStyle(Color.uplift.customBadge.opacity(0.8))
            }
        }
    }

    /// Prominent this-session weight × reps; deltas as superscripts on the changed metric.
    private func thisPairLabel(thisSet: SetRecord, previous: PreviousSet?) -> some View {
        let wText = thisSet.weightDisplay
        let rText = thisSet.isEachSide ? "\(thisSet.reps)×2" : "\(thisSet.reps)"

        let wDelta: Double?
        let rDelta: Int?
        if let previous, !thisSet.isWarmup, !previous.isWarmup {
            let w = thisSet.weightLbs - previous.weight
            let r = thisSet.reps - previous.reps
            wDelta = abs(w) >= 0.05 ? w : nil
            rDelta = r != 0 ? r : nil
        } else {
            wDelta = nil
            rDelta = nil
        }

        return HStack(alignment: .firstTextBaseline, spacing: 3) {
            // Weight + optional weight Δ superscript
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(wText)
                    .font(.uplift.mono(17, weight: .bold))
                    .foregroundStyle(Color.uplift.weightTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let wDelta {
                    superscriptDelta(weight: wDelta)
                }
            }

            Text("×")
                .font(.uplift.mono(14, weight: .semibold))
                .foregroundStyle(Color.uplift.fgDim)

            // Reps + optional reps Δ superscript
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(rText)
                    .font(.uplift.mono(17, weight: .bold))
                    .foregroundStyle(Color.uplift.repsTint)
                if let rDelta {
                    superscriptDelta(reps: rDelta)
                }
            }

            if thisSet.isWarmup {
                Text("W")
                    .font(.uplift.text(9, weight: .bold))
                    .foregroundStyle(Color.uplift.customBadge)
                    .padding(.leading, 2)
            }
            if thisSet.isAssisted {
                Text("A")
                    .font(.uplift.text(9, weight: .bold))
                    .foregroundStyle(Color.uplift.legsInk)
            }
            if thisSet.isEachSide {
                Text("EA")
                    .font(.uplift.text(9, weight: .bold))
                    .foregroundStyle(Color.uplift.accent)
            }
        }
    }

    private func superscriptDelta(weight: Double) -> some View {
        let text = weight > 0
            ? "⁺\(StepperLogic.format(weight))"
            : "⁻\(StepperLogic.format(abs(weight)))"
        return Text(text)
            .font(.uplift.mono(10, weight: .bold))
            .foregroundStyle(weight > 0 ? Color.uplift.up : Color.uplift.down)
            .baselineOffset(7)
            .accessibilityLabel("Weight \(weight > 0 ? "up" : "down") \(StepperLogic.format(abs(weight)))")
    }

    private func superscriptDelta(reps: Int) -> some View {
        let text = reps > 0 ? "⁺\(reps)" : "⁻\(abs(reps))"
        return Text(text)
            .font(.uplift.mono(10, weight: .bold))
            .foregroundStyle(reps > 0 ? Color.uplift.up : Color.uplift.down)
            .baselineOffset(7)
            .accessibilityLabel("Reps \(reps > 0 ? "up" : "down") \(abs(reps))")
    }

    @ViewBuilder
    private func flagChips(warmup: Bool, eachSide: Bool, assisted: Bool) -> some View {
        if warmup {
            Text("W")
                .font(.uplift.text(10, weight: .bold))
                .foregroundStyle(Color.uplift.customBadge)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.uplift.customBadge.opacity(0.16)))
        }
        if eachSide {
            Text("EA")
                .font(.uplift.text(10, weight: .bold))
                .foregroundStyle(Color.uplift.accent)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.uplift.accent.opacity(0.16)))
        }
        if assisted {
            Text("A")
                .font(.uplift.text(10, weight: .bold))
                .foregroundStyle(Color.uplift.legsInk)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.uplift.legsInk.opacity(0.16)))
        }
    }

    private func setAccessibilityLabel(_ set: SetRecord, isSelected: Bool) -> String {
        let weightPart: String
        if set.isAssisted {
            weightPart = "\(StepperLogic.format(set.weightLbs)) pounds assistance"
        } else {
            weightPart = "\(StepperLogic.format(set.weightLbs)) pounds"
        }
        let parts = [
            "Set \(set.setNumber)",
            isSelected ? "editing" : nil,
            weightPart,
            set.isEachSide ? "\(set.reps) reps each side" : "\(set.reps) reps",
            set.isWarmup ? "warmup" : nil,
            isSelected ? "double tap to cancel" : "double tap to edit",
        ].compactMap { $0 }
        return parts.joined(separator: ", ")
    }

    private func comparisonA11y(index: Int, thisSet: SetRecord?, previous: PreviousSet?, isSelected: Bool) -> String {
        var parts = ["Set \(index + 1)"]
        if let previous {
            parts.append("last \(StepperLogic.format(previous.weight)) by \(previous.reps)")
        }
        if let thisSet {
            parts.append("this \(thisSet.weightDisplay) by \(thisSet.reps)")
            if isSelected { parts.append("editing") }
            if let previous, !thisSet.isWarmup, !previous.isWarmup {
                let w = thisSet.weightLbs - previous.weight
                let r = thisSet.reps - previous.reps
                if abs(w) >= 0.05 {
                    parts.append("weight \(w > 0 ? "up" : "down") \(StepperLogic.format(abs(w)))")
                }
                if r != 0 {
                    parts.append("reps \(r > 0 ? "up" : "down") \(abs(r))")
                }
            }
        } else {
            parts.append("not logged yet")
        }
        return parts.joined(separator: ", ")
    }
}

/// Applies swipe-to-delete only when a this-session set exists on the row.
private struct OptionalSwipe: ViewModifier {
    let enabled: Bool
    let onDelete: () -> Void
    let onTap: () -> Void

    func body(content: Content) -> some View {
        if enabled {
            content.swipeToDelete(fullSwipeDeletes: false, onDelete: onDelete, onTap: onTap)
        } else {
            content
        }
    }
}

#Preview("FocusSetsCard comparison") {
    FocusSetsCard(
        sets: {
            let a = SetRecord(setNumber: 1, weightLbs: 230, reps: 5)
            let b = SetRecord(setNumber: 2, weightLbs: 225, reps: 6)
            let c = SetRecord(setNumber: 3, weightLbs: 225, reps: 5)
            return [a, b, c]
        }(),
        previousSets: [
            .init(weight: 225, reps: 5, isWarmup: false),
            .init(weight: 225, reps: 5, isWarmup: false),
            .init(weight: 225, reps: 5, isWarmup: false),
        ],
        previousDateLabel: "3d ago",
        selectedSetID: nil
    )
    .padding(20)
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
}
