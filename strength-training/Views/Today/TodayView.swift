//
//  TodayView.swift
//  strength-training
//
//  Workout-tab root when no session is active. Day picker + start/resume,
//  suspended-session UX, Yesterday row, This Week card.
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @Bindable var workoutVM: WorkoutViewModel

    @State private var todayVM = TodayViewModel()
    /// Observe split edits so the day picker refreshes after Settings changes.
    @State private var dayCatalog = DayTypeRegistry.shared
    /// Day type pending the "Replace Current Workout?" confirmation.
    @State private var confirmingDayType: DayType?
    @State private var showGymPass = false
    @State private var showDayPlanEditor = false

    @Query(
        filter: #Predicate<WorkoutSession> { $0.isCompleted == true },
        sort: \WorkoutSession.date,
        order: .reverse
    )
    private var completedSessions: [WorkoutSession]

    private var mostRecent: WorkoutSession? { completedSessions.first }

    private var weekSessions: [WorkoutSession] {
        var cal = Calendar.current
        cal.firstWeekday = 2
        guard let week = cal.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        return completedSessions.filter { week.contains($0.date) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    eyebrow("What are you training?")
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                    dayPicker
                    rotationPicker
                        .padding(.top, 14)
                    startButton
                        .padding(.top, 14)
                    editDayPlanLink
                    if workoutVM.suspendedSession != nil {
                        cancelLink
                    }
                    yesterdaySection
                    thisWeekSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Color.uplift.bgElev)
            .scrollIndicators(.hidden)
            .navigationBarHidden(true)
            .navigationDestination(item: $workoutVM.summaryDetailSession) { session in
                SessionDetailView(session: session)
            }
            .sheet(isPresented: $showDayPlanEditor) {
                DayPlanEditorView(dayType: todayVM.selectedDayType)
            }
        }
        .onAppear {
            todayVM.syncSelection(
                suspended: workoutVM.suspendedSession,
                mostRecent: mostRecent,
                suggestedTrack: { workoutVM.suggestedRotationTrack(for: $0) }
            )
        }
        .task {
            await todayVM.fetchLastDurations(
                sessions: completedSessions,
                healthKitService: workoutVM.healthKitService
            )
        }
        .confirmationDialog(
            "Cancel Workout?",
            isPresented: $workoutVM.showCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("Cancel Workout", role: .destructive) {
                workoutVM.cancelSuspendedSession()
            }
            Button("Keep Training", role: .cancel) {}
        } message: {
            let dayName = workoutVM.suspendedSession?.day.rawValue ?? "current"
            Text("Your \(dayName) Day workout will be discarded. This can't be undone.")
        }
        .confirmationDialog(
            "Apple Health Workout",
            isPresented: $workoutVM.showHealthKitKeepPrompt,
            titleVisibility: .visible
        ) {
            Button("Delete from Apple Health", role: .destructive) {
                workoutVM.deleteHealthKitWorkout()
            }
            Button("Keep in Apple Health") {
                workoutVM.keepHealthKitWorkout()
            }
        } message: {
            Text("This workout has been running for over 5 minutes. Would you also like to delete it from Apple Health?")
        }
        .onChange(of: workoutVM.showHealthKitKeepPrompt) { _, newValue in
            if !newValue {
                workoutVM.handleHealthKitPromptDismissed()
            }
        }
        .confirmationDialog(
            "Replace Current Workout?",
            isPresented: Binding(
                get: { confirmingDayType != nil },
                set: { if !$0 { confirmingDayType = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let dayType = confirmingDayType {
                Button("Start \(dayType.rawValue) · \(todayVM.selectedRotationTrack.sessionFilterLabel)", role: .destructive) {
                    workoutVM.abandonSuspendedAndStart(
                        dayType: dayType,
                        rotationTrack: todayVM.selectedRotationTrack
                    )
                    confirmingDayType = nil
                }
            }
            Button("Cancel", role: .cancel) {
                confirmingDayType = nil
            }
        } message: {
            let count = workoutVM.suspendedInProgressExerciseCount
            let dayName = workoutVM.suspendedSession?.day.rawValue ?? "current"
            Text("Your \(dayName) Day workout has \(count) exercise\(count == 1 ? "" : "s") in progress. Starting a new workout will discard it.")
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.uplift.text(13, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
                Text("Today")
                    .font(.uplift.display(34, weight: .bold))
                    .kerning(-0.8)
                    .foregroundStyle(Color.uplift.fg)
            }
            Spacer(minLength: 8)
            Button {
                showGymPass = true
            } label: {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(Color.uplift.surface1)
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.uplift.accent)
                    }
                    .frame(width: 44, height: 44)
                    Text("Gym pass")
                        .font(.uplift.text(10, weight: .semibold))
                        .foregroundStyle(Color.uplift.fgMuted)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show gym membership barcode")
        }
        .padding(.top, 12)
        .fullScreenCover(isPresented: $showGymPass) {
            GymPassView()
        }
    }

    private func eyebrow(_ text: String) -> some View {
        Text(text)
            .textCase(.uppercase)
            .font(.uplift.text(11, weight: .semibold))
            .tracking(0.4)
            .foregroundStyle(Color.uplift.fgMuted)
    }

    private var dayPicker: some View {
        VStack(spacing: 8) {
            // Order comes from Settings → Training Split (drag to match your week).
            ForEach(Array(dayCatalog.activeDays.enumerated()), id: \.element.id) { index, dayType in
                DayPickerCard(
                    dayType: dayType,
                    lastDuration: todayVM.lastDurations[dayType],
                    isSelected: todayVM.selectedDayType == dayType,
                    inProgressCount: suspendedBadgeCount(for: dayType),
                    weekPosition: dayCatalog.activeDays.count > 1 ? index + 1 : nil
                ) {
                    todayVM.selectDayType(
                        dayType,
                        suspended: workoutVM.suspendedSession,
                        suggestedTrack: { workoutVM.suggestedRotationTrack(for: $0) }
                    )
                }
            }
        }
    }

    /// A/B week for the selected day — same control for Push, Legs, Posterior, etc.
    private var rotationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            eyebrow("Week rotation")
            UpliftSegmentedControl(
                segments: [
                    UpliftSegment(id: RotationTrack.a.storageKey, label: "A week"),
                    UpliftSegment(id: RotationTrack.b.storageKey, label: "B week"),
                ],
                selection: Binding(
                    get: {
                        // Today only offers A/B (not All); map All → A for the control.
                        let track = todayVM.selectedRotationTrack
                        return track == .b ? RotationTrack.b.storageKey : RotationTrack.a.storageKey
                    },
                    set: { todayVM.selectedRotationTrack = RotationTrack(storageKey: $0) }
                )
            )
            Text("Applies to every day. Label lifts A or B in Exercises — shared lifts stay on Every.")
                .font(.uplift.text(12, weight: .medium))
                .foregroundStyle(Color.uplift.fgDim)
        }
    }

    private func suspendedBadgeCount(for dayType: DayType) -> Int? {
        guard let suspended = workoutVM.suspendedSession,
              suspended.day == dayType,
              workoutVM.suspendedInProgressExerciseCount > 0
        else { return nil }
        return workoutVM.suspendedInProgressExerciseCount
    }

    private var isResume: Bool {
        workoutVM.suspendedSession?.day == todayVM.selectedDayType
    }

    /// Occasional setup — keep quiet under Start so it doesn’t compete with training.
    private var editDayPlanLink: some View {
        Button {
            showDayPlanEditor = true
        } label: {
            Text("Edit \(todayVM.selectedDayType.rawValue) list")
                .font(.uplift.text(12, weight: .medium))
                .foregroundStyle(Color.uplift.fgDim)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit \(todayVM.selectedDayType.rawValue) exercise list")
        .accessibilityHint("Add, remove, or reorder exercises without starting a workout")
    }

    private var startButton: some View {
        Button {
            startTapped()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isResume ? "arrow.right" : "bolt.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text(startButtonTitle)
                    .font(.uplift.text(16, weight: .semibold))
                    .kerning(-0.2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.uplift.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(Color.uplift.onAccent)
        }
        .buttonStyle(.plain)
    }

    private var startButtonTitle: String {
        let day = todayVM.selectedDayType.rawValue
        let week = todayVM.selectedRotationTrack.sessionFilterLabel
        if isResume {
            return "Resume \(day) · \(week)"
        }
        return "Start \(day) · \(week)"
    }

    private func startTapped() {
        let target = todayVM.selectedDayType
        let track = todayVM.selectedRotationTrack
        if let suspended = workoutVM.suspendedSession,
           suspended.day != target,
           workoutVM.suspendedHasSets {
            // Discarding logged work needs explicit confirmation.
            confirmingDayType = target
        } else {
            // Resumes same-type suspended sessions; silently discards set-less ones.
            workoutVM.startSession(dayType: target, rotationTrack: track)
        }
    }

    private var cancelLink: some View {
        Button {
            workoutVM.showCancelConfirmation = true
        } label: {
            Text("Cancel workout")
                .font(.uplift.text(13, weight: .medium))
                .foregroundStyle(Color.uplift.fgMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var yesterdaySection: some View {
        if let recent = mostRecent {
            SectionHeader(TodayStats.relativeDayLabel(for: recent.date))
            NavigationLink {
                SessionDetailView(session: recent)
            } label: {
                YesterdayCard(
                    dayType: recent.day,
                    volumeText: TodayStats.formatVolume(SessionMath.volume(of: recent)),
                    setCount: SessionMath.setCount(of: recent),
                    prCount: SessionMath.e1RMPRCount(for: recent, allSessions: completedSessions)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var thisWeekSection: some View {
        Group {
            SectionHeader("This week")
            ThisWeekCard(
                sessionCount: weekSessions.count,
                volumeText: TodayStats.formatVolume(weekSessions.reduce(0) { $0 + SessionMath.volume(of: $1) }),
                setCount: weekSessions.reduce(0) { $0 + SessionMath.setCount(of: $1) },
                cells: TodayStats.weekCells(sessions: weekSessions.map { ($0.date, $0.day) })
            )
        }
    }
}

#Preview {
    TodayView(workoutVM: WorkoutViewModel(
        modelContext: previewContainer.mainContext,
        healthKitService: HealthKitWorkoutService()
    ))
    .modelContainer(previewContainer)
}
