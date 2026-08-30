//
//  SwipeToDelete.swift
//  strength-training
//
//  Horizontal swipe-to-remove. Default is reveal-then-tap (safer; matches
//  global list-mutation rules). fullSwipeDeletes is opt-in only.
//

import SwiftUI

/// Hit-zone and swipe-end rules for `SwipeToDeleteModifier`.
/// Extracted so the trash strip cannot be “covered” by a full-row close overlay.
enum SwipeToDeleteLogic {
    static let revealWidth: CGFloat = 72

    enum HitZone: Equatable {
        /// Sliding row — tap edits, or closes when already revealed.
        case row
        /// Trailing trash — tap must delete, never dismiss.
        case trash
    }

    enum EndAction: Equatable {
        case close
        case reveal
        case delete
    }

    /// Local x in the row bounds. Trailing `revealWidth` is trash once revealed.
    static func hitZone(x: CGFloat, rowWidth: CGFloat, isRevealed: Bool) -> HitZone {
        guard isRevealed, rowWidth > revealWidth else { return .row }
        return x >= rowWidth - revealWidth ? .trash : .row
    }

    static func endAction(projectedOffset: CGFloat, fullSwipeDeletes: Bool) -> EndAction {
        if fullSwipeDeletes, projectedOffset < -revealWidth * 1.25 {
            return .delete
        }
        if projectedOffset < -revealWidth / 2 {
            return .reveal
        }
        return .close
    }
}

struct SwipeToDeleteModifier: ViewModifier {
    let onDelete: () -> Void
    var onTap: (() -> Void)? = nil
    /// If true, a strong swipe past the threshold commits delete immediately.
    /// Global default is false (reveal trash, then tap).
    var fullSwipeDeletes: Bool = false
    var isEnabled: Bool = true

    @State private var offsetX: CGFloat = 0
    @State private var isRevealed = false

    private var revealWidth: CGFloat { SwipeToDeleteLogic.revealWidth }

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            content
                .offset(x: offsetX)
                // Drag on the row only. A parent DragGesture eats the trash tap.
                .simultaneousGesture(dragGesture)
                .modifier(SwipeOptionalTap(onTap: onTap, isRevealed: isRevealed, onClose: {
                    withAnimation(.easeOut(duration: 0.2)) { close() }
                }))

            // Last sibling so it wins hit-testing. Do not wrap this ZStack in an
            // overlay — `.contentShape` after trailing padding covers the trash
            // and the tap closes the swipe instead of deleting.
            if offsetX < -4 {
                trashControl
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityAction(named: "Remove") { onDelete() }
    }

    private var trashControl: some View {
        Image(systemName: "trash.fill")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: revealWidth)
            .frame(maxHeight: .infinity)
            .background(Color.uplift.down)
            .contentShape(Rectangle())
            .opacity(min(1, Double(-offsetX / revealWidth)))
            .highPriorityGesture(TapGesture().onEnded { commitDelete() })
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Remove")
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 16, coordinateSpace: .local)
            .onChanged { value in
                guard isEnabled else { return }
                // Horizontal-dominant only — leave vertical to the list / reorder.
                guard abs(value.translation.width) > abs(value.translation.height) * 1.2
                else { return }
                let base: CGFloat = isRevealed ? -revealWidth : 0
                let next = base + value.translation.width
                // Allow a bit past reveal for full-swipe feel.
                offsetX = min(0, max(-revealWidth * 1.6, next))
            }
            .onEnded { value in
                guard isEnabled else {
                    close()
                    return
                }
                let base: CGFloat = isRevealed ? -revealWidth : 0
                let projected = base + value.translation.width
                withAnimation(.easeOut(duration: 0.2)) {
                    switch SwipeToDeleteLogic.endAction(
                        projectedOffset: projected,
                        fullSwipeDeletes: fullSwipeDeletes
                    ) {
                    case .delete:
                        commitDelete()
                    case .reveal:
                        isRevealed = true
                        offsetX = -revealWidth
                    case .close:
                        close()
                    }
                }
            }
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

/// Tap on the sliding row: edit when closed, dismiss when revealed.
/// Never attached to a full-width overlay — that steals the trash tap.
private struct SwipeOptionalTap: ViewModifier {
    let onTap: (() -> Void)?
    let isRevealed: Bool
    let onClose: () -> Void

    func body(content: Content) -> some View {
        if isRevealed {
            content.onTapGesture(perform: onClose)
        } else if let onTap {
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
        isEnabled: Bool = true,
        onDelete: @escaping () -> Void,
        onTap: (() -> Void)? = nil
    ) -> some View {
        modifier(SwipeToDeleteModifier(
            onDelete: onDelete,
            onTap: onTap,
            fullSwipeDeletes: fullSwipeDeletes,
            isEnabled: isEnabled
        ))
    }
}
