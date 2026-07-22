//
//  AddExercisePicker.swift
//  strength-training
//
//  Full library browser for adding lifts to a session. Shows every preset /
//  custom exercise (except those already in the workout), grouped by muscle
//  or day — not limited to the current day’s tags.
//

import SwiftUI
import SwiftData

struct AddExercisePicker: View {
    let currentDayType: DayType
    /// Exercise ids already in the session list (hidden from the picker).
    let excludedIDs: Set<UUID>
    /// Called with the exercise and whether to also pin it to the current day.
    let onPick: (Exercise, Bool) -> Void
    /// When embedded in `AddExerciseSheet`, hide sheet chrome / detents.
    var embedded: Bool = false
    /// Day-plan mode: always pin and hide the optional toggle.
    var forceAssignToDay: Bool = false

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var groupMode: GroupMode = .muscle
    @State private var assignToCurrentDay = true
    @State private var dayCatalog = DayTypeRegistry.shared

    @Query(sort: \Exercise.sortOrder) private var allExercises: [Exercise]

    private enum GroupMode: String, CaseIterable, Identifiable {
        case muscle = "Muscle"
        case day = "Day"
        case name = "A–Z"
        var id: String { rawValue }
    }

    /// Full library minus what's already on the workout.
    private var candidates: [Exercise] {
        allExercises.filter { exercise in
            !excludedIDs.contains(exercise.id)
                && (searchText.isEmpty
                    || exercise.name.localizedCaseInsensitiveContains(searchText)
                    || exercise.muscleGroup.localizedCaseInsensitiveContains(searchText)
                    || exercise.dayTypeNames.contains {
                        $0.localizedCaseInsensitiveContains(searchText)
                    })
        }
    }

    private var sections: [(title: String, ink: Color, exercises: [Exercise])] {
        switch groupMode {
        case .muscle:
            return groupByMuscle(candidates)
        case .day:
            return groupByDay(candidates)
        case .name:
            let sorted = candidates.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return sorted.isEmpty ? [] : [("All exercises", Color.uplift.fgMuted, sorted)]
        }
    }

    private var showAssignToggle: Bool {
        !forceAssignToDay && !currentDayType.includesAllExercises
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !embedded {
                Capsule()
                    .fill(Color.uplift.fgFaint)
                    .frame(width: 36, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                Text("Add exercise")
                    .font(.uplift.display(20, weight: .bold))
                    .kerning(-0.4)
                    .foregroundStyle(Color.uplift.fg)
                    .padding(.horizontal, 20)
            }

            Text("Full library · \(candidates.count) available")
                .font(.uplift.text(13, weight: .medium))
                .foregroundStyle(Color.uplift.fgMuted)
                .padding(.horizontal, 20)
                .padding(.top, embedded ? 8 : 2)

            // Grouping control
            UpliftSegmentedControl(
                segments: GroupMode.allCases.map {
                    UpliftSegment(id: $0.rawValue, label: $0.rawValue)
                },
                selection: Binding(
                    get: { groupMode.rawValue },
                    set: { groupMode = GroupMode(rawValue: $0) ?? .muscle }
                )
            )
            .padding(.horizontal, 20)
            .padding(.top, 12)

            SearchField(placeholder: "Search all exercises", text: $searchText)
                .padding(.horizontal, 20)
                .padding(.top, 10)

            // Pin to current day (builds Posterior Chain / Push library over time)
            if showAssignToggle {
                Toggle(isOn: $assignToCurrentDay) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Also add to \(currentDayType.rawValue) day")
                            .font(.uplift.text(14, weight: .semibold))
                            .foregroundStyle(Color.uplift.fg)
                        Text("Keeps it on this day next time, not only this workout")
                            .font(.uplift.text(11, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                    }
                }
                .tint(Color.uplift.accent)
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                        Section {
                            ForEach(Array(section.exercises.enumerated()), id: \.element.id) { index, exercise in
                                exerciseRow(exercise)
                                if index < section.exercises.count - 1 {
                                    Rectangle()
                                        .fill(Color.uplift.hairline)
                                        .frame(height: 0.5)
                                        .padding(.leading, 66)
                                }
                            }
                        } header: {
                            sectionHeader(title: section.title, ink: section.ink, count: section.exercises.count)
                        }
                    }

                    if candidates.isEmpty {
                        Text(searchText.isEmpty
                             ? "Every exercise is already in this workout"
                             : "No matches")
                            .font(.uplift.text(13, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                            .frame(maxWidth: .infinity)
                            .padding(24)
                    }
                }
                .padding(.bottom, 28)
            }
        }
        .background(Color.uplift.bgElev)
        .modifier(StandaloneSheetChrome(enabled: !embedded))
    }

