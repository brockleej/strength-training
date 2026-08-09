//
//  AddExercisePicker.swift
//  strength-training
//
//  Full library browser for adding lifts to a session. Shows every preset /
//  custom exercise (except those already in the workout), grouped by muscle
//  or day. For the current day (e.g. Arms), preferred muscles and unassigned
//  matching lifts are listed first so users aren’t buried in irrelevant stock.
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
                    || exercise.muscleGroupsDisplay.localizedCaseInsensitiveContains(searchText)
                    || exercise.dayTypeNames.contains {
                        $0.localizedCaseInsensitiveContains(searchText)
                    })
        }
    }

    /// Ranked for the day being edited (Arms → biceps/triceps first, etc.).
    private func daySorted(_ exercises: [Exercise]) -> [Exercise] {
        exercises.sorted { lhs, rhs in
            let ls = currentDayType.exerciseRelevance(lhs)
            let rs = currentDayType.exerciseRelevance(rhs)
            if ls != rs { return ls > rs }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var sections: [(title: String, ink: Color, exercises: [Exercise])] {
        // When a "Suggested for Day" block is shown, omit those rows from lower sections.
        let rest: [Exercise]
        if searchText.isEmpty, !currentDayType.includesAllExercises {
            let suggestedIDs = Set(suggestedForDay.map(\.id))
            rest = candidates.filter { !suggestedIDs.contains($0.id) }
        } else {
            rest = candidates
        }
        switch groupMode {
        case .muscle:
            return groupByMuscle(rest)
        case .day:
            return groupByDay(rest)
        case .name:
            let sorted = daySorted(rest)
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

            Text(librarySubtitle)
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

            SearchField(
                placeholder: currentDayType.includesAllExercises
                    ? "Search all exercises"
                    : "Search · \(currentDayType.rawValue) first",
                text: $searchText
            )
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
                    // Suggested first when browsing (not searching) a specific day.
                    if searchText.isEmpty,
                       !currentDayType.includesAllExercises,
                       !suggestedForDay.isEmpty {
                        Section {
                            ForEach(Array(suggestedForDay.enumerated()), id: \.element.id) { index, exercise in
                                exerciseRow(exercise)
                                if index < suggestedForDay.count - 1 {
                                    Rectangle()
                                        .fill(Color.uplift.hairline)
                                        .frame(height: 0.5)
                                        .padding(.leading, 66)
                                }
                            }
                        } header: {
                            sectionHeader(
                                title: "Suggested for \(currentDayType.rawValue)",
                                ink: currentDayType.upliftInk,
                                count: suggestedForDay.count
                            )
                        }
                    }

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
        .onAppear {
            // Muscle groups ordered for this day; better default than A–Z.
            if !currentDayType.includesAllExercises {
                groupMode = .muscle
            }
        }
    }

    private var librarySubtitle: String {
        if currentDayType.includesAllExercises {
            return "Full library · \(candidates.count) available"
        }
        let preferred = currentDayType.preferredMuscleGroups.prefix(3).joined(separator: ", ")
        if preferred.isEmpty {
            return "Full library · \(candidates.count) available · \(currentDayType.rawValue) first"
        }
        return "\(currentDayType.rawValue) first (\(preferred)…) · \(candidates.count) available"
    }

    /// High-relevance lifts for this day (unassigned preferred, not already suggested twice).
    private var suggestedForDay: [Exercise] {
        let ranked = daySorted(candidates).filter { currentDayType.exerciseRelevance($0) >= 400 }
        return Array(ranked.prefix(12))
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
        let personalBest = exercise.personalBestSummary()
        let hasHistory = exercise.hasTrainingHistory()

        return Button {
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
                    HStack(spacing: 6) {
                        if !exercise.muscleGroupsDisplay.isEmpty {
                            Text(exercise.muscleGroupsDisplay)
                                .font(.uplift.text(12, weight: .medium))
                                .foregroundStyle(Color.uplift.fgMuted)
                                .lineLimit(2)
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
                ExercisePRBadge(hasHistory: hasHistory, personalBestSummary: personalBest)
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
        .accessibilityLabel(pickerAccessibility(exercise, personalBest: personalBest, hasHistory: hasHistory))
    }

    private func pickerAccessibility(
        _ exercise: Exercise,
        personalBest: String?,
        hasHistory: Bool
    ) -> String {
        var parts = [exercise.name, "add"]
        if let personalBest {
            parts.append("personal best \(personalBest)")
        } else if hasHistory {
            parts.append("trained before")
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Grouping

    private func groupByMuscle(_ exercises: [Exercise]) -> [(title: String, ink: Color, exercises: [Exercise])] {
        // Prefer this day’s muscles (e.g. Arms → Biceps, Triceps) before the rest.
        let preferred = currentDayType.preferredMuscleGroups
        let order = preferred + Self.muscleGroupOrder.filter { name in
            !preferred.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame })
        }

        var buckets: [String: [Exercise]] = [:]
        for exercise in exercises {
            // Bucket by primary muscle; compounds still show full list on the row.
            let key = exercise.primaryMuscleGroup.trimmingCharacters(in: .whitespaces)
            let label = key.isEmpty ? "Other" : key
            buckets[label, default: []].append(exercise)
        }
        var result: [(String, Color, [Exercise])] = []
        for name in order {
            // Case-insensitive bucket match
            guard let key = buckets.keys.first(where: { $0.caseInsensitiveCompare(name) == .orderedSame }),
                  let list = buckets.removeValue(forKey: key)
            else { continue }
            let sorted = daySorted(list)
            let title = preferred.contains(where: { $0.caseInsensitiveCompare(key) == .orderedSame })
                ? "\(key) · \(currentDayType.rawValue)"
                : key
            result.append((title, muscleInk(key), sorted))
        }
        for name in buckets.keys.sorted() {
            let list = daySorted(buckets[name]!)
            result.append((name, muscleInk(name), list))
        }
        return result
    }

    private func groupByDay(_ exercises: [Exercise]) -> [(title: String, ink: Color, exercises: [Exercise])] {
        // Unassigned first when relevant, then current day, then other days.
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
        // Unassigned arm/push/etc. stock sits here after slim day seeding.
        appendKey("Unassigned")
        appendKey(currentDayType.rawValue)
        for home in dayCatalog.exerciseHomeDays { appendKey(home.rawValue) }
        for key in byPrimary.keys.sorted() where !seen.contains(key) {
            orderedKeys.append(key)
        }

        return orderedKeys.compactMap { key in
            guard let list = byPrimary[key], !list.isEmpty else { return nil }
            let day = DayType(rawValue: key)
            let title: String
            if key == "Unassigned" {
                title = "Unassigned · library"
            } else if key == currentDayType.rawValue {
                title = "\(key) · this day"
            } else {
                title = key
            }
            // Within Unassigned, still rank by day relevance (arms first on Arms).
            let sorted = daySorted(list)
            let ink = key == "Unassigned" ? Color.uplift.fgMuted : day.upliftInk
            return (title, ink, sorted)
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
