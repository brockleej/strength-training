//
//  DayPlanEditorView.swift
//  RockLog
//
//  Edit a day's exercise roster without starting a workout.
//  One List is the only scroller. Long-press and drag to reorder (.onMove),
//  swipe left or long-press to remove, tap to edit, Add exercise row.
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
        let byID = Dictionary(dayExercisesSorted.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
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
            List {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Long-press an exercise and drag to reorder. Swipe left to remove. Tap to edit.")
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

                }
                .planListRow(top: 12, bottom: 8)

                if displayedExercises.isEmpty {
                    EmptyListState(
                        title: "No exercises on this day",
                        description: "Add lifts from your library. Unassigned lifts live under Exercises → Unassigned.",
                        actionTitle: ListMutationCopy.addExercise,
                        action: { showAddPicker = true }
                    )
                    .planListRow(top: 4, bottom: 28)
                } else {
                    ForEach(Array(displayedExercises.enumerated()), id: \.element.id) { index, exercise in
                        planRow(exercise, index: index)
                            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    removeExercise(exercise)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button("Remove", role: .destructive) {
                                    removeExercise(exercise)
                                }
                            }
                    }
                    .onMove(perform: moveExercises)

                    AddItemRow(title: ListMutationCopy.addExercise) {
                        showAddPicker = true
                    }
                    .planListRow(top: 8, bottom: 28)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 1)
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
                syncOrderedIDsFromStore()
            }
            .onChange(of: membershipSignature) { _, _ in
                syncOrderedIDsFromStore()
            }
            .sheet(isPresented: $showAddPicker, onDismiss: syncOrderedIDsFromStore) {
                AddExerciseSheet(
                    currentDayType: dayType,
                    excludedIDs: Set(dayExercisesSorted.map(\.id)),
                    onPick: { exercise, _ in
                        exercise.addDayType(dayType, atEndOf: allExercises)
                        ModelSave.logged(modelContext, action: "DayPlanEditorView")
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

        return Button {
            editingExercise = exercise
        } label: {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.uplift.mono(13, weight: .bold))
                .foregroundStyle(Color.uplift.fgDim)
                .frame(width: 44, height: 44)

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
                .fill(Color.uplift.surface1)
        }
        .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(planAccessibility(index: index, exercise: exercise, personalBest: personalBest, hasHistory: hasHistory))
        // Identifier on the combined row. The List row owns the Remove menu.
        .accessibilityIdentifier(AccessibilityID.dayPlanExercise(exercise.name))
        .accessibilityHint("Swipe left or long press to remove, double tap to edit")
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
        let next = dayExercisesSorted.map(\.id)
        guard next != orderedIDs else { return }
        orderedIDs = next
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        var next = displayedExercises.map(\.id)
        next.move(fromOffsets: source, toOffset: destination)
        guard next != orderedIDs else { return }
        orderedIDs = next
        persistCurrentOrder()
    }

    private func persistCurrentOrder() {
        let byID = Dictionary(allExercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let ordered = orderedIDs.compactMap { byID[$0] }
        guard !ordered.isEmpty else { return }
        Exercise.applyOrder(ordered, for: dayType)
        ModelSave.logged(modelContext, action: "DayPlanEditorView")
        SeedData.persistUserPlan(context: modelContext)
    }

    private func removeExercise(_ exercise: Exercise) {
        orderedIDs.removeAll { $0 == exercise.id }
        exercise.removeDayType(dayType)
        ModelSave.logged(modelContext, action: "DayPlanEditorView")
        SeedData.persistUserPlan(context: modelContext)
    }
}

private extension View {
    /// Full-width List row with the screen's 20 pt margins and no chrome.
    func planListRow(top: CGFloat, bottom: CGFloat) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowInsets(EdgeInsets(top: top, leading: 20, bottom: bottom, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

#Preview {
    DayPlanEditorView(dayType: .push)
        .modelContainer(previewContainer)
}
