//
//  ExerciseListView.swift
//  strength-training
//
//  In-workout overview: glass header, live HK card, day title + progress,
//  mode toggle, exercise rows (+ Add exercise final row), Finish pill bar.
//

import SwiftUI
import SwiftData

struct ExerciseListView: View {
    @Bindable var workoutVM: WorkoutViewModel

    @Query(sort: \Exercise.sortOrder) private var allExercises: [Exercise]

    /// Last exercise opened in Focus this session — drives the active row.
    @State private var activeExerciseID: UUID?
    @State private var showFinishConfirmation = false
    @State private var showAddSheet = false
    @State private var dayCatalog = DayTypeRegistry.shared
    @State private var editingExercise: Exercise?
    @State private var exercisePendingRemoval: Exercise?
    @State private var showDayPlanEditor = false
    @State private var focusLaunch: FocusLaunch?
    /// Shared secondary line for all rows: last recipe (default) or progression target.
    @AppStorage("exerciseListSecondaryMode") private var secondaryModeRaw: String =
        ExerciseListRow.SecondaryMode.recipe.rawValue
    @AppStorage("exerciseListSecondaryTipSeen") private var secondaryTipSeen = false

    private var secondaryMode: ExerciseListRow.SecondaryMode {
        ExerciseListRow.SecondaryMode(rawValue: secondaryModeRaw) ?? .recipe
    }

    /// Mid-workout A/B filter only when the catalog uses rotation labels.
    private var hasABLabeledLifts: Bool {
        allExercises.contains { $0.track == .a || $0.track == .b }
    }

    private var dayType: DayType {
        workoutVM.activeSession?.day ?? dayCatalog.defaultSelection
    }

    private var sessionTrack: RotationTrack {
        workoutVM.activeSession?.track ?? .a
    }

    private var suppressedIDs: Set<UUID> {
        workoutVM.activeSession?.suppressedExerciseIDs ?? []
    }

