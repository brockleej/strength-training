//
//  FocusView.swift
//  strength-training
//
//  Per-exercise logging screen: glass header, live HK card, title, history
//  strip, sets card, sticky steppers + Log set pill bar.
//

import SwiftUI
import SwiftData

struct FocusView: View {
    @Bindable var workoutVM: WorkoutViewModel
    let exercise: Exercise
    let liftIndex: Int      // 1-based position in the session list
    let totalLifts: Int
    var hasNext: Bool = false
    var hasPrevious: Bool = false
    var onNext: (() -> Void)? = nil
    var onPrevious: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var focusVM: FocusViewModel?
    @State private var showEditExercise = false
    @State private var showRemoveConfirm = false
    @State private var historyExpanded = false

    private var loggedSets: [SetRecord] {
        (workoutVM.currentRecord(for: exercise)?.setsArray ?? [])
            .sorted { $0.setNumber < $1.setNumber }
    }

    /// Most recent completed session for this lift in the active mode (all sets,
    /// including warm-up ramps), for the “Last time” reference card.
    private var lastSessionReference: (dateLabel: String, sets: [LastSessionReferenceCard.SetLine])? {
        guard let record = lastCompletedRecord else { return nil }
        let sets = record.setsArray
            .sorted { $0.setNumber < $1.setNumber }
            .enumerated()
            .map { index, set in
                LastSessionReferenceCard.SetLine(
                    id: index + 1,
                    weight: set.weightLbs,
                    reps: set.reps,
                    isWarmup: set.isWarmup
                )
            }
        guard !sets.isEmpty else { return nil }
        let date = record.session?.date ?? .distantPast
        return (
            dateLabel: PrevSessionsStripData.relativeLabel(for: date),
            sets: sets
        )
    }

    private var lastCompletedRecord: ExerciseRecord? {
        exercise.lastCompletedRecord(mode: workoutVM.selectedMode)
    }

