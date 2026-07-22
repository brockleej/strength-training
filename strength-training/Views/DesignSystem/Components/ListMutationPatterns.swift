//
//  ListMutationPatterns.swift
//  strength-training
//
//  Global copy + helpers for list remove / reorder / add.
//  See CLAUDE.md “List mutation patterns”.
//

import Foundation
import SwiftUI
internal import UniformTypeIdentifiers

// MARK: - Shared copy

enum ListMutationCopy {
    /// Ordered plan lists (day plan, training split days).
    static let reorderAndRemove =
        "Long-press and drag to reorder. Swipe left to remove."

    /// Library browsing (no reorder).
    static let librarySwipe =
        "Swipe to remove from a day, or delete from the library. Delete always asks first."

    /// Focus sets (soft delete only).
    static let setsSwipe =
        "Tap a set to edit · swipe to remove"

    static func removeFromDay(_ day: String) -> String { "Remove from \(day)" }
    static let removeFromWorkout = "Remove from this workout"
    static let deleteFromLibrary = "Delete from library"
    static let deleteWorkout = "Delete workout"
    static let deleteDay = "Delete day"
    static let addExercise = "Add exercise"
    static let addDay = "Add day"
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
