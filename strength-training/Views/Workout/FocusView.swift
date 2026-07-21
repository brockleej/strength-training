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

    @Environment(\.dismiss) private var dismiss
    @State private var focusVM: FocusViewModel?
    @State private var showEditExercise = false
    @State private var showRemoveConfirm = false

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
        let modeRaw = workoutVM.selectedMode.rawValue
        return exercise.recordsArray
            .filter { $0.trainingMode.rawValue == modeRaw && $0.session?.isCompleted == true }
            .max { ($0.session?.date ?? .distantPast) < ($1.session?.date ?? .distantPast) }
    }

    /// Older sessions (excluding the most recent) for the horizontal strip —
    /// full sets including warmups so history matches what you logged.
    private var historyEntries: [PrevSessionsStripData.Entry] {
        let modeRaw = workoutVM.selectedMode.rawValue
        let lastID = lastCompletedRecord?.id
        let sessions = exercise.recordsArray
            .filter {
                $0.trainingMode.rawValue == modeRaw
                    && $0.session?.isCompleted == true
                    && $0.id != lastID
            }
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
                        Text("Earlier sessions")
                            .textCase(.uppercase)
                            .font(.uplift.text(11, weight: .semibold))
                            .tracking(0.4)
                            .foregroundStyle(Color.uplift.fgDim)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 6)
                        PrevSessionsStrip(entries: historyEntries)
                            .padding(.bottom, 14)
                    } else if lastSessionReference == nil {
                        PrevSessionsStrip(entries: [])
                            .padding(.bottom, 14)
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
                focusVM = FocusViewModel(prefill: currentPrefill())
            }
        }
        .onChange(of: workoutVM.selectedMode) {
            focusVM?.apply(prefill: currentPrefill())
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
            Button("Remove from this workout", role: .destructive) {
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
                Label("Remove from workout", systemImage: "minus.circle")
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

    private func stepperFooter(_ focusVM: FocusViewModel) -> some View {
        @Bindable var vm = focusVM
        return HStack(spacing: 10) {
            UpliftStepper(
                label: "Weight", unit: "lb",
                value: $vm.weight, step: 5, range: 0...1000,
                targetDelta: focusVM.weightDelta,
                onUserEdit: { focusVM.userEdited() },
                icon: "scalemass.fill", iconTint: .uplift.weightTint
            )
            UpliftStepper(
                label: "Reps",
                value: $vm.reps, step: 1, range: 1...100,
                targetDelta: focusVM.repsDelta,
                onUserEdit: { focusVM.userEdited() },
                icon: "repeat", iconTint: .uplift.fgMuted
            )
        }
        .padding(.horizontal, 12)
    }

    private func actionBar(_ focusVM: FocusViewModel) -> some View {
        @Bindable var vm = focusVM

        return VStack(spacing: 12) {
            restTimerCard(vm)

            // Warm toggle + Log / Update
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

    /// Large rest timer strip: big countdown, on/off, +30s / Skip while resting.
    private func restTimerCard(_ vm: FocusViewModel) -> some View {
        VStack(spacing: 12) {
            Button {
                vm.toggleRestTimer()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: vm.isRestTimerEnabled
                          ? (vm.isResting ? "timer" : "timer.circle.fill")
                          : "timer.circle")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(
                            vm.isResting
                                ? Color.uplift.accent
                                : (vm.isRestTimerEnabled ? Color.uplift.fg : Color.uplift.fgDim)
                        )
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.isRestTimerEnabled ? "Rest" : "Rest off")
                            .font(.uplift.text(12, weight: .semibold))
                            .tracking(0.3)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.uplift.fgMuted)

                        if vm.isRestTimerEnabled {
                            if vm.isResting {
                                TimelineView(.periodic(from: .now, by: 1)) { context in
                                    Text(timeString(from: max(0, vm.restEndDate?.timeIntervalSince(context.date) ?? 0)))
                                        .font(.uplift.mono(34, weight: .bold))
                                        .monospacedDigit()
                                        .foregroundStyle(Color.uplift.fg)
                                        .contentTransition(.numericText())
                                }
                            } else {
                                Text(timeString(from: vm.targetRestSeconds))
                                    .font(.uplift.mono(34, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundStyle(Color.uplift.fgMuted)
                            }
                        } else {
                            Text("Tap to enable")
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
                        .fill(vm.isResting ? Color.uplift.accent.opacity(0.14) : Color.uplift.surface1)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            vm.isResting ? Color.uplift.accent.opacity(0.35) : Color.uplift.hairline,
                            lineWidth: 1
                        )
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(restAccessibilityLabel(vm))

            if vm.isResting {
                HStack(spacing: 10) {
                    Button {
                        vm.addRestTime(30)
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
                        vm.skipRest()
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

    private func restAccessibilityLabel(_ vm: FocusViewModel) -> String {
        if !vm.isRestTimerEnabled { return "Rest timer off, tap to enable" }
        if vm.isResting {
            return "Resting, \(timeString(from: vm.remainingRestSeconds)) remaining, tap to disable"
        }
        return "Rest timer ready, \(timeString(from: vm.targetRestSeconds)), tap to disable"
    }

    private func timeString(from seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Actions

    private func currentPrefill() -> FocusTargetLogic.Prefill {
        FocusTargetLogic.prefill(
            suggestion: workoutVM.suggestion(for: exercise, mode: workoutVM.selectedMode),
            recent: workoutVM.recentAverage(for: exercise, mode: workoutVM.selectedMode),
            lastBest: lastSessionBestSet()
        )
    }

    /// Best (heaviest) set of the most recent completed session in the current
    /// mode — the dress baseline. Sets are passed as-logged (warmups included),
    /// matching the algorithm's `bestSet` convention via FocusTargetLogic.lastBest.
    private func lastSessionBestSet() -> (weight: Double, reps: Int)? {
        let modeRaw = workoutVM.selectedMode.rawValue
        let lastRecord = exercise.recordsArray
            .filter { $0.trainingMode.rawValue == modeRaw && $0.session?.isCompleted == true }
            .max { ($0.session?.date ?? .distantPast) < ($1.session?.date ?? .distantPast) }
        guard let sets = lastRecord?.setsArray.map({ (weight: $0.weightLbs, reps: $0.reps) })
        else { return nil }
        return FocusTargetLogic.lastBest(from: sets)
    }

    private func commitSet(_ focusVM: FocusViewModel) {
        let weight = focusVM.weight
        let reps = max(1, Int(focusVM.reps))
        let isWarmup = focusVM.isWarmup

        if let editingID = focusVM.editingSetID,
           let set = loggedSets.first(where: { $0.id == editingID }) {
            // Correct an existing set — no PR celebration, no rest-timer restart.
            workoutVM.updateSet(set, weight: weight, reps: reps, isWarmup: isWarmup)
            focusVM.clearSelectionAfterSave()
            return
        }

        workoutVM.addSet(exercise: exercise, weight: weight, reps: reps, isWarmup: isWarmup)
        focusVM.setLogged()
        // Keep Warm on after a warm-up log (ramp sets); clear after a working set.
        if !isWarmup {
            focusVM.isWarmup = false
        }
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
