//
//  FocusView.swift
//  RockLog
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
    /// Mark this lift done and jump to the next unfinished (nil = mark only).
    var onMarkDoneAndAdvance: (() -> Void)? = nil
    /// Circuit auto-advance. Previous and Next stay on the session-list rule.
    var onJumpTo: ((UUID) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var focusVM: FocusViewModel?
    @State private var showEditExercise = false
    @State private var showRemoveConfirm = false
    @State private var showReplaceSheet = false
    @State private var historyExpanded = false
    /// Note field has the keyboard. Hide the log footer so Cancel/Save stay reachable.
    @State private var isNoteEditing = false
    @AppStorage(MassUnitPreferences.key) private var massUnitRaw = MassUnit.pounds.rawValue

    private var loggedSets: [SetRecord] {
        let _ = workoutVM.setMutationEpoch
        return (workoutVM.currentRecord(for: exercise)?.loggedSetsArray ?? [])
            .sorted { $0.setNumber < $1.setNumber }
    }

    private var loggedSetIDs: [UUID] {
        loggedSets.map(\.id)
    }

    private var plannedSetsForCard: [FocusSetsCard.PreviousSet] {
        let _ = workoutVM.setMutationEpoch
        return (workoutVM.currentRecord(for: exercise)?.plannedSetsArray ?? [])
            .map {
                FocusSetsCard.PreviousSet(
                    weight: $0.weightLbs,
                    reps: $0.reps,
                    isWarmup: $0.isWarmup,
                    isEachSide: $0.isEachSide,
                    isAssisted: $0.isAssisted
                )
            }
    }

    /// Prior completed session for this lift (excludes the active session so
    /// History-edit mode doesn’t treat the workout you’re editing as “last time”).
    private var history: (record: ExerciseRecord?, usedHome: Bool) {
        workoutVM.historyRecord(for: exercise, mode: workoutVM.selectedMode)
    }

    private var lastCompletedRecord: ExerciseRecord? {
        history.record
    }

    /// Last-session sets for inline comparison in FocusSetsCard.
    private var previousSetsForCard: [FocusSetsCard.PreviousSet] {
        guard let record = lastCompletedRecord else { return [] }
        return record.loggedSetsArray
            .sorted { $0.setNumber < $1.setNumber }
            .map {
                FocusSetsCard.PreviousSet(
                    weight: $0.weightLbs,
                    reps: $0.reps,
                    isWarmup: $0.isWarmup,
                    isEachSide: $0.isEachSide,
                    isAssisted: $0.isAssisted
                )
            }
    }

    private var previousDateLabel: String? {
        guard let date = lastCompletedRecord?.session?.date else { return nil }
        return PrevSessionsStripData.relativeLabel(for: date)
    }

    /// Older sessions (excluding the most recent) for the collapsible History strip.
    private var historyEntries: [PrevSessionsStripData.Entry] {
        let lastID = lastCompletedRecord?.id
        let sessions = exercise.completedRecords(
            mode: workoutVM.selectedMode,
            excludingSessionID: workoutVM.activeSession?.id
        )
            .filter { $0.id != lastID }
            .sorted { ($0.session?.date ?? .distantPast) < ($1.session?.date ?? .distantPast) }
            .map { record in
                PrevSessionsStripData.SessionSets(
                    id: record.id,
                    date: record.session?.date ?? .distantPast,
                    sets: record.loggedSetsArray
                        .sorted { $0.setNumber < $1.setNumber }
                        .map { .init(weight: $0.weightLbs, reps: $0.reps) }
                )
            }
        return PrevSessionsStripData.entries(from: sessions)
    }

    var body: some View {
        // The sets card is a List inside this scroll view. A List given an
        // unbounded height grows over the safe area and hides Log set from
        // accessibility. The log bar is a real sibling below the scroll view,
        // so it keeps a frame even when the list is on screen.
        VStack(spacing: 0) {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: 56)   // glass-header clearance
                    if !workoutVM.isRevisitingSavedSession {
                        LiveHealthKitCard(service: workoutVM.healthKitService)
                            .padding(.horizontal, 20)
                    }
                    titleSection
                    // Sets first (with last-session inline) so logging doesn’t
                    // require scrolling past a huge “Last time” card.
                    setsSection
                    if !historyEntries.isEmpty {
                        historyDisclosure
                    }
                }
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.uplift.bgElev)
            .scrollIndicators(.hidden)

            GlassHeader {
                // Hierarchy: Workout (list) → this exercise. Label the parent, not the leaf.
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                        Text("Workout")
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
                .accessibilityIdentifier(AccessibilityID.focusBack)
                .accessibilityLabel("Back to workout")
                .accessibilityHint("Return to the workout exercise list to finish or change lifts")

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
        focusFooter
        }
        .background(Color.uplift.bgElev)
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
            let opening = currentPrefill()
            focusVM?.apply(prefill: opening.0, openingLine: opening.1)
        }
        .onChange(of: massUnitRaw) { old, new in
            let from = MassUnit(rawValue: old) ?? .pounds
            let to = MassUnit(rawValue: new) ?? .pounds
            focusVM?.adoptUnit(to, from: from)
        }
        .onChange(of: exercise.id) { _, _ in
            focusVM = makeFocusVM()
            historyExpanded = false
            isNoteEditing = false
        }
        .onChange(of: loggedSetIDs) { _, ids in
            focusVM?.clearEditIfSetNoLongerListed(ids, restore: currentPrefill().0)
        }
        .sheet(isPresented: $showEditExercise) {
            EditExerciseView(
                exercise: exercise,
                focusDay: workoutVM.activeSession?.day
            )
        }
        .sheet(isPresented: $showReplaceSheet) {
            AddExerciseSheet(
                currentDayType: workoutVM.activeSession?.day
                    ?? DayTypeRegistry.shared.defaultSelection,
                excludedIDs: Set([exercise.id]),
                onPick: { newExercise, _ in
                    workoutVM.replaceExerciseInSession(removing: exercise, with: newExercise)
                    dismiss()
                },
                onCreated: { newExercise in
                    workoutVM.replaceExerciseInSession(removing: exercise, with: newExercise)
                    dismiss()
                }
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
            if let day = workoutVM.activeSession?.day, !day.includesAllExercises {
                Button(ListMutationCopy.removeFromDay(day.rawValue), role: .destructive) {
                    workoutVM.removeExerciseFromDayPlan(exercise, day: day)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This workout only hides it today. Remove from the day to drop it from the plan. Sets logged this session will be deleted.")
        }
    }

    @ViewBuilder
    private var focusFooter: some View {
        if workoutVM.pendingSetUndo != nil || (!isNoteEditing && focusVM != nil) {
            VStack(spacing: 8) {
                if workoutVM.pendingSetUndo != nil {
                    setDeletedToast
                }
                if !isNoteEditing, let focusVM {
                    VStack(spacing: 12) {
                        stepperFooter(focusVM)
                        comparisonLine(focusVM)
                        loadAndStackRow
                        carryUndoLine
                        warmupRampRow(focusVM)
                        actionBar(focusVM)
                    }
                }
            }
            .padding(.top, 8)
            .background {
                Color.uplift.bgElev
                    .ignoresSafeArea(edges: .bottom)
            }
            .accessibilityElement(children: .contain)
        }
    }

    private var setDeletedToast: some View {
        HStack(spacing: 12) {
            Text("Set deleted")
                .font(.uplift.text(15, weight: .semibold))
                .foregroundStyle(Color.uplift.fg)
            Spacer(minLength: 8)
            Button("Undo") {
                workoutVM.undoDeletedSet()
            }
            .font(.uplift.text(15, weight: .bold))
            .foregroundStyle(Color.uplift.accent)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier(AccessibilityID.setUndo)
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.uplift.surface1)
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Sections

    @ViewBuilder
    private var setsSection: some View {
        let prev = previousSetsForCard
        let planned = plannedSetsForCard
        VStack(alignment: .leading, spacing: 6) {
            Text(setsHeading(hasLast: !prev.isEmpty, hasPlan: !planned.isEmpty))
                .textCase(.uppercase)
                .font(.uplift.text(11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Color.uplift.fgDim)
                .padding(.horizontal, 20)

            if let focusVM {
                configuredSetsCard(focusVM, previous: prev, planned: planned)
                    .padding(.horizontal, 20)
            } else {
                FocusSetsCard(
                    sets: loggedSets,
                    previousSets: prev,
                    previousDateLabel: previousDateLabel,
                    plannedSets: planned,
                    onDelete: { set in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            workoutVM.deleteSet(set, from: exercise)
                        }
                    }
                )
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 8)
    }

    private func configuredSetsCard(
        _ focusVM: FocusViewModel,
        previous: [FocusSetsCard.PreviousSet],
        planned: [FocusSetsCard.PreviousSet]
    ) -> some View {
        var card = FocusSetsCard(
            sets: loggedSets,
            previousSets: previous,
            previousDateLabel: previousDateLabel,
            plannedSets: planned,
            selectedSetID: focusVM.editingSetID,
            onSelect: { set in
                focusVM.enterEdit(set: set)
            },
            onDelete: { set in
                withAnimation(.easeInOut(duration: 0.2)) {
                    focusVM.clearEditIfMatching(set, restore: currentPrefill().0)
                    workoutVM.deleteSet(set, from: exercise)
                }
            },
            onSelectPrevious: { prev in
                loadSnapshot(prev)
            },
            onSelectPlanned: { planned in
                loadSnapshot(planned)
            }
        )
        return card
    }

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
                                    .frame(width: 44, height: 44)
                                    .background(Circle().fill(Color.uplift.surface1))
                            }
                            .buttonStyle(.plain)
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityIdentifier(AccessibilityID.focusPrevious)
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
                                .frame(minWidth: 44, minHeight: 44)
                                .background(Capsule().fill(Color.uplift.accent))
                            }
                            .buttonStyle(.plain)
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityIdentifier(AccessibilityID.focusNext)
                            .accessibilityLabel("Next unfinished exercise")
                        }
                    }
                }
            }
            Text(exercise.name)
                .font(.uplift.display(30, weight: .bold))
                .kerning(-0.7)
                .foregroundStyle(Color.uplift.fg)
                .lineLimit(2)

            ExerciseNoteCard(exercise: exercise, isEditing: $isNoteEditing) { text in
                workoutVM.saveExerciseNote(text, for: exercise)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 14)
    }

    private var overflowMenu: some View {
        Menu {
            Button {
                workoutVM.presentSessionReorder = true
            } label: {
                Label("Reorder today's list", systemImage: "arrow.up.arrow.down")
            }
            .accessibilityIdentifier(AccessibilityID.workoutReorder)
            Button {
                showEditExercise = true
            } label: {
                Label("Edit exercise", systemImage: "pencil")
            }
            Button {
                showReplaceSheet = true
            } label: {
                Label(ListMutationCopy.replaceInWorkout, systemImage: "arrow.triangle.swap")
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
            .frame(width: 44, height: 44)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("More options")
    }

    private func makeFocusVM() -> FocusViewModel {
        // Prefill already sets isAssisted when assistance is preferred; no second flip.
        let opening = currentPrefill()
        let model = FocusViewModel(prefill: opening.0)
        model.openingLineText = opening.1
        return model
    }

    private func stepperFooter(_ focusVM: FocusViewModel) -> some View {
        @Bindable var vm = focusVM
        return HStack(spacing: 10) {
            UpliftStepper(
                label: vm.isAssisted ? "Assist" : "Weight",
                unit: MassUnitPreferences.unit.rawValue,
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

    private func comparisonLine(_ focusVM: FocusViewModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !focusVM.openingLineText.isEmpty {
                Text(focusVM.openingLineText)
                    .font(.uplift.text(12, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
                    .accessibilityIdentifier(AccessibilityID.focusComparison)
            }
            if PlateLinePolicy.shows(
                isAssisted: focusVM.isAssisted,
                loadMode: exercise.loadMode,
                stack: workoutVM.stackDefinition(for: exercise)
            ) {
                let unit = MassUnitPreferences.unit
                // focusVM.weight is already in the display unit.
                Text(PlateLinePolicy.readout(displayedWeight: focusVM.weight, unit: unit).text)
                    .font(.uplift.mono(11, weight: .medium))
                    .foregroundStyle(Color.uplift.fgDim)
                    .accessibilityIdentifier(AccessibilityID.focusPlates)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private func actionBar(_ focusVM: FocusViewModel) -> some View {
        @Bindable var vm = focusVM

        return VStack(spacing: 12) {
            restTimerCard()

            // Warm + Log / Update + Done (Done matches Warm size, far right)
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
                    .accessibilityIdentifier(AccessibilityID.focusWarmup)
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
                    .accessibilityIdentifier(
                        FocusLogControl.identifier(isEditing: focusVM.isEditingSet)
                    )

                    doneWithLiftButton
                }

                if focusVM.isEditingSet {
                    Button {
                        let opening = currentPrefill()
                        focusVM.openingLineText = opening.1
                        focusVM.cancelEdit(restore: opening.0)
                    } label: {
                        Text("Cancel edit")
                            .font(.uplift.text(13, weight: .semibold))
                            .foregroundStyle(Color.uplift.fgMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityID.focusCancelEdit)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 12)
    }

    /// Compact like Warm; far right of the log row. Explicit finish, not set-count.
    private var doneWithLiftButton: some View {
        let done = workoutVM.isExerciseDone(for: exercise)
        return Button {
            if done {
                workoutVM.markExerciseNotDone(exercise)
            } else if let onMarkDoneAndAdvance {
                onMarkDoneAndAdvance()
            } else {
                workoutVM.markExerciseDone(exercise)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: done ? "arrow.uturn.backward" : "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(done ? "Resume" : "Done")
                    .font(.uplift.text(14, weight: .semibold))
            }
            .foregroundStyle(done ? Color.uplift.fgMuted : Color.uplift.up)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(done ? Color.uplift.surface1 : Color.uplift.up.opacity(0.14))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        done ? Color.uplift.hairline : Color.uplift.up.opacity(0.35),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.focusDone)
        .accessibilityLabel(done ? "Resume this lift" : "Done with this lift")
        .accessibilityHint(
            done
                ? "Marks the lift not done so you can log more sets"
                : "Marks this lift finished and moves to the next unfinished lift"
        )
    }

    /// The countdown and the on/off switch are separate. Tapping the time,
    /// −15, +15, or Skip does not turn rest off for this lift.
    private func restTimerCard() -> some View {
        @Bindable var wvm = workoutVM
        // Read epoch so toggles refresh the card.
        let _ = wvm.restTimerPreferenceEpoch
        let timerOn = wvm.isRestTimerEnabled(for: exercise)
        // Show live countdown even on a timer-off lift (you may still be resting
        // from the end of a previous super-set).
        let showCountdown = wvm.isResting

        return HStack(spacing: 10) {
            Image(systemName: timerOn
                  ? (showCountdown ? "timer" : "timer.circle.fill")
                  : "timer.circle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(
                    showCountdown
                        ? Color.uplift.accent
                        : (timerOn ? Color.uplift.fg : Color.uplift.fgDim)
                )
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(timerOn ? "Rest · this lift" : "Rest off · this lift")
                    .font(.uplift.text(11, weight: .semibold))
                    .tracking(0.3)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.uplift.fgMuted)
                    .lineLimit(1)

                if showCountdown {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(timeString(from: max(0, wvm.restEndDate?.timeIntervalSince(context.date) ?? 0)))
                            .font(.uplift.mono(26, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Color.uplift.fg)
                            .contentTransition(.numericText())
                    }
                    .accessibilityLabel(restAccessibilityLabel(timerOn: timerOn))
                } else if timerOn {
                    Text(timeString(from: Double(wvm.restSeconds(for: exercise))))
                        .font(.uplift.mono(26, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.uplift.fgMuted)
                        .accessibilityLabel("Rest \(timeString(from: Double(wvm.restSeconds(for: exercise))))")
                } else {
                    Text("Manual only")
                        .font(.uplift.text(15, weight: .semibold))
                        .foregroundStyle(Color.uplift.fgDim)
                }
            }

            Toggle("Rest for this lift", isOn: Binding(
                get: { timerOn },
                set: { wvm.setRestTimerEnabled($0, for: exercise) }
            ))
            .labelsHidden()
            .tint(Color.uplift.accent)
            .accessibilityIdentifier(AccessibilityID.restToggle)

            Spacer(minLength: 4)

            if showCountdown {
                restControlChip("−15") {
                    wvm.addRestTime(-15)
                }
                .accessibilityIdentifier(AccessibilityID.restMinus)
                .accessibilityLabel("Subtract 15 seconds")

                restControlChip("+15") {
                    wvm.addRestTime(15)
                }
                .accessibilityIdentifier(AccessibilityID.restPlus)
                .accessibilityLabel("Add 15 seconds")

                restControlChip("Skip", muted: true) {
                    wvm.skipRest()
                }
                .accessibilityIdentifier(AccessibilityID.restSkip)
                .accessibilityLabel("Skip rest")
            } else {
                Button {
                    wvm.startRest(exercise: exercise)
                } label: {
                    Text("Start")
                        .font(.uplift.text(14, weight: .semibold))
                        .foregroundStyle(Color.uplift.onAccent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.uplift.accent))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start rest timer")
                .accessibilityHint("Starts a \(timeString(from: Double(wvm.restSeconds(for: exercise)))) rest countdown")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
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
        .padding(.horizontal, 16)
    }

    private func restControlChip(_ title: String, muted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.uplift.text(13, weight: .semibold))
                .foregroundStyle(muted ? Color.uplift.fgMuted : Color.uplift.fg)
                .padding(.horizontal, 11)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.uplift.bgElev.opacity(0.7)))
                .overlay {
                    Capsule().strokeBorder(Color.uplift.hairline.opacity(0.8), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func restAccessibilityLabel(timerOn: Bool) -> String {
        if workoutVM.isResting {
            return "Resting, \(timeString(from: workoutVM.remainingRestSeconds)) remaining. Auto-rest for this lift is \(timerOn ? "on" : "off")."
        }
        if timerOn {
            return "Auto-rest on for this lift, \(timeString(from: Double(workoutVM.restSeconds(for: exercise)))). Tap to turn off auto-rest."
        }
        return "Auto-rest off for this lift. Tap to turn on, or use Start for a manual rest."
    }

    private func timeString(from seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Actions

    private func setsHeading(hasLast: Bool, hasPlan: Bool) -> String {
        if hasPlan { return "Sets · last · plan · actual" }
        if hasLast { return "Sets · last vs this" }
        return "This session"
    }

    private func loadSnapshot(_ snapshot: FocusSetsCard.PreviousSet) {
        focusVM?.loadFromHistory(
            weight: snapshot.weight,
            reps: snapshot.reps,
            isWarmup: snapshot.isWarmup,
            isEachSide: snapshot.isEachSide,
            isAssisted: snapshot.isAssisted
        )
    }

    private func currentPrefill() -> (FocusTargetLogic.Prefill, String) {
        let sessionLast: FocusTargetLogic.SessionLastSet? = {
            guard let last = loggedSets.last else { return nil }
            return FocusTargetLogic.sessionSet(from: last)
        }()
        let nextSetNumber = loggedSets.count + 1
        let plannedForNext: FocusTargetLogic.SessionLastSet? = {
            guard nextSetNumber >= 1, nextSetNumber <= plannedSetsForCard.count else { return nil }
            let p = plannedSetsForCard[nextSetNumber - 1]
            return FocusTargetLogic.SessionLastSet(
                weight: p.weight,
                reps: p.reps,
                isWarmup: p.isWarmup,
                isEachSide: p.isEachSide,
                isAssisted: p.isAssisted
            )
        }()
        let historicalOnly = FocusTargetLogic.historicalSet(
            fromPriorSets: lastCompletedRecord?.loggedSetsArray ?? [],
            nextSetNumber: nextSetNumber
        )
        let mode = SetPrefillPreferences.mode
        let preferAssist = plannedForNext?.isAssisted == true
            || historicalOnly?.isAssisted == true
            || sessionLast?.isAssisted == true
            || (sessionLast == nil && historicalOnly == nil && (
                lastCompletedRecord?.loggedSetsArray.contains(where: { $0.isAssisted && !$0.isWarmup }) == true
                || ExerciseAssistPreferences.prefersAssist(for: exercise.id)
                || exercise.loadMode == .assist
            ))
        let body = workoutVM.bodyWeightPoundsForLogging()
        let legacy = FocusTargetLogic.prefill(
            suggestion: workoutVM.suggestion(for: exercise, mode: workoutVM.selectedMode),
            recent: workoutVM.recentAverage(for: exercise, mode: workoutVM.selectedMode),
            lastBest: lastSessionBestSet(),
            sessionLast: nil,
            historicalSet: nil,
            prefillMode: mode,
            preferAssistance: preferAssist,
            bodyWeightLbs: body
        )
        let stack = workoutVM.stackDefinition(for: exercise)
        let asEntered: (Double) -> Double = { effective in
            guard preferAssist else { return effective }
            return LoadMath.entered(fromEffective: effective, mode: .assist, bodyWeight: body)
        }
        let suggestionPair = workoutVM.suggestion(for: exercise, mode: workoutVM.selectedMode).map {
            WeightReps(weight: asEntered($0.targetWeight), reps: $0.targetReps)
        }
        let resolved = StartingWeight.resolve(StartingWeight.Input(
            setNumber: nextSetNumber,
            loggedCount: loggedSets.count,
            plan: plannedForNext.map { WeightReps(weight: $0.weight, reps: $0.reps, isWarmup: $0.isWarmup) },
            lastTimeSameSet: historicalOnly.map { WeightReps(weight: $0.weight, reps: $0.reps) },
            lastTimeBest: lastSessionBestSet().map { WeightReps(weight: asEntered($0.weight), reps: $0.reps) },
            suggestion: suggestionPair,
            sessionLast: sessionLast.map { WeightReps(weight: $0.weight, reps: $0.reps) },
            repeatLastSet: mode == .repeatLast,
            starting: StartingWeightPreferences.choice,
            stack: stack,
            lastAtHome: history.usedHome
        ))
        var weight = resolved.weight
        var reps = resolved.reps
        if let carried = workoutVM.carriedOpening(for: exercise, setNumber: nextSetNumber) {
            weight = carried.displayWeight
            reps = carried.reps
        }
        let unit = MassUnitPreferences.unit
        let displayWeight = MassMath.display(fromPounds: weight, unit: unit)
        let prefill = FocusTargetLogic.Prefill(
            weight: displayWeight,
            reps: reps,
            weightDelta: plannedForNext == nil ? legacy.weightDelta : nil,
            repsDelta: plannedForNext == nil ? legacy.repsDelta : nil,
            isWarmup: WarmupPolicy.nextTag(planSaysWarmup: resolved.isWarmup),
            isEachSide: plannedForNext?.isEachSide ?? sessionLast?.isEachSide ?? false,
            isAssisted: preferAssist || exercise.loadMode == .assist
        )
        return (prefill, resolved.line.text(unit: unit))
    }

    /// Best working set of the most recent completed session — dress baseline
    /// (warmups excluded; matches ProgressionService.bestSet).
    private func lastSessionBestSet() -> (weight: Double, reps: Int)? {
        guard let lastRecord = lastCompletedRecord else { return nil }
        // Use effective load so assisted progress (less assist) tracks correctly.
        let sets = lastRecord.loggedSetsArray.map {
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
        let unit = MassUnitPreferences.unit
        let entered = focusVM.weight
        let weight = MassMath.storedPounds(fromEntered: entered, unit: unit)
        let offered = MassMath.storedPounds(fromEntered: focusVM.offeredWeight, unit: unit)
        let reps = max(1, Int(focusVM.reps.rounded()))
        let isWarmup = focusVM.isWarmup
        let isEachSide = focusVM.isEachSide
        let isAssisted = focusVM.isAssisted || exercise.loadMode == .assist
        focusVM.weight = entered
        ExerciseAssistPreferences.setPrefersAssist(isAssisted, for: exercise.id)
        let loggedTheOffer = MassMath.sameDisplayed(weight, offered, unit: unit)
        let setNumber = (focusVM.editingSetID.flatMap { id in loggedSets.first { $0.id == id }?.setNumber })
            ?? (loggedSets.count + 1)

        if let editingID = focusVM.editingSetID,
           let set = loggedSets.first(where: { $0.id == editingID }) {
            let previousWeight = set.weightLbs
            let repsOnly = MassMath.sameStoredPounds(previousWeight, weight) && set.reps != reps
            workoutVM.updateSet(
                set,
                weight: weight,
                reps: reps,
                isWarmup: isWarmup,
                isEachSide: isEachSide,
                isAssisted: isAssisted,
                enteredValue: entered,
                enteredUnit: unit
            )
            workoutVM.applyCarry(
                exercise: exercise,
                setNumber: set.setNumber,
                newWeight: weight,
                isWarmup: isWarmup,
                loggedTheOffer: MassMath.sameStoredPounds(previousWeight, weight),
                repsOnly: repsOnly
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
            isAssisted: isAssisted,
            offeredWeight: offered,
            loadMode: exercise.loadMode == .bar && isAssisted ? .assist : exercise.loadMode,
            enteredValue: entered,
            enteredUnit: unit
        )
        workoutVM.applyCarry(
            exercise: exercise,
            setNumber: setNumber,
            newWeight: weight,
            isWarmup: isWarmup,
            loggedTheOffer: loggedTheOffer,
            repsOnly: false
        )
        workoutVM.markCarryRowLogged(exercise: exercise, setNumber: setNumber)
        let opening = currentPrefill()
        focusVM.apply(prefill: opening.0, openingLine: opening.1)
        workoutVM.startRestAfterSet(for: exercise)
        if let nextID = workoutVM.circuitNext(after: exercise, wasWarmup: isWarmup) {
            onJumpTo?(nextID)
        }
    }

    private var loadAndStackRow: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(LoadMode.allCases, id: \.self) { mode in
                    Button(mode.title) {
                        exercise.loadMode = mode
                        ModelSave.logged(workoutVM.modelContext, action: "FocusView")
                    }
                }
            } label: {
                Text(exercise.loadMode.title)
                    .font(.uplift.text(12, weight: .semibold))
                    .foregroundStyle(Color.uplift.fg)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.uplift.surface1))
            }
            .accessibilityIdentifier(AccessibilityID.focusLoadMode)

            Menu {
                Section("Weight jumps on this machine") {
                    ForEach(MachineSteps.options(for: MassUnitPreferences.unit), id: \.self) { step in
                        Button(MachineSteps.optionLabel(step, unit: MassUnitPreferences.unit)) {
                            chooseMachineStep(step)
                        }
                    }
                }
                Button("No machine steps") { chooseMachineStep(nil) }
                Button("Forget learned steps") { workoutVM.clearLearnedStack(exercise: exercise) }
            } label: {
                Text(machineStepsPillText)
                    .font(.uplift.text(12, weight: .semibold))
                    .foregroundStyle(Color.uplift.fgMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.uplift.surface1))
            }
            .accessibilityIdentifier(AccessibilityID.stackOverride)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }

    /// Reads the mutation epoch so the pill redraws as soon as a step is picked.
    private var machineStepsPillText: String {
        _ = workoutVM.setMutationEpoch
        return MachineSteps.pillLabel(for: workoutVM.stackDefinition(for: exercise))
    }

    /// Save the step, then move the weight on screen onto a real machine weight right away.
    private func chooseMachineStep(_ step: Double?) {
        workoutVM.applyTypedStack(exercise: exercise, step: step, pins: [])
        guard let focusVM, let stack = workoutVM.stackDefinition(for: exercise) else { return }
        let unit = MassUnitPreferences.unit
        let snapped = MachineSteps.snappedDisplay(focusVM.weight, unit: unit, stack: stack)
        if !MassMath.sameDisplayed(
            MassMath.pounds(fromDisplay: snapped, unit: unit),
            MassMath.pounds(fromDisplay: focusVM.weight, unit: unit),
            unit: unit
        ) {
            focusVM.weight = snapped
            focusVM.userEdited()
        }
    }

    private var carryUndoLine: some View {
        Group {
            if let line = workoutVM.carryLine(for: exercise) {
                HStack(spacing: 8) {
                    Text(line)
                        .font(.uplift.text(12, weight: .medium))
                        .foregroundStyle(Color.uplift.fg)
                    Spacer(minLength: 0)
                    Button("Undo") { workoutVM.undoCarry(for: exercise) }
                        .font(.uplift.text(13, weight: .semibold))
                        .foregroundStyle(Color.uplift.accent)
                        .accessibilityIdentifier(AccessibilityID.focusCarryUndo)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func warmupRampRow(_ focusVM: FocusViewModel) -> some View {
        Group {
            if exercise.suggestWarmupRamp, loggedSets.isEmpty {
                let working = MassMath.storedPounds(fromEntered: focusVM.offeredWeight, unit: MassUnitPreferences.unit)
                let ramp = WarmupPolicy.ramp(workingWeight: working, stack: workoutVM.stackDefinition(for: exercise))
                if !ramp.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(ramp.enumerated()), id: \.offset) { _, step in
                            Button {
                                focusVM.loadFromHistory(weight: MassMath.display(fromPounds: step.weight, unit: MassUnitPreferences.unit), reps: step.reps, isWarmup: true)
                            } label: {
                                Text("\(MassMath.format(step.weight, unit: MassUnitPreferences.unit))×\(step.reps)")
                                    .font(.uplift.mono(11, weight: .semibold))
                                    .foregroundStyle(Color.uplift.customBadge)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color.uplift.customBadge.opacity(0.16)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(AccessibilityID.focusWarmupRamp)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
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
                    ?? Exercise.make(name: "Back Squat", dayType: .legs, muscleGroup: "Quads", sortOrder: 0)
            }(),
            liftIndex: 1,
            totalLifts: 6
        )
    }
    .modelContainer(previewContainer)
    .preferredColorScheme(.dark)
}
