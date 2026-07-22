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
        content
            .offset(x: offsetX)
            .background(alignment: .trailing) {
                if offsetX < -4 {
                    Button {
                        commitDelete()
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: revealWidth, height: 44)
                            .frame(maxHeight: .infinity)
                            .background(Color.uplift.down)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .opacity(min(1, Double(offsetX / -revealWidth)))
                    .accessibilityLabel("Remove")
                }
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
            .onTapGesture {
                if isRevealed {
                    withAnimation(.easeOut(duration: 0.2)) { close() }
                } else {
                    onTap?()
                }
            }
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

extension View {
    /// Soft remove: swipe reveals trash; tap to confirm (unless fullSwipeDeletes).
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
