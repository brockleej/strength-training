// strength-training/Views/Workout/ExerciseListView.swift
import SwiftUI
import SwiftData

struct ExerciseListView: View {
    @Bindable var workoutVM: WorkoutViewModel
    @Query(sort: \Exercise.sortOrder) private var allExercises: [Exercise]

    /// Exercise the user most recently entered Focus on (or tapped). Drives the
    /// "active" row highlight + chevron. Persists for the session lifetime.
    @State private var activeExerciseID: UUID?
    @State private var showFinishConfirmation = false
    @State private var showAddExercisePicker = false
    @State private var showAddExerciseSheet = false

    private var dayType: DayType {
        workoutVM.activeSession?.dayType ?? .arms
    }

    /// Exercises shown for this session, in the order they appear.
    /// Full Body shows Arms then Legs (matches existing logic in WorkoutViewModel.exercises).
    private var sessionExercises: [Exercise] {
        if dayType == .fullBody { return allExercises }
        return allExercises.filter { $0.dayType == dayType }
    }

    private var completedCount: Int {
        sessionExercises.filter { exercise in
            workoutVM.currentRecord(for: exercise)?.setsArray.isEmpty == false
        }.count
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: 56)  // glass-header clearance
                        LiveHealthKitCard(service: workoutVM.healthKitService)
                            .padding(.horizontal, 20)
                        titleSection
                        progressBar
                        exerciseList
                    }
                    .padding(.bottom, 140)  // pill action bar clearance
                }
                .background(Color.uplift.bgElev)
                .scrollIndicators(.hidden)

                GlassHeader {
                    CircleButton(icon: "chevron.down") {
                        workoutVM.suspendSession()
                    }
                    Spacer()
                    Text("\(dayType.rawValue) DAY".uppercased())
                        .font(.uplift.text(11, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(Color.uplift.fgMuted)
                    Spacer()
                    overflowMenu
                }
            }
            .safeAreaInset(edge: .bottom) {
                actionBar
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
            .sheet(isPresented: $showAddExercisePicker) {
                AddExercisePicker(
                    currentDayType: dayType,
                    onPick: { exercise in
                        // Adding the picked exercise: just preselect it as active.
                        // Phase 2 doesn't add a record until the user logs a set
                        // (preserves existing WorkoutViewModel.findOrCreateRecord behavior).
                        activeExerciseID = exercise.id
                    },
                    onCreateNew: {
                        showAddExerciseSheet = true
                    }
                )
            }
            .sheet(isPresented: $showAddExerciseSheet) {
                AddExerciseView(preselectedDayType: oppositeDayType(for: dayType))
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
            HStack(spacing: 4) {
                Num(completedCount, size: 13, weight: .semibold)
                Text("of")
                    .font(.uplift.text(13, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
                Num(sessionExercises.count, size: 13, weight: .semibold)
                Text("exercises complete")
                    .font(.uplift.text(13, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 14)
    }

    private var progressBar: some View {
        let fraction = sessionExercises.isEmpty
            ? 0.0
            : Double(completedCount) / Double(sessionExercises.count)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.uplift.fgFaint)
                Capsule().fill(dayTypeInk(dayType))
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 6)
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
    }

    private var exerciseList: some View {
        VStack(spacing: 8) {
            ForEach(Array(sessionExercises.enumerated()), id: \.element.id) { index, exercise in
                NavigationLink {
                    FocusView(
                        workoutVM: workoutVM,
                        exercise: exercise,
                        liftIndex: index + 1,
                        totalLifts: sessionExercises.count
                    )
                    .onAppear {
                        activeExerciseID = exercise.id
                    }
                } label: {
                    ExerciseListRow(
                        exercise: exercise,
                        state: rowState(for: exercise, index: index),
                        setSummary: setSummary(for: exercise),
                        targetWeight: targetWeight(for: exercise)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    private var actionBar: some View {
        PillBottomBar {
            Button {
                if dayType == .fullBody {
                    showAddExerciseSheet = true
                } else {
                    showAddExercisePicker = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Add exercise")
                        .font(.uplift.text(15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .foregroundStyle(Color.uplift.fg)
            }
            .buttonStyle(.plain)

            Button {
                showFinishConfirmation = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Finish")
                        .font(.uplift.text(15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(Color.uplift.accent, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .foregroundStyle(Color.uplift.onAccent)
            }
            .buttonStyle(.plain)
        }
    }

    private var overflowMenu: some View {
        Menu {
            Button {
                workoutVM.selectedMode = workoutVM.selectedMode == .highWeightLowReps
                    ? .lowWeightHighReps
                    : .highWeightLowReps
            } label: {
                let nextMode = workoutVM.selectedMode == .highWeightLowReps ? "Endurance" : "Strength"
                Label("Switch to \(nextMode) mode", systemImage: "arrow.triangle.2.circlepath")
            }
            Button(role: .destructive) {
                workoutVM.showCancelConfirmation = true
            } label: {
                Label("Cancel workout", systemImage: "xmark")
            }
        } label: {
            // Visual matches CircleButton (36pt surface1 circle + ellipsis icon) but rendered
            // inline so Menu owns the tap. Using CircleButton directly would nest a Button
            // inside Menu's gesture — unreliable.
            ZStack {
                Circle().fill(Color.uplift.surface1)
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.uplift.fg)
            }
            .frame(width: 36, height: 36)
        }
    }

    // MARK: - Helpers

    private func rowState(for exercise: Exercise, index: Int) -> ExerciseListRow.State {
        let hasSets = workoutVM.currentRecord(for: exercise)?.setsArray.isEmpty == false
        if hasSets { return .completed }
        if exercise.id == activeExerciseID { return .active }
        return .pending(index: index + 1)
    }

    private func setSummary(for exercise: Exercise) -> String {
        // "{N} × {reps}" — N = number of sets in the most recent prior session
        // for this exercise + mode (best signal for "how many sets you usually do");
        // reps = rolling-average best-set reps. Returns "—" if no prior history.
        let priorRecord = exercise.recordsArray
            .filter { $0.trainingMode == workoutVM.selectedMode && $0.session?.isCompleted == true }
            .sorted { ($0.session?.date ?? .distantPast) > ($1.session?.date ?? .distantPast) }
            .first
        let setCount = priorRecord?.setsArray.count ?? 0
        guard setCount > 0,
              let avg = workoutVM.recentAverage(for: exercise, mode: workoutVM.selectedMode)
        else { return "—" }
        return "\(setCount) × \(avg.reps)"
    }

    private func targetWeight(for exercise: Exercise) -> String? {
        if let suggestion = workoutVM.suggestion(for: exercise, mode: workoutVM.selectedMode) {
            return formatWeight(suggestion.targetWeight) + " lb"
        }
        if let avg = workoutVM.recentAverage(for: exercise, mode: workoutVM.selectedMode) {
            return formatWeight(avg.weight) + " lb"
        }
        return nil
    }

    private func formatWeight(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.1f", v)
    }

    private func dayTypeInk(_ dayType: DayType) -> Color {
        switch dayType {
        case .arms:     .uplift.armsInk
        case .legs:     .uplift.legsInk
        case .fullBody: .uplift.fullInk
        }
    }

    private func oppositeDayType(for dayType: DayType) -> DayType {
        switch dayType {
        case .arms:     .legs
        case .legs:     .arms
        case .fullBody: .arms  // arbitrary — Full Body's "+ New" preselects arms
        }
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
}