    /// Library exercises for a day tag, filtered by A/B week and session hides.
    private func libraryExercises(for section: DayType) -> [Exercise] {
        allExercises
            .filter {
                $0.belongs(to: section)
                    && $0.track.isVisible(whenSessionTrack: sessionTrack)
                    && !suppressedIDs.contains($0.id)
            }
            .sorted {
                let lhs = $0.sortIndex(for: section)
                let rhs = $1.sortIndex(for: section)
                if lhs != rhs { return lhs < rhs }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    /// Exercises already pulled into this session (eager records), any day tag.
    private var sessionExercises: [Exercise] {
        (workoutVM.activeSession?.exerciseRecordsArray ?? [])
            .compactMap(\.exercise)
            .filter { !suppressedIDs.contains($0.id) }
    }

    /// Ordered sections: own day (or all tags for Full Body-style), plus any
    /// cross-day / orphan-tag exercises the picker added this session.
    private var sections: [(dayType: DayType, exercises: [Exercise])] {
        if dayType.includesAllExercises {
            return groupedLibrarySections(from: allExercises)
        }

        var result: [(DayType, [Exercise])] = []
        let own = libraryExercises(for: dayType)
        let ownIDs = Set(own.map(\.id))
        let extras = sessionExercises.filter { !ownIDs.contains($0.id) }

        // Lead with today's day type when it has exercises, or when the session
        // is still empty (so the empty state is clearly "Push day" not orphan tags).
        if !own.isEmpty || extras.isEmpty {
            result.append((dayType, own))
        }

        let byDay = Dictionary(grouping: extras) { $0.day }
        for day in orderedDayTypes(Set(byDay.keys.map(\.rawValue))) {
            guard let list = byDay[day], !list.isEmpty else { continue }
            result.append((day, list.sorted { $0.sortOrder < $1.sortOrder }))
        }
        return result
    }

    /// Full-body / catch-all: library exercises visible for this A/B week.
    private func groupedLibrarySections(from exercises: [Exercise]) -> [(DayType, [Exercise])] {
        let visible = exercises.filter {
            $0.track.isVisible(whenSessionTrack: sessionTrack)
                && !suppressedIDs.contains($0.id)
        }
        // Place multi-day exercises under each membership for full-body browsing.
        var byDay: [String: [Exercise]] = [:]
        for exercise in visible {
            for name in exercise.dayTypeNames {
                byDay[name, default: []].append(exercise)
            }
        }
        return orderedDayTypes(Set(byDay.keys)).compactMap { day in
            guard let list = byDay[day.rawValue], !list.isEmpty else { return nil }
            let sorted = list.sorted {
                let lhs = $0.sortIndex(for: day)
                let rhs = $1.sortIndex(for: day)
                if lhs != rhs { return lhs < rhs }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return (day, sorted)
        }
    }

    /// Catalog homes first (current day leading), then orphan tags A→Z.
    private func orderedDayTypes(_ names: Set<String>) -> [DayType] {
        var ordered: [DayType] = []
        var seen = Set<String>()
        func append(_ day: DayType) {
            guard names.contains(day.rawValue), !seen.contains(day.rawValue) else { return }
            ordered.append(day)
            seen.insert(day.rawValue)
        }
        append(dayType)
        for home in dayCatalog.exerciseHomeDays { append(home) }
        for name in names.sorted() where !seen.contains(name) {
            ordered.append(DayType(rawValue: name))
        }
        return ordered
    }

    private var flatExercises: [Exercise] {
        sections.flatMap(\.exercises)
    }

    private var completedCount: Int {
        flatExercises.filter { workoutVM.isExerciseDone(for: $0) }.count
    }

    private func hasSets(_ exercise: Exercise) -> Bool {
        workoutVM.currentRecord(for: exercise)?.setsArray.isEmpty == false
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: 56)
                        if workoutVM.isRevisitingSavedSession {
                            editingBanner
                        } else {
                            LiveHealthKitCard(service: workoutVM.healthKitService)
                                .padding(.horizontal, 20)
                        }
                        titleSection
                        progressBar
                        if hasABLabeledLifts {
                            rotationToggle
                        }
                        modeToggle
                        secondaryLineTip
                        exerciseListSection
                        addExerciseRow
                    }
                    .padding(.bottom, 110)   // pill bar clearance
                }
                .background(Color.uplift.bgElev)
                .scrollIndicators(.hidden)

                GlassHeader {
                    // Hierarchy: Home (Today) → this workout list → a lift.
                    // Chevron-down matches dismiss sheet; label makes “leave without finishing” clear.
                    Button {
                        workoutVM.suspendSession()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 13, weight: .bold))
                            Text("Home")
                                .font(.uplift.text(14, weight: .semibold))
                        }
                        .foregroundStyle(Color.uplift.fg)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Color.uplift.surface1))
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Home")
                    .accessibilityHint("Leave the workout list and return to Today. Your session stays available to resume.")

                    Spacer()
                    Text("\(dayType.rawValue) day")
                        .textCase(.uppercase)
                        .font(.uplift.text(11, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(Color.uplift.fgMuted)
                    Spacer()
                    overflowMenu
                }
            }
            .safeAreaInset(edge: .bottom) {
                finishBar
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $focusLaunch) { launch in
                FocusFlowView(
                    workoutVM: workoutVM,
                    exercises: flatExercises,
                    startIndex: launch.startIndex
                )
                .onAppear { activeExerciseID = launch.exerciseID }
            }
            .confirmationDialog(
                workoutVM.isRevisitingSavedSession ? "Save changes?" : "Finish Workout?",
                isPresented: $showFinishConfirmation,
                titleVisibility: .visible
            ) {
                Button(workoutVM.isRevisitingSavedSession ? "Save Changes" : "Finish Workout") {
                    workoutVM.finishSession()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if workoutVM.isRevisitingSavedSession {
                    Text("Updates this saved workout. \(completedCount) exercise\(completedCount == 1 ? "" : "s") currently have sets.")
                } else {
                    Text("You completed \(completedCount) exercise\(completedCount == 1 ? "" : "s") this session.")
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddExerciseSheet(
                    currentDayType: dayType.includesAllExercises
                        ? (dayCatalog.exerciseHomeDays.first ?? dayType)
                        : dayType,
                    excludedIDs: Set(flatExercises.map(\.id)),
                    onPick: { exercise, assignToCurrentDay in
                        if assignToCurrentDay {
                            exercise.addDayType(dayType, atEndOf: allExercises)
                            try? workoutVM.modelContext.save()
                            SeedData.persistUserPlan(context: workoutVM.modelContext)
                        }
                        workoutVM.addExerciseToSession(exercise)
                    },
                    onCreated: { exercise in
                        workoutVM.addExerciseToSession(exercise)
                    }
                )
            }
            .sheet(item: $editingExercise) { exercise in
                EditExerciseView(
                    exercise: exercise,
                    focusDay: dayType.includesAllExercises ? nil : dayType
                )
            }
            .sheet(isPresented: $showDayPlanEditor) {
                DayPlanEditorView(dayType: dayType)
            }
            .confirmationDialog(
                "Remove \(exercisePendingRemoval?.name ?? "exercise")?",
                isPresented: Binding(
                    get: { exercisePendingRemoval != nil },
                    set: { if !$0 { exercisePendingRemoval = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(ListMutationCopy.removeFromWorkout, role: .destructive) {
                    if let exercise = exercisePendingRemoval {
                        workoutVM.removeExerciseFromSession(exercise)
                    }
                    exercisePendingRemoval = nil
                }
                if !dayType.includesAllExercises {
                    Button(ListMutationCopy.removeFromDay(dayType.rawValue), role: .destructive) {
                        if let exercise = exercisePendingRemoval {
                            workoutVM.removeExerciseFromDayPlan(exercise, day: dayType)
                        }
                        exercisePendingRemoval = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    exercisePendingRemoval = nil
                }
            } message: {
                Text(dayType.includesAllExercises
                     ? "Stays in your library. Sets logged this session for this exercise will be deleted."
                     : "This workout only hides it today. Remove from \(dayType.rawValue) to drop it from the day plan.")
            }
        }
    }

    // MARK: - Sections

    private var editingBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "pencil.line")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.uplift.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Editing saved workout")
                    .font(.uplift.text(14, weight: .semibold))
                    .foregroundStyle(Color.uplift.fg)
                Text("Adjust sets or add a missed lift, then Save Changes.")
                    .font(.uplift.text(12, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.uplift.accent.opacity(0.12))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.uplift.accent.opacity(0.35), lineWidth: 1)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                DayChip(dayType: dayType, size: .sm)
                Text(dayType.rawValue)
                    .font(.uplift.display(28, weight: .bold))
                    .kerning(-0.6)
                    .foregroundStyle(Color.uplift.fg)
                if sessionTrack != .every, let badge = sessionTrack.badge {
                    Text(badge)
                        .font(.uplift.text(13, weight: .bold))
                        .foregroundStyle(Color.uplift.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.uplift.accent.opacity(0.16)))
                }
            }
            HStack(spacing: 0) {
                Text("\(completedCount) of \(flatExercises.count)")
                    .font(.uplift.mono(13, weight: .semibold))
                Text(" exercises complete")
                    .font(.uplift.text(13, weight: .medium))
            }
            .foregroundStyle(Color.uplift.fgMuted)
            if workoutVM.isRevisitingSavedSession, let date = workoutVM.activeSession?.date {
                Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.uplift.text(12, weight: .medium))
                    .foregroundStyle(Color.uplift.fgDim)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    /// A / B / All — available on every day type mid-workout.
    private var rotationToggle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WEEK ROTATION")
                .font(.uplift.text(11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Color.uplift.fgMuted)
            UpliftSegmentedControl(
                segments: RotationTrack.sessionFilters.map { track in
                    UpliftSegment(id: track.storageKey, label: track.sessionFilterLabel)
                },
                selection: Binding(
                    get: { sessionTrack.storageKey },
                    set: { workoutVM.setSessionRotationTrack(RotationTrack(storageKey: $0)) }
                )
            )
            Text("Every day supports A/B. Switch here anytime; All shows both.")
                .font(.uplift.text(11, weight: .medium))
                .foregroundStyle(Color.uplift.fgDim)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var progressBar: some View {
        let fraction = flatExercises.isEmpty
            ? 0.0
            : Double(completedCount) / Double(flatExercises.count)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.uplift.fgFaint)
                Capsule().fill(dayType.upliftInk)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 6)
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(completedCount) of \(flatExercises.count) exercises complete")
    }

    private var modeToggle: some View {
        UpliftSegmentedControl(
            segments: [
                UpliftSegment(id: TrainingMode.highWeightLowReps.rawValue, label: "Strength", icon: "bolt.fill"),
                UpliftSegment(id: TrainingMode.lowWeightHighReps.rawValue, label: "Endurance", icon: "flame.fill"),
            ],
            selection: Binding(
                get: { workoutVM.selectedMode.rawValue },
                set: { workoutVM.selectedMode = TrainingMode(rawValue: $0) ?? .highWeightLowReps }
            )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private var exerciseListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                if sections.count > 1 {
                    Text("\(section.dayType.rawValue) exercises")
                        .textCase(.uppercase)
                        .font(.uplift.text(11, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(section.dayType.upliftInk)
                        .padding(.top, 8)
                }
                ForEach(Array(section.exercises.enumerated()), id: \.element.id) { index, exercise in
                    let rowData = rowData(for: exercise)
                    ExerciseListRow(
                        name: exercise.name,
                        state: rowState(for: exercise, number: index + 1),
                        trackBadge: exercise.track.badge,
                        lastSessionSummary: rowData.lastSessionSummary,
                        personalBestSummary: rowData.personalBestSummary,
                        hasHistory: rowData.hasHistory,
                        targetWeight: rowData.targetWeight,
                        targetReps: rowData.targetReps,
                        secondaryMode: secondaryMode,
                        onToggleSecondary: toggleSecondaryMode
                    )
                    .contentShape(Rectangle())
                    .swipeToDelete {
                        exercisePendingRemoval = exercise
                    } onTap: {
                        let start = flatExercises.firstIndex(where: { $0.id == exercise.id }) ?? 0
                        focusLaunch = FocusLaunch(exerciseID: exercise.id, startIndex: start)
                    }
                    .contextMenu {
                        Button {
                            editingExercise = exercise
                        } label: {
                            Label("Edit exercise", systemImage: "pencil")
                        }
                        Button {
                            toggleSecondaryMode()
                        } label: {
                            Label(
                                secondaryMode == .recipe ? "Show progression target" : "Show last session",
                                systemImage: secondaryMode == .recipe ? "arrow.up.right" : "clock.arrow.circlepath"
                            )
                        }
                        Button(role: .destructive) {
                            exercisePendingRemoval = exercise
                        } label: {
                            Label(ListMutationCopy.removeFromWorkout, systemImage: "minus.circle")
                        }
                        if !dayType.includesAllExercises {
                            Button(role: .destructive) {
                                workoutVM.removeExerciseFromDayPlan(exercise, day: dayType)
                            } label: {
                                Label(ListMutationCopy.removeFromDay(dayType.rawValue), systemImage: "minus.circle")
                            }
                        }
                    }
                    .accessibilityHint("Swipe left to remove from this workout or day plan")
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var secondaryLineTip: some View {
        Group {
            if !secondaryTipSeen, !flatExercises.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.uplift.accent)
                    Text("Tap Last under a lift to switch between last session and progression target.")
                        .font(.uplift.text(12, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button {
                        secondaryTipSeen = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.uplift.fgDim)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss tip")
                }
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.uplift.accent.opacity(0.10))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
        }
    }

    private func toggleSecondaryMode() {
        secondaryTipSeen = true
        withAnimation(.easeInOut(duration: 0.15)) {
            secondaryModeRaw = secondaryMode == .recipe
                ? ExerciseListRow.SecondaryMode.target.rawValue
                : ExerciseListRow.SecondaryMode.recipe.rawValue
        }
    }

    private var addExerciseRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            AddItemRow(title: ListMutationCopy.addExercise) {
                showAddSheet = true
            }
            Text(ListMutationCopy.workoutListHint)
                .font(.uplift.text(12, weight: .medium))
                .foregroundStyle(Color.uplift.fgDim)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var finishBar: some View {
        PillBottomBar {
            Button {
                showFinishConfirmation = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                    Text(workoutVM.isRevisitingSavedSession ? "Save Changes" : "Finish Workout")
                        .font(.uplift.text(15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.uplift.accent, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .foregroundStyle(Color.uplift.onAccent)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 12)
    }

    private var overflowMenu: some View {
        Menu {
            Button {
                showDayPlanEditor = true
            } label: {
                Label("Reorder / edit day plan", systemImage: "arrow.up.arrow.down")
            }
            Button(role: .destructive) {
                // Live workouts: park first so the confirm can discard them.
                // History edit: leave active — confirm re-completes (never deletes).
                // (suspendSession on a History edit re-completes immediately.)
                if !workoutVM.isRevisitingSavedSession {
                    workoutVM.suspendSession()
                }
                workoutVM.showCancelConfirmation = true
            } label: {
                Label(
                    workoutVM.isRevisitingSavedSession ? "Exit editing" : "Cancel workout",
                    systemImage: "xmark"
                )
            }
        } label: {
            ZStack {
                Circle().fill(Color.uplift.surface1)
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.uplift.fg)
            }
            .frame(width: 36, height: 36)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("More options")
    }

    // MARK: - Row data

    private func rowState(for exercise: Exercise, number: Int) -> ExerciseListRow.RowState {
        // Completed only when the user marks the lift done — not by set count.
        if workoutVM.isExerciseDone(for: exercise) { return .completed }
        if exercise.id == activeExerciseID { return .active }
        if hasSets(exercise) { return .active } // in progress (has sets, not marked done)
        return .pending(number: number)
    }

    private func rowData(for exercise: Exercise) -> (
        targetWeight: Double?,
        targetReps: Int?,
        lastSessionSummary: String?,
        personalBestSummary: String?,
        hasHistory: Bool
    ) {
        let lastRecord = exercise.lastCompletedRecord(
            mode: workoutVM.selectedMode,
            excludingSessionID: workoutVM.activeSession?.id
        )
        let summary = lastRecord.map { Self.formatLastSessionSets($0.setsArray) }
        let suggestion = workoutVM.suggestion(for: exercise, mode: workoutVM.selectedMode)
        let recent = workoutVM.recentAverage(for: exercise, mode: workoutVM.selectedMode)
        var target = suggestion?.targetWeight ?? recent?.weight
        // Progression is effective load; list target should match Assist field when appropriate.
        let preferAssist = lastRecord?.setsArray.contains(where: { $0.isAssisted && !$0.isWarmup }) == true
            || ExerciseAssistPreferences.prefersAssist(for: exercise.id)
        let bw = BodyWeightPreferences.pounds
        if preferAssist, let effective = target, bw > 0 {
            target = max(0, bw - effective)
        }
        let hasHistory = workoutVM.hasTrainingHistory(for: exercise)
        return (
            targetWeight: target,
            targetReps: suggestion?.targetReps ?? recent?.reps,
            lastSessionSummary: summary,
            personalBestSummary: workoutVM.personalBestSummary(for: exercise),
            hasHistory: hasHistory
        )
    }

    /// "135×5 · 225×4 · −50×8 · 305×5" — full last-session recipe (assist as −N).
    private static func formatLastSessionSets(_ sets: [SetRecord]) -> String {
        let ordered = sets.sorted { $0.setNumber < $1.setNumber }
        guard !ordered.isEmpty else { return "" }
        return ordered.map { set in
            let w = set.isAssisted
                ? "−\(StepperLogic.format(set.weightLbs))"
                : StepperLogic.format(set.weightLbs)
            var piece = "\(w)×\(set.reps)"
            if set.isEachSide { piece += "ea" }
            return set.isWarmup ? "\(piece)w" : piece
        }
        .joined(separator: " · ")
    }
}

private struct FocusLaunch: Hashable, Identifiable {
    let exerciseID: UUID
    let startIndex: Int
    var id: UUID { exerciseID }
}

#Preview {
    ExerciseListView(workoutVM: {
        let vm = WorkoutViewModel(
            modelContext: previewContainer.mainContext,
            healthKitService: HealthKitWorkoutService()
        )
        return vm
    }())
    .modelContainer(previewContainer)
    .preferredColorScheme(.dark)
}
