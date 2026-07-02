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

    private var loggedSets: [SetRecord] {
        (workoutVM.currentRecord(for: exercise)?.setsArray ?? [])
            .sorted { $0.setNumber < $1.setNumber }
    }

    /// Prior completed sessions of this exercise in the current mode,
    /// oldest-first, warmups excluded.
    private var historyEntries: [PrevSessionsStripData.Entry] {
        let modeRaw = workoutVM.selectedMode.rawValue
        let sessions = exercise.recordsArray
            .filter { $0.trainingMode.rawValue == modeRaw && $0.session?.isCompleted == true }
            .sorted { ($0.session?.date ?? .distantPast) < ($1.session?.date ?? .distantPast) }
            .map { record in
                PrevSessionsStripData.SessionSets(
                    id: record.id,
                    date: record.session?.date ?? .distantPast,
                    sets: record.setsArray
                        .filter { !$0.isWarmup }
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
                    PrevSessionsStrip(entries: historyEntries)
                        .padding(.bottom, 14)
                    FocusSetsCard(sets: loggedSets) { set in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            workoutVM.deleteSet(set, from: exercise)
                        }
                    }
                    .padding(.horizontal, 20)
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
    }

    // MARK: - Sections

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Capsule()
                    .fill(exercise.dayType.upliftInk)
                    .frame(width: 4, height: 16)
                Text("\(exercise.dayType.rawValue) day")
                    .textCase(.uppercase)
                    .font(.uplift.text(11, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(exercise.dayType.upliftInk)
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
                workoutVM.selectedMode = workoutVM.selectedMode == .highWeightLowReps
                    ? .lowWeightHighReps
                    : .highWeightLowReps
            } label: {
                let next = workoutVM.selectedMode == .highWeightLowReps ? "Endurance" : "Strength"
                Label("Switch to \(next) mode", systemImage: "arrow.triangle.2.circlepath")
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
                onUserEdit: { focusVM.userEdited() }
            )
            UpliftStepper(
                label: "Reps",
                value: $vm.reps, step: 1, range: 1...100,
                targetDelta: focusVM.repsDelta,
                onUserEdit: { focusVM.userEdited() }
            )
        }
        .padding(.horizontal, 12)
    }

    private func actionBar(_ focusVM: FocusViewModel) -> some View {
        PillBottomBar {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.uplift.fgMuted)
                        .accessibilityHidden(true)
                    Text(WorkoutFormat.elapsed(context.date.timeIntervalSince(focusVM.restAnchor)))
                        .font(.uplift.mono(14, weight: .semibold))
                        .foregroundStyle(Color.uplift.fg)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Rest time")
                .accessibilityValue(WorkoutFormat.elapsed(context.date.timeIntervalSince(focusVM.restAnchor)))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)

            Button {
                logSet(focusVM)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Log set")
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

    // MARK: - Actions

    private func currentPrefill() -> FocusTargetLogic.Prefill {
        FocusTargetLogic.prefill(
            suggestion: workoutVM.suggestion(for: exercise, mode: workoutVM.selectedMode),
            recent: workoutVM.recentAverage(for: exercise, mode: workoutVM.selectedMode),
            lastBest: lastSessionBestSet()
        )
    }

    /// Best (heaviest) non-warmup set of the most recent completed session in
    /// the current mode — the dress baseline (mirrors the algorithm's
    /// heaviest-set convention).
    private func lastSessionBestSet() -> (weight: Double, reps: Int)? {
        let modeRaw = workoutVM.selectedMode.rawValue
        let lastRecord = exercise.recordsArray
            .filter { $0.trainingMode.rawValue == modeRaw && $0.session?.isCompleted == true }
            .max { ($0.session?.date ?? .distantPast) < ($1.session?.date ?? .distantPast) }
        guard let best = lastRecord?.setsArray
            .filter({ !$0.isWarmup })
            .max(by: { $0.weightLbs < $1.weightLbs })
        else { return nil }
        return (best.weightLbs, best.reps)
    }

    private func logSet(_ focusVM: FocusViewModel) {
        workoutVM.addSet(exercise: exercise, weight: focusVM.weight, reps: Int(focusVM.reps))
        focusVM.setLogged()
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
