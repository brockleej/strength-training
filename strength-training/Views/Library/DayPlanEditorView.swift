//
//  DayPlanEditorView.swift
//  strength-training
//
//  Edit a day's exercise roster without starting a workout.
//  Global list patterns: long-press reorder, swipe-to-remove, Add exercise row.
//

import SwiftUI
import SwiftData

struct DayPlanEditorView: View {
    let dayType: DayType

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var allExercises: [Exercise]

    @State private var trackFilter: RotationTrack = .every
    @State private var showAddPicker = false
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
                    Text(ListMutationCopy.reorderAndRemove + " Tap to edit.")
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
                        EmptyListState(
                            title: "No exercises on this day",
                            description: "Add lifts from your library. Unassigned lifts live under Exercises → Unassigned.",
                            actionTitle: ListMutationCopy.addExercise,
                            action: { showAddPicker = true }
                        )
                    } else {
                        VStack(spacing: 8) {
                            ForEach(Array(displayedExercises.enumerated()), id: \.element.id) { index, exercise in
                                planRow(exercise, index: index)
                                    .reorderDropTarget(
                                        id: exercise.id,
                                        orderedIDs: $orderedIDs,
                                        draggingID: $draggingID,
                                        onReorder: persistCurrentOrder
                                    )
                            }
                        }
                    }

                    if !displayedExercises.isEmpty {
                        AddItemRow(title: ListMutationCopy.addExercise) {
                            showAddPicker = true
                        }
                        .padding(.top, 8)
                    }
                    Color.clear.frame(height: 24)
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
            .sheet(isPresented: $showAddPicker, onDismiss: syncOrderedIDsFromStore) {
                AddExerciseSheet(
                    currentDayType: dayType,
                    excludedIDs: Set(dayExercisesSorted.map(\.id)),
                    onPick: { exercise, _ in
                        exercise.addDayType(dayType, atEndOf: allExercises)
                        try? modelContext.save()
                        syncOrderedIDsFromStore()
                    },
                    onCreated: { _ in
                        syncOrderedIDsFromStore()
                    },
                    assignAlways: true
                )
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
        .reorderDragSource(id: exercise.id, displayName: exercise.name, draggingID: $draggingID)
        .swipeToDelete(fullSwipeDeletes: false, onDelete: {
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

#Preview {
    DayPlanEditorView(dayType: .push)
        .modelContainer(previewContainer)
}
