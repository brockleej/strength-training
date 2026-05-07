//
//  WorkoutViewModel.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI
import SwiftData

/// Display context for `PRCelebrationView`. Built by `WorkoutViewModel` when a
/// just-logged set creates a new all-time e1RM PR for the exercise.
///
/// Identifiable so `.fullScreenCover(item:)` can drive presentation in FocusView.
struct PRCelebrationContext: Identifiable, Equatable {
    /// Stable across the lifetime of one celebration trigger; new id per PR
    /// so SwiftUI re-presents if the user logs another PR after dismissing.
    let id: UUID = UUID()
    /// The exercise the PR was achieved on. Used for the title.
    let exerciseName: String
    /// The just-logged set that triggered the celebration.
    let weight: Double
    let reps: Int
    /// Computed e1RM for the just-logged set. Used for the "1RM est. {N} lb" subtitle.
    let newE1RM: Double
    /// The previous best — used for the delta card. Nil if this exercise had no
    /// prior history (so the delta card hides).
    let previousBest: ProgressionService.E1RMBest?

    /// Computed delta in pounds between new e1RM and previous best.
    /// Always > 0 when `previousBest != nil` (otherwise we wouldn't celebrate).
    var weightDelta: Double {
        guard let previousBest else { return 0 }
        // The set's weight - the previous best's weight is more meaningful for
        // the user than e1RM-vs-e1RM delta. If the user hit the same weight at
        // higher reps (also a PR), this returns 0 — fall back to the e1RM delta
        // pill in that case (handled at the view).
        return weight - previousBest.weight
    }
}

@Observable
final class WorkoutViewModel {
    var modelContext: ModelContext
    // Backed by private storage to guard against SwiftData zombie objects
    // (e.g. after a backup restore deletes all sessions while refs are held).
    private var _activeSession: WorkoutSession?
    var activeSession: WorkoutSession? {
        get {
            if let s = _activeSession, s.isDeleted { _activeSession = nil }
            return _activeSession
        }
        set { _activeSession = newValue }
    }
    /// A session the user navigated away from without finishing.
    /// Kept alive so it can be resumed or explicitly abandoned.
    private var _suspendedSession: WorkoutSession?
    var suspendedSession: WorkoutSession? {
        get {
            if let s = _suspendedSession, s.isDeleted { _suspendedSession = nil }
            return _suspendedSession
        }
        set { _suspendedSession = newValue }
    }
    var selectedMode: TrainingMode = .highWeightLowReps
    var showDeleteHint = false
    private var deleteHintShownThisSession = false
    var sessionPendingEffortRating: WorkoutSession?
    /// Set after a workout is finished (and effort rating handled) to trigger navigation to its detail.
    var completedSessionToReview: WorkoutSession?
    /// Set after the effort rating sheet dismisses (Confirm or Skip). Drives presentation
    /// of WorkoutSummaryView via WorkoutTabView's sheet binding. Cleared by Done/Detail
    /// callbacks on the summary view.
    var sessionPendingSummary: WorkoutSession?
    /// Pending PR celebration to present, if any. Bound by FocusView via .fullScreenCover(item:).
    /// Set by `addSet(...)` when a logged set creates a new all-time e1RM PR. Cleared
    /// when the view dismisses.
    var pendingCelebration: PRCelebrationContext?

    /// Per-session re-fire guard: tracks Exercise.id values that have already
    /// celebrated in the current session. Reset whenever a new session starts.
    /// In-memory only — not persisted.
    private var celebratedExerciseIDs: Set<UUID> = []

    /// Per-session count of exercises that fired a PR celebration during the
    /// active session. Reads the in-memory `celebratedExerciseIDs` set populated
    /// by `addSet(...)`. Resets when a new session begins.
    var prCountThisSession: Int {
        celebratedExerciseIDs.count
    }
    let healthKitService: HealthKitWorkoutService

    // MARK: - Cancel / Abandon Workout State

    var showCancelConfirmation = false
    var showHealthKitKeepPrompt = false
    private var pendingAction: PendingAction?
    private var healthKitDecisionMade = false

    private enum PendingAction {
        case cancelOnly
        case replaceWith(DayType)
    }

    init(modelContext: ModelContext, healthKitService: HealthKitWorkoutService) {
        self.modelContext = modelContext
        self.healthKitService = healthKitService
        healthKitService.checkAuthorization()
        healthKitService.cleanUpOrphanedState()
        resolveSessionState()
    }

    // MARK: - Session Lifecycle

    /// On launch: resume today's session, auto-complete stale ones, or start fresh.
    func resolveSessionState() {
        autoCompleteStaleSession()

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> {
                $0.isCompleted == false &&
                $0.date >= startOfToday &&
                $0.date < endOfToday
            }
        )
        descriptor.fetchLimit = 1

