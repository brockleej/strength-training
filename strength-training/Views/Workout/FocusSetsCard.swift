//
//  FocusSetsCard.swift
//  strength-training
//

import SwiftUI

/// Logged-sets table for the Focus screen: SET | WEIGHT | REPS header, one
/// mono row per set. Tap a row to edit in the steppers; swipe-left to delete.
struct FocusSetsCard: View {
    let sets: [SetRecord]              // sorted ascending by setNumber
    var selectedSetID: UUID? = nil
    let onSelect: (SetRecord) -> Void
    let onDelete: (SetRecord) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            if sets.isEmpty {
                Text("No sets yet")
                    .font(.uplift.text(13, weight: .medium))
                    .foregroundStyle(Color.uplift.fgDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else {
                Text(ListMutationCopy.setsSwipe)
                    .font(.uplift.text(11, weight: .medium))
                    .foregroundStyle(Color.uplift.fgDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 6)

                ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                    row(set)
                    if index < sets.count - 1 {
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
        HStack {
            Text("SET")
            Spacer()
            Text("WEIGHT").frame(width: 64, alignment: .trailing)
            Text("REPS").frame(width: 48, alignment: .trailing)
        }
        .font(.uplift.text(11, weight: .bold))
        .tracking(0.4)
        .foregroundStyle(Color.uplift.fgMuted)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.uplift.hairline).frame(height: 0.5)
        }
    }

    private func row(_ set: SetRecord) -> some View {
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
            if set.isWarmup {
                Text("W")
                    .font(.uplift.text(10, weight: .bold))
                    .foregroundStyle(Color.uplift.customBadge)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.uplift.customBadge.opacity(0.16)))
            }
            if set.isEachSide {
                Text("EA")
                    .font(.uplift.text(10, weight: .bold))
                    .foregroundStyle(Color.uplift.accent)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.uplift.accent.opacity(0.16)))
            }
            if set.isAssisted {
                Text("A")
                    .font(.uplift.text(10, weight: .bold))
                    .foregroundStyle(Color.uplift.legsInk)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.uplift.legsInk.opacity(0.16)))
            }
            Text(set.weightDisplay)
                .font(.uplift.mono(14, weight: .semibold))
                .foregroundStyle(Color.uplift.weightTint)
                .frame(width: 64, alignment: .trailing)
            Text(set.isEachSide ? "\(set.reps)×2" : "\(set.reps)")
                .font(.uplift.mono(14, weight: .semibold))
                .foregroundStyle(Color.uplift.fg)
                .frame(width: 52, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.uplift.accent.opacity(0.10) : Color.clear)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(setAccessibilityLabel(set, isSelected: isSelected))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        // Focus sets: reveal-then-tap (safer mid-workout than full-swipe commit).
        .swipeToDelete(fullSwipeDeletes: false, onDelete: { onDelete(set) }, onTap: { onSelect(set) })
    }

    private func setAccessibilityLabel(_ set: SetRecord, isSelected: Bool) -> String {
        let weightPart: String
        if set.isAssisted {
            weightPart = "\(StepperLogic.format(set.weightLbs)) pounds assistance"
        } else {
            weightPart = "\(StepperLogic.format(set.weightLbs)) pounds"
        }
        var parts = [
            "Set \(set.setNumber)",
            isSelected ? "editing" : nil,
            weightPart,
            set.isEachSide ? "\(set.reps) reps each side" : "\(set.reps) reps",
            set.isWarmup ? "warmup" : nil,
            isSelected ? "double tap to cancel" : "double tap to edit",
        ].compactMap { $0 }
        return parts.joined(separator: ", ")
    }
}

#Preview("FocusSetsCard") {
    VStack(spacing: 16) {
        FocusSetsCard(
            sets: {
                let a = SetRecord(setNumber: 1, weightLbs: 225, reps: 5)
                let b = SetRecord(setNumber: 2, weightLbs: 225, reps: 5)
                let c = SetRecord(setNumber: 3, weightLbs: 230, reps: 3)
                return [a, b, c]
            }(),
            selectedSetID: nil,
            onSelect: { _ in },
            onDelete: { _ in }
        )
        FocusSetsCard(sets: [], onSelect: { _ in }, onDelete: { _ in })
    }
    .padding(20)
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
}
