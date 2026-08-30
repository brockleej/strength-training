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

    enum TapAction: Equatable {
        case delete
        case close
        case edit
        case ignore
    }

    /// Location-based tap routing. Sibling trash controls lose to ScrollView
    /// on device; the row itself must dispatch trash vs close vs edit.
    static func tapAction(
        x: CGFloat,
        rowWidth: CGFloat,
        isRevealed: Bool,
        hasEditAction: Bool
    ) -> TapAction {
        switch hitZone(x: x, rowWidth: rowWidth, isRevealed: isRevealed) {
        case .trash:
            return .delete
        case .row:
            if isRevealed { return .close }
            return hasEditAction ? .edit : .ignore
        }
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
    @State private var rowWidth: CGFloat = 0

    private var revealWidth: CGFloat { SwipeToDeleteLogic.revealWidth }

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            // Visual only. Taps are dispatched on the container via hitZone so a
            // ScrollView / sibling overlay cannot swallow the trash.
            if offsetX < -4 {
                trashControl
            }

            content
                .offset(x: offsetX)
        }
        .contentShape(Rectangle())
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { _, width in
            rowWidth = width
        }
        .simultaneousGesture(dragGesture)
        .modifier(SwipeRowTap(
            isEnabled: isEnabled && (isRevealed || onTap != nil),
            onTap: { location in
                handleTap(x: location.x)
            }
        ))
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
            .opacity(min(1, Double(-offsetX / revealWidth)))
            .accessibilityHidden(true)
    }

    private func handleTap(x: CGFloat) {
        guard isEnabled else { return }
        switch SwipeToDeleteLogic.tapAction(
            x: x,
            rowWidth: rowWidth,
            isRevealed: isRevealed,
            hasEditAction: onTap != nil
        ) {
        case .delete:
            commitDelete()
        case .close:
            withAnimation(.easeOut(duration: 0.2)) { close() }
        case .edit:
            onTap?()
        case .ignore:
            break
        }
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

/// Location-based tap on the swipe container. Used instead of a sibling
/// trash control so ScrollView cannot swallow the trailing strip.
private struct SwipeRowTap: ViewModifier {
    let isEnabled: Bool
    let onTap: (CGPoint) -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content.highPriorityGesture(
                SpatialTapGesture().onEnded { value in
                    onTap(value.location)
                }
            )
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
