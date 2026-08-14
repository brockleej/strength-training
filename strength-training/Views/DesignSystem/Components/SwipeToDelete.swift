//
//  SwipeToDelete.swift
//  strength-training
//
//  Horizontal swipe-to-remove. Default is reveal-then-tap (safer; matches
//  global list-mutation rules). fullSwipeDeletes is opt-in only.
//

import SwiftUI

struct SwipeToDeleteModifier: ViewModifier {
    let onDelete: () -> Void
    var onTap: (() -> Void)? = nil
    /// If true, a strong swipe past the threshold commits delete immediately.
    /// Global default is false (reveal trash, then tap).
    var fullSwipeDeletes: Bool = false

    @State private var offsetX: CGFloat = 0
    @State private var isRevealed = false
    private let revealWidth: CGFloat = 72

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            // Sibling of the row (not a background) so the trash stays tappable.
            if offsetX < -4 {
                Button {
                    commitDelete()
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: revealWidth)
                        .frame(maxHeight: .infinity)
                        .background(Color.uplift.down)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(min(1, Double(-offsetX / revealWidth)))
                .accessibilityLabel("Remove")
            }

            content
                .offset(x: offsetX)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .simultaneousGesture(
            DragGesture(minimumDistance: 16, coordinateSpace: .local)
                .onChanged { value in
                    // Horizontal-dominant only — leave vertical to the list.
                    guard abs(value.translation.width) > abs(value.translation.height) * 1.1
                    else { return }
                    let base: CGFloat = isRevealed ? -revealWidth : 0
                    let next = base + value.translation.width
                    // Allow a bit past reveal for full-swipe feel.
                    offsetX = min(0, max(-revealWidth * 1.6, next))
                }
                .onEnded { value in
                    let base: CGFloat = isRevealed ? -revealWidth : 0
                    let projected = base + value.translation.width
                    withAnimation(.easeOut(duration: 0.2)) {
                        if fullSwipeDeletes, projected < -revealWidth * 1.25 {
                            commitDelete()
                        } else if projected < -revealWidth / 2 {
                            isRevealed = true
                            offsetX = -revealWidth
                        } else {
                            close()
                        }
                    }
                }
        )
        // Close overlay covers the row only — trailing `revealWidth` stays on the trash.
        .overlay {
            if isRevealed {
                Color.clear
                    .padding(.trailing, revealWidth)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) { close() }
                    }
            }
        }
        .modifier(SwipeOptionalTap(onTap: onTap, isRevealed: isRevealed, onClose: {
            withAnimation(.easeOut(duration: 0.2)) { close() }
        }))
        .accessibilityAction(named: "Remove") { onDelete() }
    }

    private func commitDelete() {
        close()
        onDelete()
    }

    private func close() {
        isRevealed = false
        offsetX = 0
    }
}

/// Only attaches a tap handler when `onTap` is provided (and not while revealed).
private struct SwipeOptionalTap: ViewModifier {
    let onTap: (() -> Void)?
    let isRevealed: Bool
    let onClose: () -> Void

    func body(content: Content) -> some View {
        if let onTap, !isRevealed {
            content.onTapGesture(perform: onTap)
        } else {
            content
        }
    }
}

extension View {
    /// Soft remove: swipe reveals trash; tap to confirm (unless fullSwipeDeletes).
    /// When `onTap` is nil, taps pass through (e.g. to a NavigationLink).
    func swipeToDelete(
        fullSwipeDeletes: Bool = false,
        onDelete: @escaping () -> Void,
        onTap: (() -> Void)? = nil
    ) -> some View {
        modifier(SwipeToDeleteModifier(
            onDelete: onDelete,
            onTap: onTap,
            fullSwipeDeletes: fullSwipeDeletes
        ))
    }
}
