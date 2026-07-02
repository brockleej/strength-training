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
                .foregroundStyle(Color.uplift.weightTint)
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

/// Swipe-left-to-reveal-delete for rows living inside a card (outside a List).
/// A left drag reveals a tappable trash button; the delete only commits on
/// tap (reveal-then-tap — prevents accidental full-swipe deletions mid-workout).
/// Vertical-dominant drags are ignored so the enclosing ScrollView keeps them.
private struct SwipeToDeleteModifier: ViewModifier {
    let onDelete: () -> Void

    @State private var offsetX: CGFloat = 0
    @State private var isRevealed = false
    private let revealWidth: CGFloat = 64

    func body(content: Content) -> some View {
        content
            .offset(x: offsetX)
            .background(alignment: .trailing) {
                if offsetX < -4 {
                    Button {
                        close()
                        onDelete()   // haptic fires inside WorkoutViewModel.deleteSet
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.uplift.down)
                            .frame(width: revealWidth, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .opacity(min(1, Double(offsetX / -revealWidth)))
                    .accessibilityLabel("Delete set")
                }
            }
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        // Horizontal-dominant drags only — vertical stays with the scroll
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        let base: CGFloat = isRevealed ? -revealWidth : 0
                        offsetX = min(0, max(-revealWidth, base + value.translation.width))
                    }
                    .onEnded { value in
                        withAnimation(.easeOut(duration: 0.2)) {
                            if !isRevealed, value.translation.width < -revealWidth / 2 {
                                isRevealed = true
                                offsetX = -revealWidth
                            } else if isRevealed, value.translation.width > revealWidth / 2 {
                                close()
                            } else {
                                offsetX = isRevealed ? -revealWidth : 0
                            }
                        }
                    }
            )
            .onTapGesture {
                if isRevealed {
                    withAnimation(.easeOut(duration: 0.2)) { close() }
                }
            }
            .accessibilityAction(named: "Delete") { onDelete() }
    }

    private func close() {
        isRevealed = false
        offsetX = 0
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
