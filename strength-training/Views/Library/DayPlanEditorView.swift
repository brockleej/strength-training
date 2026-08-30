//
//  DayPlanEditorView.swift
//  strength-training
//
//  Edit a day's exercise roster without starting a workout.
//  Global list patterns: long-press the number to reorder, swipe-to-remove,
//  Add exercise row. Not a List — native swipeActions + whole-row long-press
//  + contextMenu stacked on one row and ate the Remove tap / froze the lift.
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
                            }
                        }

                        AddItemRow(title: ListMutationCopy.addExercise) {
                            showAddPicker = true
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
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
            .onChange(of: membershipSignature) { _, _ in
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
                        SeedData.persistUserPlan(context: modelContext)
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

    /// `@Query` count does not change when a lift is only unassigned from this day.
    private var membershipSignature: String {
        allExercises
            .map { "\($0.id.uuidString)|\($0.dayType)|\($0.extraDayTypes)" }
            .sorted()
            .joined(separator: ";")
    }

    private func planRow(_ exercise: Exercise, index: Int) -> some View {
        let personalBest = exercise.personalBestSummary()
        let hasHistory = exercise.hasTrainingHistory()

        return HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.uplift.mono(13, weight: .bold))
                .foregroundStyle(Color.uplift.fgDim)
                .frame(width: 28, height: 36)
                .contentShape(Rectangle())
                .longPressReorder(
                    id: exercise.id,
                    orderedIDs: $orderedIDs,
                    draggingID: $draggingID,
                    onReorder: persistCurrentOrder
                )
                .accessibilityLabel("Reorder \(exercise.name)")

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.uplift.text(15, weight: .semibold))
                        .foregroundStyle(Color.uplift.fg)
                        .lineLimit(1)
                    if let badge = exercise.track.badge {
                        Text(badge)
                            .font(.uplift.text(9, weight: .bold))
                            .foregroundStyle(Color.uplift.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.uplift.accent.opacity(0.16)))
                    }
                    if hasHistory && personalBest == nil {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.uplift.fgDim)
                    }
                }
                if !exercise.muscleGroupsDisplay.isEmpty {
                    Text(exercise.muscleGroupsDisplay)
                        .font(.uplift.text(12, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            ExercisePRBadge(hasHistory: hasHistory, personalBestSummary: personalBest)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(draggingID == exercise.id ? Color.uplift.surface2 : Color.uplift.surface1)
        }
        .swipeToDelete(fullSwipeDeletes: false, isEnabled: draggingID == nil, onDelete: {
            removeExercise(exercise)
        }, onTap: {
            editingExercise = exercise
        })
        .accessibilityElement(children: .combine)
        .accessibilityLabel(planAccessibility(index: index, exercise: exercise, personalBest: personalBest, hasHistory: hasHistory))
        .accessibilityHint("Long press the number and drag to reorder, swipe left to remove, double tap to edit")
    }

    private func planAccessibility(
        index: Int,
        exercise: Exercise,
        personalBest: String?,
        hasHistory: Bool
    ) -> String {
        var parts = ["\(index + 1). \(exercise.name)"]
        if let personalBest {
            parts.append("personal best \(personalBest)")
        } else if hasHistory {
            parts.append("trained before")
        }
        return parts.joined(separator: ", ")
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
        SeedData.persistUserPlan(context: modelContext)
    }

    private func removeExercise(_ exercise: Exercise) {
        orderedIDs.removeAll { $0 == exercise.id }
        exercise.removeDayType(dayType)
        try? modelContext.save()
        SeedData.persistUserPlan(context: modelContext)
    }
}

#Preview {
    DayPlanEditorView(dayType: .push)
        .modelContainer(previewContainer)
}
