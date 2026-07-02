//
//  FocusSetsCard.swift
//  strength-training
//

import SwiftUI

/// Logged-sets table for the Focus screen: SET | WEIGHT | REPS header, one
/// mono row per set, swipe-left to delete. Shows only logged sets — the
/// steppers + Log set button below carry the "next set".
struct FocusSetsCard: View {
    let sets: [SetRecord]              // sorted ascending by setNumber
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
        HStack {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(Color.uplift.up.opacity(0.16))
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.uplift.up)
                }
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)
                Text("\(set.setNumber)")
                    .font(.uplift.mono(14, weight: .semibold))
                    .foregroundStyle(Color.uplift.fg)
            }
            Spacer()
            Text(StepperLogic.format(set.weightLbs))
                .font(.uplift.mono(14, weight: .semibold))
                .foregroundStyle(Color.uplift.fg)
                .frame(width: 64, alignment: .trailing)
            Text("\(set.reps)")
                .font(.uplift.mono(14, weight: .semibold))
                .foregroundStyle(Color.uplift.fg)
                .frame(width: 48, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Set \(set.setNumber), \(StepperLogic.format(set.weightLbs)) pounds, \(set.reps) reps")
        .swipeToDelete { onDelete(set) }
    }
}

/// Swipe-left-to-delete for rows living inside a card (outside a List).
/// Drag past the threshold reveals a destructive zone; release deletes.
private struct SwipeToDeleteModifier: ViewModifier {
    let onDelete: () -> Void

    @State private var offsetX: CGFloat = 0
    private let threshold: CGFloat = -72

    func body(content: Content) -> some View {
        content
            .offset(x: offsetX)
            .background(alignment: .trailing) {
                if offsetX < -4 {
                    HStack {
                        Spacer()
                        Image(systemName: "trash.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.uplift.down)
                            .padding(.trailing, 16)
                    }
                    .opacity(min(1, Double(-offsetX / -threshold)))
                }
            }
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        // Horizontal-dominant left drags only
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        offsetX = min(0, value.translation.width)
                    }
                    .onEnded { value in
                        if value.translation.width <= threshold {
                            onDelete()
                        }
                        withAnimation(.easeOut(duration: 0.2)) { offsetX = 0 }
                    }
            )
            .accessibilityAction(named: "Delete") { onDelete() }
    }
}

extension View {
    func swipeToDelete(onDelete: @escaping () -> Void) -> some View {
        modifier(SwipeToDeleteModifier(onDelete: onDelete))
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
            onDelete: { _ in }
        )
        FocusSetsCard(sets: [], onDelete: { _ in })
    }
    .padding(20)
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
}
