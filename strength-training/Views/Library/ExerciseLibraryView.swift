//
//  ExerciseLibraryView.swift
//  strength-training
//

import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.sortOrder) private var allExercises: [Exercise]
    @State private var showAddSheet = false
    @State private var searchText = ""
    @State private var dayCatalog = DayTypeRegistry.shared
    @State private var editingExercise: Exercise?
    @State private var editFocusDay: DayType?
    @State private var exercisePendingDelete: Exercise?

    private func matchesSearch(_ exercise: Exercise) -> Bool {
        searchText.isEmpty
            || exercise.name.localizedCaseInsensitiveContains(searchText)
            || exercise.muscleGroup.localizedCaseInsensitiveContains(searchText)
    }

    private func exercises(for dayType: DayType) -> [Exercise] {
        allExercises.filter { exercise in
            exercise.belongs(to: dayType) && matchesSearch(exercise)
        }
    }

    private var unassignedExercises: [Exercise] {
        allExercises
            .filter { $0.isUnassigned && matchesSearch($0) }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private var sectionDays: [DayType] {
        var days = dayCatalog.exerciseHomeDays
        let known = Set(days.map(\.rawValue))
        let orphanNames = Set(allExercises.flatMap(\.dayTypeNames)).subtracting(known)
        days.append(contentsOf: orphanNames.sorted().map { DayType(rawValue: $0) })
        return days
    }

    var body: some View {
        NavigationStack {
            List {
                SearchField(placeholder: "Search exercises", text: $searchText)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))

                Text(ListMutationCopy.librarySwipe)
                    .font(.uplift.text(12, weight: .medium))
                    .foregroundStyle(Color.uplift.fgDim)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))

                ForEach(sectionDays) { dayType in
                    let matching = exercises(for: dayType)
                    if !matching.isEmpty {
                        librarySection(dayType: dayType, matching: matching)
                    }
                }

                if !unassignedExercises.isEmpty {
                    librarySection(dayType: .unassigned, matching: unassignedExercises, isUnassigned: true)
                }

                if allExercises.isEmpty {
                    EmptyListState(
                        title: "No exercises yet",
                        systemImage: "figure.strengthtraining.traditional",
                        description: "Create a lift to build your library.",
                        actionTitle: ListMutationCopy.addExercise,
                        action: { showAddSheet = true }
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else if !searchText.isEmpty,
                   sectionDays.allSatisfy({ exercises(for: $0).isEmpty }),
                   unassignedExercises.isEmpty {
                    Text("No matches")
                        .font(.uplift.text(13, weight: .medium))
                        .foregroundStyle(Color.uplift.fgDim)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.uplift.bgElev)
            .navigationTitle("Exercises")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.uplift.fg)
                    }
                    .accessibilityLabel(ListMutationCopy.addExercise)
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddExerciseView()
            }
            .sheet(item: $editingExercise, onDismiss: { editFocusDay = nil }) { exercise in
                EditExerciseView(exercise: exercise, focusDay: editFocusDay)
            }
            .confirmationDialog(
                "Delete \(exercisePendingDelete?.name ?? "exercise")?",
                isPresented: Binding(
                    get: { exercisePendingDelete != nil },
                    set: { if !$0 { exercisePendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(ListMutationCopy.deleteFromLibrary, role: .destructive) {
                    if let exercise = exercisePendingDelete {
                        modelContext.delete(exercise)
                        try? modelContext.save()
                    }
                    exercisePendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    exercisePendingDelete = nil
                }
            } message: {
                Text("Removes it from all days. Past workout history that referenced it may show a missing exercise.")
            }
        }
    }

    @ViewBuilder
    private func librarySection(
        dayType: DayType,
        matching: [Exercise],
        isUnassigned: Bool = false
    ) -> some View {
        Section {
            ForEach(matching) { exercise in
                Button {
                    editFocusDay = isUnassigned ? nil : dayType
                    editingExercise = exercise
                } label: {
                    LibraryRow(exercise: exercise, sectionDay: isUnassigned ? nil : dayType)
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.uplift.surface1)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 20)
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 12, leading: 34, bottom: 12, trailing: 34))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if !isUnassigned {
                        Button(ListMutationCopy.removeFromDay(dayType.rawValue)) {
                            exercise.removeDayType(dayType)
                            try? modelContext.save()
                        }
                        .tint(Color.uplift.customBadge)
                    }
                    Button(ListMutationCopy.deleteFromLibrary, role: .destructive) {
                        exercisePendingDelete = exercise
                    }
                }
                .contextMenu {
                    Button {
                        editFocusDay = isUnassigned ? nil : dayType
                        editingExercise = exercise
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    if !isUnassigned {
                        Button {
                            exercise.removeDayType(dayType)
                            try? modelContext.save()
                        } label: {
                            Label(ListMutationCopy.removeFromDay(dayType.rawValue), systemImage: "minus.circle")
                        }
                    }
                    Button(role: .destructive) {
                        exercisePendingDelete = exercise
                    } label: {
                        Label(ListMutationCopy.deleteFromLibrary, systemImage: "trash")
                    }
                }
            }
        } header: {
            HStack(spacing: 8) {
                Circle()
                    .fill(dayType.upliftInk)
                    .frame(width: 8, height: 8)
                Text(dayType.rawValue)
                    .textCase(.uppercase)
                    .font(.uplift.text(11, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(Color.uplift.fg)
                Spacer()
                Text("\(matching.count)")
                    .font(.uplift.mono(12, weight: .semibold))
                    .foregroundStyle(Color.uplift.fgDim)
            }
        }
    }
}

private struct LibraryRow: View {
    let exercise: Exercise
    var sectionDay: DayType? = nil

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(exercise.name)
                        .font(.uplift.text(15, weight: .semibold))
                        .kerning(-0.2)
                        .foregroundStyle(Color.uplift.fg)
                    if let badge = exercise.track.badge {
                        Text(badge)
                            .font(.uplift.text(9, weight: .bold))
                            .foregroundStyle(Color.uplift.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.uplift.accent.opacity(0.16)))
                    }
                    if exercise.isCustom {
                        Text("Custom")
                            .textCase(.uppercase)
                            .font(.uplift.text(9, weight: .bold))
                            .tracking(0.4)
                            .foregroundStyle(Color.uplift.customBadge)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.uplift.customBadge.opacity(0.16)))
                    }
                }
                HStack(spacing: 6) {
                    if !exercise.muscleGroup.isEmpty {
                        Text(exercise.muscleGroup)
                            .font(.uplift.text(12, weight: .medium))
                            .foregroundStyle(Color.uplift.fgMuted)
                    }
                    if exercise.isUnassigned {
                        Text("Unassigned")
                            .font(.uplift.text(11, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                    } else if exercise.dayTypeNames.count > 1 {
                        Text(exercise.dayTypeNames.joined(separator: " · "))
                            .font(.uplift.text(11, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.uplift.fgDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityLabel: String {
        var parts = [exercise.name]
        if let badge = exercise.track.badge { parts.append("week \(badge)") }
        if !exercise.muscleGroup.isEmpty { parts.append(exercise.muscleGroup) }
        if exercise.dayTypeNames.count > 1 {
            parts.append("days \(exercise.dayTypeNames.joined(separator: ", "))")
        }
        parts.append("edit")
        return parts.joined(separator: ", ")
    }
}
