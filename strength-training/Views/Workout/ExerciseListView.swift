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
    @State private var showAddPicker = false
    @State private var showAddExerciseSheet = false
    @State private var pendingCreateNew = false

    private var dayType: DayType {
        workoutVM.activeSession?.dayType ?? .arms
    }

    /// Session list = the day type's library exercises + any cross-day
    /// exercises pulled in via the picker (their records exist eagerly).
    private func exercises(in section: DayType) -> [Exercise] {
        let base = allExercises.filter { $0.dayType == section }
        let extraIDs = Set(
            (workoutVM.activeSession?.exerciseRecordsArray ?? [])
                .compactMap { $0.exercise }
                .filter { $0.dayType == section }
                .map(\.id)
        )
        // base already covers own-day exercises; extras matter only when the
        // section is NOT the session's day type (cross-day additions)
        if section == dayType || dayType == .fullBody {
            return base
        }
        return base.filter { extraIDs.contains($0.id) }
    }

    /// Ordered sections: own day type (or Arms+Legs for Full Body), plus a
    /// cross-day section when the picker pulled exercises in.
    private var sections: [(dayType: DayType, exercises: [Exercise])] {
        if dayType == .fullBody {
            return [(.arms, exercises(in: .arms)), (.legs, exercises(in: .legs))]
        }
        let other: DayType = dayType == .arms ? .legs : .arms
        let crossDay = exercises(in: other)
        var result: [(DayType, [Exercise])] = [(dayType, exercises(in: dayType))]
        if !crossDay.isEmpty {
            result.append((other, crossDay))
        }
        return result
    }

    private var flatExercises: [Exercise] {
        sections.flatMap(\.exercises)
    }

    private var completedCount: Int {
        flatExercises.filter { hasSets($0) }.count
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
                        LiveHealthKitCard(service: workoutVM.healthKitService)
                            .padding(.horizontal, 20)
                        titleSection
                        progressBar
                        modeToggle
                        exerciseListSection
                        addExerciseRow
                    }
                    .padding(.bottom, 110)   // pill bar clearance
                }
                .background(Color.uplift.bgElev)
                .scrollIndicators(.hidden)

                GlassHeader {
                    CircleButton(icon: "chevron.down", accessibilityLabel: "Minimize workout") {
                        workoutVM.suspendSession()
                    }
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
            .confirmationDialog(
                "Finish Workout?",
                isPresented: $showFinishConfirmation,
                titleVisibility: .visible
            ) {
                Button("Finish Workout") { workoutVM.finishSession() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You completed \(completedCount) exercise\(completedCount == 1 ? "" : "s") this session.")
            }
            .sheet(isPresented: $showAddPicker, onDismiss: {
                if pendingCreateNew {
                    pendingCreateNew = false
                    showAddExerciseSheet = true
                }
            }) {
                AddExercisePicker(
                    currentDayType: dayType,
                    excludedIDs: Set(flatExercises.map(\.id)),
                    onPick: { exercise in
                        workoutVM.addExerciseToSession(exercise)
                    },
                    onCreateNew: { pendingCreateNew = true }
                )
            }
            .sheet(isPresented: $showAddExerciseSheet) {
                AddExerciseView(preselectedDayType: dayType == .fullBody ? .arms : dayType)
            }
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                DayChip(dayType: dayType, size: .sm)
                Text(dayType.rawValue)
                    .font(.uplift.display(28, weight: .bold))
                    .kerning(-0.6)
                    .foregroundStyle(Color.uplift.fg)
            }
            (
                Text("\(completedCount) of \(flatExercises.count)")
                    .font(.uplift.mono(13, weight: .semibold))
                + Text(" exercises complete")
                    .font(.uplift.text(13, weight: .medium))
            )
            .foregroundStyle(Color.uplift.fgMuted)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
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
                    NavigationLink {
                        FocusView(
                            workoutVM: workoutVM,
                            exercise: exercise,
                            liftIndex: (flatExercises.firstIndex(where: { $0.id == exercise.id }) ?? 0) + 1,
                            totalLifts: flatExercises.count
                        )
                        .onAppear { activeExerciseID = exercise.id }
                    } label: {
                        let rowData = rowData(for: exercise)
                        ExerciseListRow(
                            name: exercise.name,
                            lastSets: rowData.lastSets,
                            targetWeight: rowData.targetWeight,
                            targetReps: rowData.targetReps,
                            state: rowState(for: exercise, number: index + 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var addExerciseRow: some View {
        Button {
            if dayType == .fullBody {
                showAddExerciseSheet = true
            } else {
                showAddPicker = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                Text("Add exercise")
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
                    Text("Finish Workout")
                        .font(.uplift.text(15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.uplift.accent, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .foregroundStyle(Color.uplift.onAccent)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 4)
    }

    private var overflowMenu: some View {
        Menu {
            Button(role: .destructive) {
                // Cancel = suspend first, then run the existing destructive flow
                // from Today (which owns the confirmation dialogs).
                workoutVM.suspendSession()
                workoutVM.showCancelConfirmation = true
            } label: {
                Label("Cancel workout", systemImage: "xmark")
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
        if hasSets(exercise) { return .completed }
        if exercise.id == activeExerciseID { return .active }
        return .pending(number: number)
    }

    private func rowData(for exercise: Exercise) -> (lastSets: Int?, targetWeight: Double?, targetReps: Int?) {
        let modeRaw = workoutVM.selectedMode.rawValue
        let lastRecord = exercise.recordsArray
            .filter { $0.trainingMode.rawValue == modeRaw && $0.session?.isCompleted == true }
            .max { ($0.session?.date ?? .distantPast) < ($1.session?.date ?? .distantPast) }
        let lastSets = lastRecord.map { $0.setsArray.filter { !$0.isWarmup }.count }
        let recent = workoutVM.recentAverage(for: exercise, mode: workoutVM.selectedMode)
        let target = workoutVM.suggestion(for: exercise, mode: workoutVM.selectedMode)?.targetWeight
        return (
            lastSets: (lastSets ?? 0) > 0 ? lastSets : nil,
            targetWeight: target ?? recent?.weight,
            targetReps: recent?.reps
        )
    }
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