    // MARK: - Rows

    private func sectionHeader(title: String, ink: Color, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(title.uppercased())
                .font(.uplift.text(11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(ink)
            Text("\(count)")
                .font(.uplift.mono(11, weight: .semibold))
                .foregroundStyle(Color.uplift.fgDim)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.uplift.bgElev)
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        Button {
            let assign = forceAssignToDay
                || (assignToCurrentDay && !currentDayType.includesAllExercises)
            dismiss()
            onPick(exercise, assign)
        } label: {
            HStack(spacing: 10) {
                DayChip(dayType: exercise.day, size: .sm)
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
                    HStack(spacing: 6) {
                        if !exercise.muscleGroup.isEmpty {
                            Text(exercise.muscleGroup)
                                .font(.uplift.text(12, weight: .medium))
                                .foregroundStyle(Color.uplift.fgMuted)
                        }
                        if exercise.dayTypeNames.count >= 1 {
                            Text(exercise.dayTypeNames.joined(separator: " · "))
                                .font(.uplift.text(11, weight: .medium))
                                .foregroundStyle(Color.uplift.fgDim)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.uplift.accent)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Grouping

    private func groupByMuscle(_ exercises: [Exercise]) -> [(title: String, ink: Color, exercises: [Exercise])] {
        let order = Self.muscleGroupOrder
        var buckets: [String: [Exercise]] = [:]
        for exercise in exercises {
            let key = exercise.muscleGroup.trimmingCharacters(in: .whitespaces)
            let label = key.isEmpty ? "Other" : key
            buckets[label, default: []].append(exercise)
        }
        var result: [(String, Color, [Exercise])] = []
        for name in order where buckets[name] != nil {
            let list = buckets.removeValue(forKey: name)!
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            result.append((name, muscleInk(name), list))
        }
        for name in buckets.keys.sorted() {
            let list = buckets[name]!
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            result.append((name, muscleInk(name), list))
        }
        return result
    }

    private func groupByDay(_ exercises: [Exercise]) -> [(title: String, ink: Color, exercises: [Exercise])] {
        // One row per exercise under its primary day; multi-day lifts still listed once
        // under primary to avoid duplicates, with all day names in the subtitle.
        var byPrimary: [String: [Exercise]] = [:]
        for exercise in exercises {
            let key = exercise.dayTypeNames.first ?? "Unassigned"
            byPrimary[key, default: []].append(exercise)
        }

        var orderedKeys: [String] = []
        var seen = Set<String>()
        func appendKey(_ key: String) {
            guard byPrimary[key] != nil, !seen.contains(key) else { return }
            orderedKeys.append(key)
            seen.insert(key)
        }
        appendKey(currentDayType.rawValue)
        for home in dayCatalog.exerciseHomeDays { appendKey(home.rawValue) }
        for key in byPrimary.keys.sorted() where !seen.contains(key) {
            orderedKeys.append(key)
        }

        return orderedKeys.compactMap { key in
            guard let list = byPrimary[key], !list.isEmpty else { return nil }
            let day = DayType(rawValue: key)
            let title = key == currentDayType.rawValue ? "\(key) · today" : key
            let sorted = list.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return (title, day.upliftInk, sorted)
        }
    }

    private func muscleInk(_ muscle: String) -> Color {
        // Stable tint per muscle name so sections scan easily.
        let palette: [Color] = [
            .uplift.accent, Color(hex: 0xFF8C42), Color(hex: 0x34C759),
            Color(hex: 0xB569FF), Color(hex: 0xFF4D88), Color(hex: 0x3F9CFF),
            Color(hex: 0xFFB547), Color(hex: 0xFF6B6B),
        ]
        let hash = abs(muscle.utf8.reduce(0) { ($0 &* 31) &+ Int($1) })
        return palette[hash % palette.count]
    }

    /// Preferred muscle section order (seed groups + common extras).
    private static let muscleGroupOrder: [String] = [
        "Chest", "Shoulders", "Back", "Biceps", "Triceps", "Rear Delts",
        "Quads", "Hamstrings", "Glutes", "Adductors", "Calves", "Lower Back",
        "Core", "Other",
    ]
}

/// Presentation chrome only when the picker is shown as its own sheet.
private struct StandaloneSheetChrome: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled {
            content
                .presentationDetents([.large, .medium])
                .presentationDragIndicator(.hidden)
                .presentationContentInteraction(.scrolls)
        } else {
            content
        }
    }
}

#Preview("AddExercisePicker") {
    AddExercisePicker(
        currentDayType: .push,
        excludedIDs: [],
        onPick: { _, _ in }
    )
    .modelContainer(previewContainer)
    .preferredColorScheme(.dark)
}