        activeSession = try? modelContext.fetch(descriptor).first
    }

    /// Auto-complete any sessions from previous days that were never finished.
    func autoCompleteStaleSession() {
        let startOfToday = Calendar.current.startOfDay(for: .now)

        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> {
                $0.isCompleted == false &&
                $0.date < startOfToday
            }
        )

        if let staleSessions = try? modelContext.fetch(descriptor) {
            for session in staleSessions {
                session.isCompleted = true
            }
            try? modelContext.save()
        }
    }

    func startSession(dayType: DayType) {
        // Resume a suspended session of the same type
        if let suspended = suspendedSession, suspended.dayType == dayType {
            activeSession = suspended
            suspendedSession = nil
            healthKitService.resumeWorkout()
            return
        }
        // Silently discard a suspended session that has no sets
        if let suspended = suspendedSession {
            if !suspended.exerciseRecordsArray.contains(where: { !$0.setsArray.isEmpty }) {
                modelContext.delete(suspended)
                try? modelContext.save()
            }
            suspendedSession = nil
        }
        let session = WorkoutSession(dayType: dayType)
        modelContext.insert(session)
        try? modelContext.save()
        activeSession = session
        celebratedExerciseIDs.removeAll()
        startHealthKitWorkout()
    }

    /// Move the active session to the background without completing it.
    func suspendSession() {
        suspendedSession = activeSession
        activeSession = nil
        healthKitService.pauseWorkout()
    }

    /// Discard the suspended session and immediately start a new one.
    /// HealthKit disposal follows the >= 5 min threshold logic.
    func abandonSuspendedAndStart(dayType: DayType) {
        if let suspended = suspendedSession {
            modelContext.delete(suspended)
            try? modelContext.save()
            suspendedSession = nil
        }
        // Delay to let the first confirmation dialog dismiss before potentially showing the HealthKit one.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.resolveHealthKitDisposal(.replaceWith(dayType))
        }
    }

    /// Cancel and delete the suspended session entirely.
    func cancelSuspendedSession() {
        if let suspended = suspendedSession {
            modelContext.delete(suspended)
            try? modelContext.save()
            suspendedSession = nil
        }
        resolveHealthKitDisposal(.cancelOnly)
    }

    /// Called when the HealthKit keep/delete dialog dismisses without an explicit button tap.
    func handleHealthKitPromptDismissed() {
        guard !healthKitDecisionMade else { return }
        keepHealthKitWorkout()
    }

    func keepHealthKitWorkout() {
        healthKitDecisionMade = true
        let action = pendingAction
        pendingAction = nil
        Task {
            await healthKitService.endWorkout()
            await MainActor.run { [weak self] in self?.completePendingAction(action) }
        }
    }

    func deleteHealthKitWorkout() {
        healthKitDecisionMade = true
        let action = pendingAction
        pendingAction = nil
        Task {
            await healthKitService.discardWorkout()
            await MainActor.run { [weak self] in self?.completePendingAction(action) }
        }
    }

    /// Number of exercises in the suspended session that have at least one set.
    var suspendedInProgressExerciseCount: Int {
        suspendedSession?.exerciseRecordsArray.filter { !$0.setsArray.isEmpty }.count ?? 0
    }

    /// True when the suspended session has at least one set logged.
    var suspendedHasSets: Bool {
        suspendedSession?.exerciseRecordsArray.contains { !$0.setsArray.isEmpty } ?? false
    }

    // MARK: - HealthKit Disposal

    private func resolveHealthKitDisposal(_ action: PendingAction) {
        let elapsed = healthKitService.elapsedSeconds
        if elapsed >= 300 {
            pendingAction = action
            healthKitDecisionMade = false
            showHealthKitKeepPrompt = true
        } else {
            Task {
                await healthKitService.discardWorkout()
                await MainActor.run { [weak self] in self?.completePendingAction(action) }
            }
        }
    }

    private func completePendingAction(_ action: PendingAction?) {
        guard let action else { return }
        switch action {
        case .cancelOnly:
            break
        case .replaceWith(let dayType):
            let session = WorkoutSession(dayType: dayType)
            modelContext.insert(session)
            try? modelContext.save()
            activeSession = session
            celebratedExerciseIDs.removeAll()
            startHealthKitWorkout()
        }
    }

    func finishSession() {
        guard let session = activeSession, !session.isCompleted else { return }
        session.isCompleted = true
        let capturedSession = session
        // Don't nil activeSession here — keep the ExerciseListView visible as a
        // stable backdrop while the effort-rating sheet shows. ContentView clears
        // activeSession after switching to the History tab so no intermediate
        // screens flash.
        try? modelContext.save()
        HapticService.workoutCompleted()
        Task {
            let uuid = await healthKitService.endWorkout()
            capturedSession.healthKitWorkoutUUID = uuid
            try? modelContext.save()
            if uuid != nil {
                sessionPendingEffortRating = capturedSession
            } else {
                completedSessionToReview = capturedSession
            }
        }
    }

    func saveEffortRating(_ rating: Int) {
        guard let session = sessionPendingEffortRating else { return }
        session.effortRating = rating
        try? modelContext.save()
        let uuid = session.healthKitWorkoutUUID
        // Phase 4: route through the summary screen instead of jumping straight to History.
        sessionPendingSummary = session
        sessionPendingEffortRating = nil
        if let uuid {
            Task { await healthKitService.saveEffortRating(rating, workoutUUID: uuid) }
        }
    }

    func skipEffortRating() {
        // Phase 4: route through the summary screen instead of jumping straight to History.
        sessionPendingSummary = sessionPendingEffortRating
        sessionPendingEffortRating = nil
    }

    // MARK: - Exercises

    func exercises(for dayType: DayType) -> [Exercise] {
        // Fetch all exercises then filter in Swift — avoids #Predicate enum comparison issues
        let descriptor = FetchDescriptor<Exercise>(
            sortBy: [SortDescriptor(\Exercise.sortOrder)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        if dayType == .fullBody { return all }
        return all.filter { $0.dayType == dayType }
    }

    // MARK: - Progression

    func recentAverage(for exercise: Exercise, mode: TrainingMode) -> RecentAverage? {
        ProgressionService.recentAverage(for: exercise, mode: mode)
    }

    func suggestion(for exercise: Exercise, mode: TrainingMode) -> ProgressionSuggestion? {
        let raw = UserDefaults.standard.string(forKey: "progressionAggressiveness") ?? ""
        let aggressiveness = ProgressionAggressiveness(rawValue: raw) ?? .moderate
        return ProgressionService.suggestion(for: exercise, mode: mode, aggressiveness: aggressiveness)
    }

    /// Get the current session's record for an exercise in the active mode.
    func currentRecord(for exercise: Exercise) -> ExerciseRecord? {
        guard let session = activeSession else { return nil }
        let modeRaw = selectedMode.rawValue
        return session.exerciseRecordsArray.first {
            $0.exercise?.id == exercise.id &&
            $0.trainingMode.rawValue == modeRaw
        }
    }

    /// Show the delete-set hint once per session, auto-hiding after 5 seconds.
    func showDeleteHintIfNeeded() {
        guard !deleteHintShownThisSession else { return }
        deleteHintShownThisSession = true
        Task { @MainActor in
            // Delay so the hint reads as a distinct event from the set appearing
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation(.easeInOut(duration: 0.4)) { showDeleteHint = true }
            try? await Task.sleep(for: .seconds(5))
            withAnimation(.easeInOut(duration: 0.6)) { showDeleteHint = false }
        }
    }

    // MARK: - Set Logging

    func addSet(exercise: Exercise, weight: Double, reps: Int) {
        // Phase 3 — capture prior all-time best BEFORE saving so the new set
        // doesn't influence the comparison.
        let priorBest = ProgressionService.allTimeBestE1RM(for: exercise)

        let record = findOrCreateRecord(for: exercise)
        let setNumber = record.setsArray.count + 1
        let set = SetRecord(setNumber: setNumber, weightLbs: weight, reps: reps)
        set.exerciseRecord = record
        if record.sets == nil { record.sets = [] }
        record.sets?.append(set)
        modelContext.insert(set)
        try? modelContext.save()
        HapticService.setLogged()
        showDeleteHintIfNeeded()

        // Phase 3 — PR check: did this set produce a new all-time-best e1RM?
        let newE1RM = ProgressionService.e1RM(weight: weight, reps: reps)
        let priorE1RM = priorBest?.e1RM ?? 0
        if newE1RM > priorE1RM, !celebratedExerciseIDs.contains(exercise.id) {
            celebratedExerciseIDs.insert(exercise.id)
            pendingCelebration = PRCelebrationContext(
                exerciseName: exercise.name,
                weight: weight,
                reps: reps,
                newE1RM: newE1RM,
                previousBest: priorBest
            )
        }
    }

    func deleteSet(_ set: SetRecord, from exercise: Exercise) {
        HapticService.swipeToDelete()
        modelContext.delete(set)
        // Renumber remaining sets
        if let record = currentRecord(for: exercise) {
            let sorted = record.setsArray.sorted { $0.setNumber < $1.setNumber }
            for (index, s) in sorted.enumerated() {
                s.setNumber = index + 1
            }
        }
        try? modelContext.save()
    }

    // MARK: - Helpers

    private func startHealthKitWorkout() {
        Task {
            if healthKitService.authorizationStatus == nil {
                let authorized = await healthKitService.requestAuthorization()
                if authorized {
                    try? await healthKitService.startWorkout()
                }
            } else if healthKitService.authorizationStatus == true {
                try? await healthKitService.startWorkout()
            }
        }
    }

    private func findOrCreateRecord(for exercise: Exercise) -> ExerciseRecord {
        if let existing = currentRecord(for: exercise) {
            return existing
        }

        guard let session = activeSession else {
            fatalError("No active session when trying to create ExerciseRecord")
        }

        let record = ExerciseRecord(
            trainingMode: selectedMode,
            sortOrder: session.exerciseRecordsArray.count
        )
        record.exercise = exercise
        record.session = session
        if session.exerciseRecords == nil { session.exerciseRecords = [] }
        session.exerciseRecords?.append(record)
        modelContext.insert(record)
        try? modelContext.save()
        return record
    }
}
