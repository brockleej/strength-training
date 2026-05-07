// strength-training/Views/Workout/FocusView.swift
import SwiftUI
import SwiftData

struct FocusView: View {
    @Bindable var workoutVM: WorkoutViewModel
    let exercise: Exercise
    /// 1-based index of this exercise within the session's exercise list (e.g. "LIFT 3 · 6").
    let liftIndex: Int
    let totalLifts: Int

    @Environment(\.dismiss) private var dismiss

    @State private var focusVM: FocusViewModel?

    /// Sets logged for this exercise in the current session, sorted ascending by set#.
    private var loggedSets: [SetRecord] {
        let record = workoutVM.currentRecord(for: exercise)
        return (record?.setsArray ?? []).sorted { $0.setNumber < $1.setNumber }
    }

    private var historyEntries: [PrevSessionsStrip.Entry] {
        PrevSessionsStripData.shape(for: exercise, mode: workoutVM.selectedMode)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: 56)  // glass-header clearance
                    LiveHealthKitCard(service: workoutVM.healthKitService)
                        .padding(.horizontal, 20)
                    titleSection
                    PrevSessionsStrip(entries: historyEntries)
                        .padding(.bottom, 14)
                    if workoutVM.showDeleteHint {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.uplift.accent)
                            Text("Long press a set to delete it")
                                .font(.uplift.text(12, weight: .medium))
                                .foregroundStyle(Color.uplift.fgMuted)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.uplift.accentSoft)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    FocusSetsCard(sets: loggedSets) { set in
                        workoutVM.deleteSet(set, from: exercise)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 280)  // clearance for stepper footer + pill action bar (Task 14)
            }
            .background(Color.uplift.bgElev)
            .scrollIndicators(.hidden)

            GlassHeader {
                CircleButton(icon: "chevron.left") { dismiss() }
                Spacer()
                VStack(spacing: 0) {
                    Text("LIFT \(liftIndex) · \(totalLifts)".uppercased())
                        .font(.uplift.text(11, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(Color.uplift.fgMuted)
                }
                Spacer()
                overflowMenu
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let focusVM {
                VStack(spacing: 12) {
                    FocusStepperFooter(focusVM: focusVM)
                    FocusActionBar(focusVM: focusVM) {
                        logSet()
                    }
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
                focusVM = makeFocusViewModel()
            }
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(dayTypeInk(exercise.dayType))
                    .frame(width: 4, height: 16)
                    .clipShape(Capsule())
                Text("\(exercise.dayType.rawValue) DAY")
                    .font(.uplift.text(11, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(dayTypeInk(exercise.dayType))
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
                let nextMode = workoutVM.selectedMode == .highWeightLowReps ? "Endurance" : "Strength"
                Label("Switch to \(nextMode) mode", systemImage: "arrow.triangle.2.circlepath")
            }
        } label: {
            // Visual matches CircleButton, rendered inline so Menu owns the tap.
            ZStack {
                Circle().fill(Color.uplift.surface1)
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.uplift.fg)
            }
            .frame(width: 36, height: 36)
        }
    }

    private func dayTypeInk(_ dayType: DayType) -> Color {
        switch dayType {
        case .arms:     .uplift.armsInk
        case .legs:     .uplift.legsInk
        case .fullBody: .uplift.fullInk
        }
    }

    // MARK: - FocusViewModel construction

    private func makeFocusViewModel() -> FocusViewModel {
        let suggestion = workoutVM.suggestion(for: exercise, mode: workoutVM.selectedMode)
        let recent = workoutVM.recentAverage(for: exercise, mode: workoutVM.selectedMode)

        // Initial value resolution: suggestion target if available, else recent average,
        // else default for first-time users (0 × 1).
        let initialWeight = suggestion?.targetWeight ?? recent?.weight ?? 0
        let initialReps = suggestion?.targetReps ?? recent?.reps ?? 1

        // Build target only when the suggestion's basis is `.consistent` — the
        // algorithm has decided the user is ready for a weight bump. Other bases
        // (`.notEnoughData` / `.improving`) shouldn't trigger the blue/bumped UI.
        var target: FocusViewModel.Target?
        if let s = suggestion, s.basis == .consistent, let r = recent {
            let weightDelta = max(0, s.targetWeight - r.weight)
            let repsDelta = max(0, s.targetReps - r.reps)
            if weightDelta > 0 || repsDelta > 0 {
                target = .init(
                    weight: s.targetWeight,
                    weightDelta: weightDelta,
                    reps: s.targetReps,
                    repsDelta: repsDelta
                )
            }
        }
        return FocusViewModel(
            initialWeight: initialWeight,
            initialReps: initialReps,
            target: target
        )
    }

    private func logSet() {
        guard let focusVM else { return }
        workoutVM.addSet(
            exercise: exercise,
            weight: focusVM.weight,
            reps: focusVM.reps
        )
        focusVM.setLogged()
    }
}