    /// Older sessions (excluding the most recent) for the collapsible History strip.
    private var historyEntries: [PrevSessionsStripData.Entry] {
        let lastID = lastCompletedRecord?.id
        let sessions = exercise.completedRecords(mode: workoutVM.selectedMode)
            .filter { $0.id != lastID }
            .sorted { ($0.session?.date ?? .distantPast) < ($1.session?.date ?? .distantPast) }
            .map { record in
                PrevSessionsStripData.SessionSets(
                    id: record.id,
                    date: record.session?.date ?? .distantPast,
                    sets: record.setsArray
                        .sorted { $0.setNumber < $1.setNumber }
                        .map { .init(weight: $0.weightLbs, reps: $0.reps) }
                )
            }
        return PrevSessionsStripData.entries(from: sessions)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: 56)   // glass-header clearance
                    LiveHealthKitCard(service: workoutVM.healthKitService)
                        .padding(.horizontal, 20)
                    titleSection
                    if let last = lastSessionReference {
                        LastSessionReferenceCard(
                            dateLabel: last.dateLabel,
                            sets: last.sets,
                            onSelectSet: { weight, reps, isWarmup in
                                guard let focusVM else { return }
                                focusVM.loadFromHistory(weight: weight, reps: reps, isWarmup: isWarmup)
                            }
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                    }
                    if !historyEntries.isEmpty {
                        historyDisclosure
                    }
                    if let focusVM {
                        Text("This session")
                            .textCase(.uppercase)
                            .font(.uplift.text(11, weight: .semibold))
                            .tracking(0.4)
                            .foregroundStyle(Color.uplift.fgDim)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 6)
                        FocusSetsCard(
                            sets: loggedSets,
                            selectedSetID: focusVM.editingSetID,
                            onSelect: { set in
                                focusVM.toggleEdit(set: set, prefillIfCancel: currentPrefill())
                            },
                            onDelete: { set in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    focusVM.clearEditIfMatching(set, restore: currentPrefill())
                                    workoutVM.deleteSet(set, from: exercise)
                                }
                            }
                        )
                        .padding(.horizontal, 20)
                    } else {
                        FocusSetsCard(
                            sets: loggedSets,
                            onSelect: { _ in },
                            onDelete: { set in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    workoutVM.deleteSet(set, from: exercise)
                                }
                            }
                        )
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 16)
            }
            .background(Color.uplift.bgElev)
            .scrollIndicators(.hidden)

            GlassHeader {
                CircleButton(icon: "chevron.left", accessibilityLabel: "Back to exercise list") {
                    dismiss()
                }
                Spacer()
                Text("Lift \(liftIndex) · \(totalLifts)")
                    .textCase(.uppercase)
                    .font(.uplift.text(11, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(Color.uplift.fgMuted)
                Spacer()
                overflowMenu
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let focusVM {
                VStack(spacing: 12) {
                    stepperFooter(focusVM)
                    actionBar(focusVM)
                }
                .padding(.top, 8)
                .background {
                    // Content fades out under the sticky footer
                    LinearGradient(
                        colors: [Color.uplift.bgElev.opacity(0), Color.uplift.bgElev],
                        startPoint: .top, endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: .bottom)
                }
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(item: $workoutVM.pendingCelebration) { context in
            PRCelebrationView(context: context) {
                workoutVM.pendingCelebration = nil
            }
        }
        .onAppear {
            if focusVM == nil {
                focusVM = makeFocusVM()
            }
        }
        .onChange(of: workoutVM.selectedMode) {
            focusVM?.apply(prefill: currentPrefill())
        }
        .onChange(of: exercise.id) { _, _ in
            focusVM = makeFocusVM()
            historyExpanded = false
        }
        .sheet(isPresented: $showEditExercise) {
            EditExerciseView(
                exercise: exercise,
                focusDay: workoutVM.activeSession?.day
            )
        }
        .confirmationDialog(
            "Remove \(exercise.name)?",
            isPresented: $showRemoveConfirm,
            titleVisibility: .visible
        ) {
            Button(ListMutationCopy.removeFromWorkout, role: .destructive) {
                workoutVM.removeExerciseFromSession(exercise)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Stays in your library. Sets logged this session for this exercise will be deleted.")
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Capsule()
                    .fill(exercise.day.upliftInk)
                    .frame(width: 4, height: 16)
                Text(exercise.isUnassigned
                     ? "Library"
                     : exercise.dayTypeNames.joined(separator: " · "))
                    .textCase(.uppercase)
                    .font(.uplift.text(11, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(exercise.day.upliftInk)
                Spacer(minLength: 0)
                if hasNext || hasPrevious {
                    HStack(spacing: 8) {
                        if hasPrevious {
                            Button {
                                onPrevious?()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.uplift.fgMuted)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(Color.uplift.surface1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Previous exercise")
                        }
                        if hasNext {
                            Button {
                                onNext?()
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Next")
                                        .font(.uplift.text(13, weight: .semibold))
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .foregroundStyle(Color.uplift.onAccent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(Capsule().fill(Color.uplift.accent))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Next exercise")
                        }
                    }
                }
            }
            Text(exercise.name)
                .font(.uplift.display(30, weight: .bold))
                .kerning(-0.7)
                .foregroundStyle(Color.uplift.fg)
                .lineLimit(2)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 14)
    }

    private var overflowMenu: some View {
        Menu {
            Button {
                showEditExercise = true
            } label: {
                Label("Edit exercise", systemImage: "pencil")
            }
            Button {
                workoutVM.selectedMode = workoutVM.selectedMode == .highWeightLowReps
                    ? .lowWeightHighReps
                    : .highWeightLowReps
            } label: {
                let next = workoutVM.selectedMode == .highWeightLowReps ? "Endurance" : "Strength"
                Label("Switch to \(next) mode", systemImage: "arrow.triangle.2.circlepath")
            }
            Button(role: .destructive) {
                showRemoveConfirm = true
            } label: {
                Label(ListMutationCopy.removeFromWorkout, systemImage: "minus.circle")
            }
        } label: {
            // Matches CircleButton visuals; Menu owns the tap.
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

    private func makeFocusVM() -> FocusViewModel {
        let sessionLast = loggedSets.last
        let prefersAssist = sessionLast == nil
            && ExerciseAssistPreferences.prefersAssist(for: exercise.id)
        return FocusViewModel(prefill: currentPrefill(), prefersAssist: prefersAssist)
    }

    private func stepperFooter(_ focusVM: FocusViewModel) -> some View {
        @Bindable var vm = focusVM
        return HStack(spacing: 10) {
            UpliftStepper(
                label: vm.isAssisted ? "Assist" : "Weight",
                unit: "lb",
                value: $vm.weight, step: focusVM.weightStep, range: 0...1000,
                targetDelta: vm.isAssisted ? nil : focusVM.weightDelta,
                onUserEdit: { focusVM.userEdited() },
                onStepHintTap: { focusVM.cycleWeightStep() },
                flagTitle: "Assist",
                flagIsOn: vm.isAssisted,
                onFlagTap: {
                    vm.isAssisted.toggle()
                    ExerciseAssistPreferences.setPrefersAssist(vm.isAssisted, for: exercise.id)
                    focusVM.userEdited()
                },
                flagAccessibilityHint: "Assisted bodyweight lift. Enter machine assistance; tonnage uses body weight minus assist.",
                icon: "scalemass.fill",
                iconTint: .uplift.weightTint
            )
            UpliftStepper(
                label: "Reps",
                value: $vm.reps, step: 1, range: 1...100,
                targetDelta: focusVM.repsDelta,
                onUserEdit: { focusVM.userEdited() },
                flagTitle: "Sides",
                flagIsOn: vm.isEachSide,
                onFlagTap: { vm.isEachSide.toggle() },
                flagAccessibilityHint: "Marks reps as left and right — volume counts both sides",
                icon: "repeat", iconTint: .uplift.fgMuted
            )
        }
        .padding(.horizontal, 12)
    }

    private func actionBar(_ focusVM: FocusViewModel) -> some View {
        @Bindable var vm = focusVM

        return VStack(spacing: 12) {
            restTimerCard()

            // Warm + Log / Update
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Button {
                        vm.isWarmup.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: vm.isWarmup ? "flame.fill" : "flame")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Warm")
                                .font(.uplift.text(14, weight: .semibold))
                        }
                        .foregroundStyle(vm.isWarmup ? Color.uplift.customBadge : Color.uplift.fgMuted)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(vm.isWarmup ? Color.uplift.customBadge.opacity(0.16) : Color.uplift.surface1)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    vm.isWarmup ? Color.uplift.customBadge.opacity(0.45) : Color.uplift.hairline,
                                    lineWidth: 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(vm.isWarmup ? "Warm-up on" : "Warm-up off")
                    .accessibilityAddTraits(vm.isWarmup ? [.isSelected] : [])

                    Button {
                        commitSet(focusVM)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: focusVM.isEditingSet ? "pencil.circle.fill" : "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                            Text(focusVM.isEditingSet ? "Update set" : "Log set")
                                .font(.uplift.text(15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            (focusVM.isEditingSet ? Color.uplift.accentDeep : Color.uplift.accent),
                            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                        )
                        .foregroundStyle(Color.uplift.onAccent)
                    }
                    .buttonStyle(.plain)
                }

                if focusVM.isEditingSet {
                    Button {
                        focusVM.cancelEdit(restore: currentPrefill())
                    } label: {
                        Text("Cancel edit")
                            .font(.uplift.text(13, weight: .semibold))
                            .foregroundStyle(Color.uplift.fgMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 12)
    }

    /// Countdown is session-wide; on/off is remembered per exercise (supersets).
    private func restTimerCard() -> some View {
        @Bindable var wvm = workoutVM
        // Read epoch so toggles refresh the card.
        let _ = wvm.restTimerPreferenceEpoch
        let timerOn = wvm.isRestTimerEnabled(for: exercise)
        // Show live countdown even on a timer-off lift (you may still be resting
        // from the end of a previous super-set).
        let showCountdown = wvm.isResting

        return VStack(spacing: 12) {
            Button {
                wvm.toggleRestTimer(for: exercise)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: timerOn
                          ? (showCountdown ? "timer" : "timer.circle.fill")
                          : "timer.circle")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(
                            showCountdown
                                ? Color.uplift.accent
                                : (timerOn ? Color.uplift.fg : Color.uplift.fgDim)
                        )
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(timerOn ? "Rest · this lift" : "Rest off · this lift")
                            .font(.uplift.text(12, weight: .semibold))
                            .tracking(0.3)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.uplift.fgMuted)

                        if showCountdown {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                Text(timeString(from: max(0, wvm.restEndDate?.timeIntervalSince(context.date) ?? 0)))
                                    .font(.uplift.mono(34, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundStyle(Color.uplift.fg)
                                    .contentTransition(.numericText())
                            }
                        } else if timerOn {
                            Text(timeString(from: wvm.targetRestSeconds))
                                .font(.uplift.mono(34, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(Color.uplift.fgMuted)
                        } else {
                            Text("No rest after sets")
                                .font(.uplift.text(18, weight: .semibold))
                                .foregroundStyle(Color.uplift.fgDim)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(showCountdown ? Color.uplift.accent.opacity(0.14) : Color.uplift.surface1)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            showCountdown ? Color.uplift.accent.opacity(0.35) : Color.uplift.hairline,
                            lineWidth: 1
                        )
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(restAccessibilityLabel(timerOn: timerOn))
            .accessibilityHint("Remembers on or off for this exercise only — use off during a superset, on for the last lift")

            if showCountdown {
                HStack(spacing: 10) {
                    Button {
                        wvm.addRestTime(30)
                    } label: {
                        Text("+30s")
                            .font(.uplift.text(16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.uplift.surface1)
                            )
                            .foregroundStyle(Color.uplift.fg)
                    }
                    .buttonStyle(.plain)

                    Button {
                        wvm.skipRest()
                    } label: {
                        Text("Skip rest")
                            .font(.uplift.text(16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.uplift.surface1)
                            )
                            .foregroundStyle(Color.uplift.fgMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func restAccessibilityLabel(timerOn: Bool) -> String {
        if workoutVM.isResting {
            return "Resting, \(timeString(from: workoutVM.remainingRestSeconds)) remaining. Timer for this lift is \(timerOn ? "on" : "off"). Tap to toggle this lift."
        }
        if timerOn {
            return "Rest on for this lift, \(timeString(from: workoutVM.targetRestSeconds)), tap to turn off for this lift"
        }
        return "Rest off for this lift, tap to turn on for this lift"
    }

    private func timeString(from seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Actions

    private func currentPrefill() -> FocusTargetLogic.Prefill {
        // Prefer the last set already logged this session (same exercise) so
        // supersets restore weight/reps when you hop back.
        let sessionLast: FocusTargetLogic.SessionLastSet? = {
            guard let last = loggedSets.last else { return nil }
            return FocusTargetLogic.SessionLastSet(
                weight: last.weightLbs,
                reps: last.reps,
                isWarmup: last.isWarmup,
                isEachSide: last.isEachSide,
                isAssisted: last.isAssisted
            )
        }()
        return FocusTargetLogic.prefill(
            suggestion: workoutVM.suggestion(for: exercise, mode: workoutVM.selectedMode),
            recent: workoutVM.recentAverage(for: exercise, mode: workoutVM.selectedMode),
            lastBest: lastSessionBestSet(),
            sessionLast: sessionLast
        )
    }

    /// Best working set of the most recent completed session — dress baseline
    /// (warmups excluded; matches ProgressionService.bestSet).
    private func lastSessionBestSet() -> (weight: Double, reps: Int)? {
        guard let lastRecord = lastCompletedRecord else { return nil }
        // Use effective load so assisted progress (less assist) tracks correctly.
        let sets = lastRecord.setsArray.map {
            (weight: $0.effectiveLoadLbs(), reps: $0.reps, isWarmup: $0.isWarmup)
        }
        return FocusTargetLogic.lastBest(from: sets)
    }

    private var historyDisclosure: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    historyExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("History")
                        .textCase(.uppercase)
                        .font(.uplift.text(11, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(Color.uplift.fgDim)
                    Text("\(historyEntries.count)")
                        .font(.uplift.mono(11, weight: .semibold))
                        .foregroundStyle(Color.uplift.fgFaint)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.uplift.fgDim)
                        .rotationEffect(.degrees(historyExpanded ? 90 : 0))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("History, \(historyEntries.count) earlier sessions")
            .accessibilityHint(historyExpanded ? "Collapse" : "Expand earlier sessions")

            if historyExpanded {
                PrevSessionsStrip(entries: historyEntries)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.bottom, historyExpanded ? 0 : 6)
    }

    private func commitSet(_ focusVM: FocusViewModel) {
        // Snap to half-pound grid so 0.5 steps stay clean.
        let weight = (focusVM.weight * 2).rounded() / 2
        let reps = max(1, Int(focusVM.reps.rounded()))
        let isWarmup = focusVM.isWarmup
        let isEachSide = focusVM.isEachSide
        let isAssisted = focusVM.isAssisted
        focusVM.weight = weight
        ExerciseAssistPreferences.setPrefersAssist(isAssisted, for: exercise.id)

        if let editingID = focusVM.editingSetID,
           let set = loggedSets.first(where: { $0.id == editingID }) {
            workoutVM.updateSet(
                set,
                weight: weight,
                reps: reps,
                isWarmup: isWarmup,
                isEachSide: isEachSide,
                isAssisted: isAssisted
            )
            focusVM.clearSelectionAfterSave()
            return
        }

        workoutVM.addSet(
            exercise: exercise,
            weight: weight,
            reps: reps,
            isWarmup: isWarmup,
            isEachSide: isEachSide,
            isAssisted: isAssisted
        )
        focusVM.setLogged()
        workoutVM.startRestAfterSet(for: exercise)
    }
}

#Preview {
    NavigationStack {
        FocusView(
            workoutVM: WorkoutViewModel(
                modelContext: previewContainer.mainContext,
                healthKitService: HealthKitWorkoutService()
            ),
            exercise: {
                let descriptor = FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.sortOrder)])
                return (try? previewContainer.mainContext.fetch(descriptor))?.first
                    ?? Exercise(name: "Back Squat", dayType: .legs, muscleGroup: "Quads", sortOrder: 0)
            }(),
            liftIndex: 1,
            totalLifts: 6
        )
    }
    .modelContainer(previewContainer)
    .preferredColorScheme(.dark)
}
