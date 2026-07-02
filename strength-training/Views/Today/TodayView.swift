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
    /// Day type pending the "Replace Current Workout?" confirmation.
    @State private var confirmingDayType: DayType?

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
                    startButton
                        .padding(.top, 14)
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
        }
        .onAppear {
            todayVM.syncSelection(suspended: workoutVM.suspendedSession, mostRecent: mostRecent)
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
            let dayName = workoutVM.suspendedSession?.dayType.rawValue ?? "current"
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
                Button("Start \(dayType.rawValue) Day", role: .destructive) {
                    workoutVM.abandonSuspendedAndStart(dayType: dayType)
                    confirmingDayType = nil
                }
            }
            Button("Cancel", role: .cancel) {
                confirmingDayType = nil
            }
        } message: {
            let count = workoutVM.suspendedInProgressExerciseCount
            let dayName = workoutVM.suspendedSession?.dayType.rawValue ?? "current"
            Text("Your \(dayName) Day workout has \(count) exercise\(count == 1 ? "" : "s") in progress. Starting a new workout will discard it.")
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.uplift.text(13, weight: .medium))
                .foregroundStyle(Color.uplift.fgMuted)
            Text("Today")
                .font(.uplift.display(34, weight: .bold))
                .kerning(-0.8)
                .foregroundStyle(Color.uplift.fg)
        }
        .padding(.top, 12)
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
            ForEach(DayType.allCases) { dayType in
                DayPickerCard(
                    dayType: dayType,
                    lastDuration: todayVM.lastDurations[dayType],
                    isSelected: todayVM.selectedDayType == dayType,
                    inProgressCount: suspendedBadgeCount(for: dayType)
                ) {
                    todayVM.selectedDayType = dayType
                }
            }
        }
    }

    private func suspendedBadgeCount(for dayType: DayType) -> Int? {
        guard let suspended = workoutVM.suspendedSession,
              suspended.dayType == dayType,
              workoutVM.suspendedInProgressExerciseCount > 0
        else { return nil }
        return workoutVM.suspendedInProgressExerciseCount
    }

    private var isResume: Bool {
        workoutVM.suspendedSession?.dayType == todayVM.selectedDayType
    }

    private var startButton: some View {
        Button {
            startTapped()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isResume ? "arrow.right" : "bolt.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text(isResume ? "Resume workout" : "Start workout")
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

    private func startTapped() {
        let target = todayVM.selectedDayType
        if let suspended = workoutVM.suspendedSession,
           suspended.dayType != target,
           workoutVM.suspendedHasSets {
            // Discarding logged work needs explicit confirmation.
            confirmingDayType = target
        } else {
            // Resumes same-type suspended sessions; silently discards set-less ones.
            workoutVM.startSession(dayType: target)
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
                    dayType: recent.dayType,
                    volumeText: TodayStats.formatVolume(volume(of: recent)),
                    setCount: setCount(of: recent),
                    prCount: e1RMPRCount(for: recent)
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
                volumeText: TodayStats.formatVolume(weekSessions.reduce(0) { $0 + volume(of: $1) }),
                setCount: weekSessions.reduce(0) { $0 + setCount(of: $1) },
                cells: TodayStats.weekCells(sessions: weekSessions.map { ($0.date, $0.dayType) })
            )
        }
    }

    // MARK: - Session math

    private func volume(of session: WorkoutSession) -> Double {
        session.exerciseRecordsArray
            .flatMap { $0.setsArray }
            .reduce(0) { $0 + $1.weightLbs * Double($1.reps) }
    }

    private func setCount(of session: WorkoutSession) -> Int {
        session.exerciseRecordsArray.reduce(0) { $0 + $1.setsArray.count }
    }

    /// Exercises in this session whose best estimated 1RM ties or beats the
    /// all-time best across all completed sessions (Epley, warmups excluded).
    /// Same formula/threshold as SessionDetailView's PR badge, but counted per
    /// EXERCISE (cross-mode best, deduped) — SessionDetailView badges per
    /// record (per mode), so counts can differ for multi-mode sessions.
    /// Uses the shared `E1RM.estimate`.
    private func e1RMPRCount(for session: WorkoutSession) -> Int {
        var counted = Set<UUID>()
        var count = 0
        for record in session.exerciseRecordsArray {
            guard let exerciseID = record.exercise?.id, !counted.contains(exerciseID) else { continue }
            let sessionBest = session.exerciseRecordsArray
                .filter { $0.exercise?.id == exerciseID }
                .flatMap { $0.setsArray }
                .filter { !$0.isWarmup }
                .map { E1RM.estimate(weightLbs: $0.weightLbs, reps: $0.reps) }
                .max() ?? 0
            guard sessionBest > 0 else { continue }
            let allTimeBest = completedSessions
                .flatMap { $0.exerciseRecordsArray }
                .filter { $0.exercise?.id == exerciseID }
                .flatMap { $0.setsArray }
                .filter { !$0.isWarmup }
                .map { E1RM.estimate(weightLbs: $0.weightLbs, reps: $0.reps) }
                .max() ?? 0
            if sessionBest >= allTimeBest {
                counted.insert(exerciseID)
                count += 1
            }
        }
        return count
    }
}

#Preview {
    TodayView(workoutVM: WorkoutViewModel(
        modelContext: previewContainer.mainContext,
        healthKitService: HealthKitWorkoutService()
    ))
    .modelContainer(previewContainer)
}
