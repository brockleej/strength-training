//
//  ListMutationPatterns.swift
//  RockLog
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

/// Whether the parent scroll view is locked, and how a measured row height
/// turns a drag into a slot. Unit tests cover cancel and Dynamic Type height.
struct ReorderScrollLock: Equatable {
    private(set) var draggingID: UUID?

    init(draggingID: UUID? = nil) {
        self.draggingID = draggingID
    }

    var scrollDisabled: Bool { draggingID != nil }

    mutating func arm(_ id: UUID) {
        draggingID = id
    }

    /// Finger up, the gesture cancelled, or the row left the screen.
    mutating func release(_ id: UUID) {
        guard draggingID == id else { return }
        draggingID = nil
    }
}

enum ReorderDragStep {
    /// Rows of travel. A zero height means layout has not measured the row yet.
    static func delta(translation: CGFloat, rowHeight: CGFloat) -> Int {
        guard rowHeight > 0 else { return 0 }
        return Int((translation / rowHeight).rounded())
    }

    static func targetIndex(start: Int, translation: CGFloat, rowHeight: CGFloat, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let next = start + delta(translation: translation, rowHeight: rowHeight)
        return max(0, min(count - 1, next))
    }
}

private struct ReorderRowHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 { value = next }
    }
}

/// Reorder without `onDrag`, which on iOS also captures horizontal swipes.
///
/// Long-press alone must not lock the row. The scroll lock clears when the
/// drag ends, the gesture cancels, or the row disappears.
private struct LongPressReorderModifier: ViewModifier {
    let id: UUID
    @Binding var orderedIDs: [UUID]
    @Binding var draggingID: UUID?
    let onReorder: () -> Void

    /// Auto-resets when the finger lifts or the gesture cancels.
    @GestureState private var isGestureActive = false
    @State private var startIndex = 0
    @State private var lastTarget = 0
    @State private var rowHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: ReorderRowHeightKey.self, value: proxy.size.height)
                }
            }
            .onPreferenceChange(ReorderRowHeightKey.self) { height in
                if height > 0, height != rowHeight {
                    rowHeight = height
                }
            }
            .scaleEffect(draggingID == id ? 1.03 : 1)
            .zIndex(draggingID == id ? 1 : 0)
            .simultaneousGesture(reorderGesture)
            .onChange(of: isGestureActive) { _, active in
                // GestureState falls back to false when the gesture cancels.
                if !active { finishDragIfNeeded() }
            }
            .onDisappear {
                finishDragIfNeeded()
            }
    }

    private var reorderGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.4)
            .sequenced(before: DragGesture(minimumDistance: 6, coordinateSpace: .global))
            .updating($isGestureActive) { value, state, _ in
                switch value {
                case .first(true), .second(true, _):
                    state = true
                default:
                    break
                }
            }
            .onChanged { value in
                switch value {
                case .first(true):
                    // Arm before the finger moves so the parent ScrollView
                    // locks. Otherwise the scroll eats the drag and the
                    // local translation stays ~0 (the "2." label never
                    // becomes "1.").
                    armDrag()
                case .second(true, let drag?):
                    armDrag()
                    let horizontal = abs(drag.translation.width)
                    let vertical = abs(drag.translation.height)
                    guard vertical >= horizontal else { return }
                    let target = ReorderDragStep.targetIndex(
                        start: startIndex,
                        translation: drag.translation.height,
                        rowHeight: rowHeight,
                        count: orderedIDs.count
                    )
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
                default:
                    break
                }
            }
            .onEnded { _ in
                finishDragIfNeeded()
            }
    }

    private func armDrag() {
        var lock = ReorderScrollLock(draggingID: draggingID)
        guard lock.draggingID != id else { return }
        startIndex = orderedIDs.firstIndex(of: id) ?? 0
        lastTarget = startIndex
        lock.arm(id)
        draggingID = lock.draggingID
        HapticService.stepperTick()
    }

    private func finishDragIfNeeded() {
        var lock = ReorderScrollLock(draggingID: draggingID)
        let wasDragging = lock.draggingID == id
        lock.release(id)
        draggingID = lock.draggingID
        if wasDragging { onReorder() }
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
