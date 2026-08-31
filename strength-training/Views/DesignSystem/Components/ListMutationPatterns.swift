//
//  ListMutationPatterns.swift
//  strength-training
//
//  Global copy + helpers for list remove / reorder / add.
//  See AGENTS.md “List mutation patterns”.
//

import Foundation
import SwiftUI
internal import UniformTypeIdentifiers

// MARK: - Shared copy

enum ListMutationCopy {
    /// Ordered plan lists (day plan, training split days).
    static let reorderAndRemove =
        "Long-press the number and drag to reorder. Swipe left to remove."

    /// Library browsing (no reorder).
    static let librarySwipe =
        "Swipe to remove from a day, or delete from the library. Delete always asks first."

    /// Focus sets — swipe commits delete (easy to undo an extra tap).
    static let setsSwipe =
        "Tap a set to edit · swipe left to delete"

    static func removeFromDay(_ day: String) -> String { "Remove from \(day)" }
    static let removeFromWorkout = "Remove from this workout"
    static let replaceInWorkout = "Replace exercise"
    static let deleteFromLibrary = "Delete from library"
    static let deleteWorkout = "Delete workout"
    static let deleteDay = "Delete day"
    static let keepLastDayTitle = "Keep at least one day"
    static let keepLastDayMessage =
        "A split needs one day so Today can start a workout. You can delete extra days."
    static let keepLastDayWithBlockMessage =
        "A split needs one day so Today can start a workout. To train this block’s days and lifts instead, use it as your split. History stays."
    static let addExercise = "Add exercise"
    static let addDay = "Add day"
    /// In-session exercise list.
    static let workoutListHint =
        "Swipe left to remove a lift from this workout or from the day plan. Long-press for edit or replace."
}

// MARK: - Reorder (long-press drag, no Edit mode)

/// Shared drop delegate for UUID-ordered lists. Persist via `onReorder`.
struct UUIDListDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var orderedIDs: [UUID]
    @Binding var draggingID: UUID?
    let onReorder: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        draggingID != nil
    }

    func dropEntered(info: DropInfo) {
        guard let draggingID,
              draggingID != targetID,
              let from = orderedIDs.firstIndex(of: draggingID),
              let to = orderedIDs.firstIndex(of: targetID),
              from != to
        else { return }

        withAnimation(.easeInOut(duration: 0.15)) {
            orderedIDs.move(
                fromOffsets: IndexSet(integer: from),
                toOffset: to > from ? to + 1 : to
            )
        }
        onReorder()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        onReorder()
        return true
    }
}

extension View {
    /// Long-press, then drag vertically to reorder. Does not steal a short
    /// horizontal swipe (that belongs to swipe-to-remove).
    func longPressReorder(
        id: UUID,
        orderedIDs: Binding<[UUID]>,
        draggingID: Binding<UUID?>,
        onReorder: @escaping () -> Void
    ) -> some View {
        modifier(LongPressReorderModifier(
            id: id,
            orderedIDs: orderedIDs,
            draggingID: draggingID,
            onReorder: onReorder
        ))
    }

    /// Whole-row long-press drag source for reorderable UUID lists.
    func reorderDragSource(
        id: UUID,
        displayName: String,
        draggingID: Binding<UUID?>
    ) -> some View {
        self.onDrag {
            draggingID.wrappedValue = id
            return NSItemProvider(object: id.uuidString as NSString)
        } preview: {
            Text(displayName)
                .font(.uplift.text(14, weight: .semibold))
                .foregroundStyle(Color.uplift.fg)
                .padding(12)
                .background(Color.uplift.surface2, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    func reorderDropTarget(
        id: UUID,
        orderedIDs: Binding<[UUID]>,
        draggingID: Binding<UUID?>,
        onReorder: @escaping () -> Void
    ) -> some View {
        self.onDrop(
            of: [.plainText],
            delegate: UUIDListDropDelegate(
                targetID: id,
                orderedIDs: orderedIDs,
                draggingID: draggingID,
                onReorder: onReorder
            )
        )
    }
}

/// Reorder without `onDrag`, which on iOS also captures horizontal swipes.
///
/// Long-press alone must not lock the row. The old sequence set `draggingID`
/// when the press fired; lifting without a drag cancelled the sequence and
/// never cleared that lock — the row (and swipe-to-remove) stayed frozen.
private struct LongPressReorderModifier: ViewModifier {
    let id: UUID
    @Binding var orderedIDs: [UUID]
    @Binding var draggingID: UUID?
    let onReorder: () -> Void

    /// Auto-resets when the finger lifts or the gesture cancels.
    @GestureState private var isGestureActive = false
    @State private var startIndex = 0
    @State private var lastTarget = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(draggingID == id ? 1.03 : 1)
            .zIndex(draggingID == id ? 1 : 0)
            .simultaneousGesture(reorderGesture)
            .onChange(of: isGestureActive) { _, active in
                if !active { finishDragIfNeeded() }
            }
    }

    private var reorderGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.4)
            .sequenced(before: DragGesture(minimumDistance: 6, coordinateSpace: .local))
            .updating($isGestureActive) { value, state, _ in
                switch value {
                case .first(true), .second(true, _):
                    state = true
                default:
                    break
                }
            }
            .onChanged { value in
                guard case .second(true, let drag?) = value else { return }
                // Wait for a vertical-dominant drag. A long-press then release,
                // or a horizontal swipe, must not arm the row.
                let horizontal = abs(drag.translation.width)
                let vertical = abs(drag.translation.height)
                guard draggingID == id || vertical >= horizontal else { return }

                if draggingID != id {
                    startIndex = orderedIDs.firstIndex(of: id) ?? 0
                    lastTarget = startIndex
                    draggingID = id
                    HapticService.stepperTick()
                }

                let rowHeight: CGFloat = 68
                let delta = Int((drag.translation.height / rowHeight).rounded())
                let target = max(0, min(orderedIDs.count - 1, startIndex + delta))
                guard target != lastTarget,
                      let current = orderedIDs.firstIndex(of: id)
                else { return }
                lastTarget = target
                withAnimation(.easeInOut(duration: 0.15)) {
                    orderedIDs.move(
                        fromOffsets: IndexSet(integer: current),
                        toOffset: target > current ? target + 1 : target
                    )
                }
            }
            .onEnded { _ in
                finishDragIfNeeded()
            }
    }

    private func finishDragIfNeeded() {
        guard draggingID == id else { return }
        draggingID = nil
        onReorder()
    }
}

// MARK: - Add row (dashed)

/// Primary “add to this context” control — workout list + day plan.
struct AddItemRow: View {
    var title: String = ListMutationCopy.addExercise
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.uplift.text(15, weight: .semibold))
            }
            .foregroundStyle(Color.uplift.fgMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.uplift.fgFaint, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

// MARK: - Empty state + optional primary action

struct EmptyListState: View {
    let title: String
    var systemImage: String = "list.bullet.rectangle"
    let description: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                title,
                systemImage: systemImage,
                description: Text(description)
            )
            if let actionTitle, let action {
                AddItemRow(title: actionTitle, action: action)
                    .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
