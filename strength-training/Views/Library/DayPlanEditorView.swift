//
//  DayPlanEditorView.swift
//  strength-training
//
//  Edit a day's exercise roster without starting a workout.
//  Clean rows (no move-handle chrome); long-press/drag a row to reorder.
//  Swipe left to remove. Tap to edit details.
//

import SwiftUI
import SwiftData
internal import UniformTypeIdentifiers

struct DayPlanEditorView: View {
    let dayType: DayType

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var allExercises: [Exercise]

    @State private var trackFilter: RotationTrack = .every
    @State private var showAddPicker = false
    @State private var showAddExerciseSheet = false
    @State private var pendingCreateNew = false
    @State private var editingExercise: Exercise?
    @State private var orderedIDs: [UUID] = []
    @State private var draggingID: UUID?

    init(dayType: DayType) {
        self.dayType = dayType
        _allExercises = Query(sort: [SortDescriptor(\Exercise.sortOrder)])
    }

    private var dayExercisesSorted: [Exercise] {
        allExercises
            .filter {
                $0.belongs(to: dayType)
                    && $0.track.isVisible(whenSessionTrack: trackFilter)
            }
            .sorted {
                let lhs = $0.sortIndex(for: dayType)
                let rhs = $1.sortIndex(for: dayType)
                if lhs != rhs { return lhs < rhs }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private var displayedExercises: [Exercise] {
        let byID = Dictionary(uniqueKeysWithValues: dayExercisesSorted.map { ($0.id, $0) })
        var seen = Set<UUID>()
        var result: [Exercise] = []
        for id in orderedIDs {
            if let ex = byID[id], seen.insert(id).inserted {
                result.append(ex)
            }
        }
        for ex in dayExercisesSorted where seen.insert(ex.id).inserted {
            result.append(ex)
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Long-press and drag a row to reorder. Swipe left to remove from this day. Tap to edit.")
                        .font(.uplift.text(13, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)

                    UpliftSegmentedControl(
                        segments: [
                            UpliftSegment(id: RotationTrack.every.storageKey, label: "All"),
                            UpliftSegment(id: RotationTrack.a.storageKey, label: "A week"),
                            UpliftSegment(id: RotationTrack.b.storageKey, label: "B week"),
                        ],
                        selection: Binding(
                            get: { trackFilter.storageKey },
                            set: {
                                trackFilter = RotationTrack(storageKey: $0)
                                syncOrderedIDsFromStore()
                            }
                        )
                    )

                    HStack {
                        Text(dayType.rawValue.uppercased())
                            .font(.uplift.text(11, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(dayType.upliftInk)
                        Spacer()
                        Text("\(displayedExercises.count)")
                            .font(.uplift.mono(12, weight: .semibold))
                            .foregroundStyle(Color.uplift.fgDim)
                    }
                    .padding(.top, 4)

                    if displayedExercises.isEmpty {
                        ContentUnavailableView(
                            "No exercises on this day",
                            systemImage: "list.bullet.rectangle",
                            description: Text("Add from the library. Unassigned lifts live under Exercises → Unassigned.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(Array(displayedExercises.enumerated()), id: \.element.id) { index, exercise in
                                planRow(exercise, index: index)
                                    .onDrop(
                                        of: [.plainText],
                                        delegate: DayPlanDropDelegate(
                                            targetID: exercise.id,
                                            orderedIDs: $orderedIDs,
                                            draggingID: $draggingID,
                                            onReorder: persistCurrentOrder
                                        )
                                    )
                            }
                        }
                    }

                    Button {
                        showAddPicker = true
                    } label: {
                        Label("Add from library", systemImage: "plus.circle.fill")
                            .font(.uplift.text(15, weight: .semibold))
                            .foregroundStyle(Color.uplift.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.uplift.surface1)
                            }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .background(Color.uplift.bgElev)
            .navigationTitle("Edit \(dayType.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { syncOrderedIDsFromStore() }
            .onChange(of: allExercises.count) { _, _ in
                if draggingID == nil {
                    syncOrderedIDsFromStore()
                }
            }
            .sheet(isPresented: $showAddPicker, onDismiss: {
                if pendingCreateNew {
                    pendingCreateNew = false
                    showAddExerciseSheet = true
                }
                syncOrderedIDsFromStore()
            }) {
                AddExercisePicker(
                    currentDayType: dayType,
                    excludedIDs: Set(dayExercisesSorted.map(\.id)),
                    onPick: { exercise, _ in
                        exercise.addDayType(dayType, atEndOf: allExercises)
                        try? modelContext.save()
                        syncOrderedIDsFromStore()
                    },
                    onCreateNew: { pendingCreateNew = true }
                )
            }
            .sheet(isPresented: $showAddExerciseSheet, onDismiss: syncOrderedIDsFromStore) {
                AddExerciseView(preselectedDayType: dayType)
            }
            .sheet(item: $editingExercise, onDismiss: syncOrderedIDsFromStore) { exercise in
                EditExerciseView(exercise: exercise, focusDay: dayType)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func planRow(_ exercise: Exercise, index: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.uplift.mono(13, weight: .bold))
                .foregroundStyle(Color.uplift.fgDim)
                .frame(width: 22, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.uplift.text(15, weight: .semibold))
                        .foregroundStyle(Color.uplift.fg)
                    if let badge = exercise.track.badge {
                        Text(badge)
                            .font(.uplift.text(9, weight: .bold))
                            .foregroundStyle(Color.uplift.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.uplift.accent.opacity(0.16)))
                    }
                }
                if !exercise.muscleGroup.isEmpty {
                    Text(exercise.muscleGroup)
                        .font(.uplift.text(12, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(draggingID == exercise.id ? Color.uplift.surface2 : Color.uplift.surface1)
        }
        // Whole row is the drag source — no separate handle chrome.
        .onDrag {
            draggingID = exercise.id
            return NSItemProvider(object: exercise.id.uuidString as NSString)
        } preview: {
            Text(exercise.name)
                .font(.uplift.text(14, weight: .semibold))
                .foregroundStyle(Color.uplift.fg)
                .padding(12)
                .background(Color.uplift.surface2, in: RoundedRectangle(cornerRadius: 12))
        }
        .swipeToDelete(fullSwipeDeletes: true, onDelete: {
            removeExercise(exercise)
        }, onTap: {
            editingExercise = exercise
        })
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(index + 1). \(exercise.name)")
        .accessibilityHint("Long press and drag to reorder, swipe left to remove, double tap to edit")
    }

    private func syncOrderedIDsFromStore() {
        orderedIDs = dayExercisesSorted.map(\.id)
    }

    private func persistCurrentOrder() {
        let byID = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.id, $0) })
        let ordered = orderedIDs.compactMap { byID[$0] }
        guard !ordered.isEmpty else { return }
        Exercise.applyOrder(ordered, for: dayType)
        try? modelContext.save()
    }

    private func removeExercise(_ exercise: Exercise) {
        exercise.removeDayType(dayType)
        try? modelContext.save()
        syncOrderedIDsFromStore()
    }
}

// MARK: - Drag reorder

private struct DayPlanDropDelegate: DropDelegate {
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

#Preview {
    DayPlanEditorView(dayType: .push)
        .modelContainer(previewContainer)
}
