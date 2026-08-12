//
//  WorkoutViewModel.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI
import SwiftData

/// Everything PRCelebrationView renders. Value snapshot — safe across dismissal.
struct PRCelebrationContext: Identifiable, Equatable {
    let id = UUID()
    let exerciseName: String
    let weight: Double
    let reps: Int
    let e1RM: Double
    let previousWeight: Double
    let previousReps: Int
    let previousDateLabel: String   // "3 wk ago"
    let weightDelta: Double
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
    var sessionPendingEffortRating: WorkoutSession?
    /// Set when a just-logged set breaks the exercise's all-time e1RM record —
    /// FocusView presents PRCelebrationView from this.
    var pendingCelebration: PRCelebrationContext?
    /// Re-fire guard: one celebration per exercise per session (spec §6.2).
    private var celebratedExerciseIDsThisSession: Set<UUID> = []
    let healthKitService: HealthKitWorkoutService

    // MARK: - Session rest timer (countdown survives Focus navigation / supersets)
    // On/off is per-exercise so you can rest only after the last lift in a superset.

    var targetRestSeconds: Double = Double(RestTimerPreferences.targetSeconds)
    /// Absolute end of the current countdown; nil when not resting.
    var restEndDate: Date? = nil {
        didSet {
            syncRestCountdownMonitor()
            // Clear any legacy rest-timer local notifications (ticks are audio-only now).
            RestTimerNotificationScheduler.reschedule(endDate: restEndDate)
        }
    }
    /// Bumped when a per-exercise rest on/off changes so Focus re-renders.
    var restTimerPreferenceEpoch: Int = 0

    /// History session opened for edit. While set, that row must never be deleted —
    /// only re-completed. History lists `isCompleted == true` only, so leaving it
    /// incomplete makes the workout look deleted.
    private(set) var revisitingSessionID: UUID?
    /// True when the active/suspended session was reopened from History for edits.
    var isRevisitingSavedSession: Bool { revisitingSessionID != nil }
    /// ContentView flips to the Workout tab when this becomes true.
    var wantsFocusOnWorkoutTab: Bool = false

    /// Whole seconds already announced (5…1) so we don’t double-beep.
    private var announcedRestSeconds: Set<Int> = []
    private var restDoneAnnounced = false
    private var restMonitorTask: Task<Void, Never>?
    /// GCD timer survives better than Task.sleep when the app is backgrounded with audio.
    private var restDispatchTimer: DispatchSourceTimer?

    var isResting: Bool {
        guard let end = restEndDate else { return false }
        return end > .now
    }

    var remainingRestSeconds: TimeInterval {
        guard let end = restEndDate else { return 0 }
        return max(0, end.timeIntervalSinceNow)
    }

    /// Per-exercise preference (persists across sessions for that lift).
    func isRestTimerEnabled(for exercise: Exercise) -> Bool {
        RestTimerPreferences.isEnabled(forExercise: exercise.id)
    }

    /// After logging a set on `exercise` — only starts rest if that lift has timer on.
    func startRestAfterSet(for exercise: Exercise) {
        if isRestTimerEnabled(for: exercise) {
            RestTimerSoundService.prepareIfNeeded()
            RestTimerSoundService.startBackgroundKeepAlive()
            restEndDate = Date.now.addingTimeInterval(targetRestSeconds)
        }
        // Timer off for this exercise: leave any active countdown running
        // (e.g. you hopped to a mid-superset lift while still resting from the last group).
    }

    /// Toggle rest auto-start for this exercise only; remembers the choice next time.
    func toggleRestTimer(for exercise: Exercise) {
        let next = !isRestTimerEnabled(for: exercise)
        RestTimerPreferences.setEnabled(next, forExercise: exercise.id)
        restTimerPreferenceEpoch &+= 1
        // Turning off on this lift cancels a running countdown (you’re not resting).
        if !next {
            restEndDate = nil
        }
    }

    /// Adjust a running countdown, or start one when idle and `seconds` is positive.
    /// Negative deltas shorten rest; if the end would be in the past, rest clears.
    func addRestTime(_ seconds: Double = 30) {
        if let current = restEndDate {
            // Extending/shortening — allow the countdown window to fire again later.
            announcedRestSeconds = []
            restDoneAnnounced = false
            let newEnd = current.addingTimeInterval(seconds)
            if newEnd <= .now {
                restEndDate = nil
            } else {
                restEndDate = newEnd
            }
        } else if seconds > 0 {
            startRest(seconds: seconds)
        }
    }

    /// Manual start (or restart) of the session rest countdown.
    func startRest(seconds: Double? = nil) {
        let duration = max(1, seconds ?? targetRestSeconds)
        RestTimerSoundService.prepareIfNeeded()
        RestTimerSoundService.startBackgroundKeepAlive()
        announcedRestSeconds = []
        restDoneAnnounced = false
        restEndDate = Date.now.addingTimeInterval(duration)
    }

    func skipRest() {
        restEndDate = nil
    }

    // MARK: - Rest countdown audio monitor

    private func syncRestCountdownMonitor() {
        restMonitorTask?.cancel()
        restMonitorTask = nil
        restDispatchTimer?.cancel()
        restDispatchTimer = nil
        announcedRestSeconds = []
        restDoneAnnounced = false

        guard restEndDate != nil else {
            RestTimerSoundService.stopBackgroundKeepAlive()
            return
        }

        // Keep the process eligible to run while the screen is locked.
        RestTimerSoundService.prepareIfNeeded()
        RestTimerSoundService.startBackgroundKeepAlive()

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInitiated))
        timer.schedule(deadline: .now(), repeating: .milliseconds(150), leeway: .milliseconds(50))
        timer.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.pollRestCountdownAudio()
            }
        }
        timer.resume()
        restDispatchTimer = timer
    }

    private func pollRestCountdownAudio() {
        guard let end = restEndDate else { return }
        let remaining = end.timeIntervalSinceNow

        if remaining <= 0 {
            if !restDoneAnnounced {
                restDoneAnnounced = true
                RestTimerSoundService.playComplete()
                // Clear so UI stops “resting”; keep a beat so the long chirp isn’t cut.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    if let end = self?.restEndDate, end.timeIntervalSinceNow <= 0 {
                        self?.restEndDate = nil
                    }
                }
            }
            return
        }

        // Ceiling whole seconds still left: 5.01 → 6 until drop below 5.0… we want
        // tick when we *enter* each second band 5…1 (first time remaining ≤ N).
        let whole = Int(ceil(remaining - 0.001))
        guard whole >= 1, whole <= RestTimerSoundService.tickWindow else { return }
        guard !announcedRestSeconds.contains(whole) else { return }
        announcedRestSeconds.insert(whole)
        RestTimerSoundService.playCountdownTick(remainingWholeSeconds: whole)
    }

    // MARK: - Cancel / Abandon Workout State

    var showCancelConfirmation = false
    var showHealthKitKeepPrompt = false
    private var pendingAction: PendingAction?
    private var healthKitDecisionMade = false

    private enum PendingAction {
        case cancelOnly
        case replaceWith(DayType, RotationTrack)
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
    /// Empty sessions (no sets) are deleted so History stays clean.
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
                let hasSets = session.exerciseRecordsArray.contains { !$0.setsArray.isEmpty }
                if hasSets {
                    session.isCompleted = true
                } else {
                    modelContext.delete(session)
                }
            }
            try? modelContext.save()
        }
    }

    func startSession(dayType: DayType, rotationTrack: RotationTrack? = nil) {
        // Resume a suspended session of the same type
        if let suspended = suspendedSession, suspended.day == dayType {
            activeSession = suspended
            // Honor the track chosen on Today if the user flipped A/B before resume.
            if let rotationTrack {
                suspended.track = rotationTrack
                try? modelContext.save()
            }
            suspendedSession = nil
            // Historical re-open never had a live HK session.
            if isProtectedHistorySession(suspended) {
                // keep revisitingSessionID; no HK resume
            } else {
                healthKitService.resumeWorkout()
            }
            return
        }
        // Leaving a parked session behind to start something else.
        if let suspended = suspendedSession {
            releaseParkedSession(suspended, discardLiveWork: false)
            suspendedSession = nil
        }
        clearRevisiting()
        let track = rotationTrack ?? suggestedRotationTrack(for: dayType)
        let session = WorkoutSession(dayType: dayType, rotationTrack: track)
        modelContext.insert(session)
        try? modelContext.save()
        activeSession = session
        celebratedExerciseIDsThisSession = []
        startHealthKitWorkout()
    }

    /// Alternate A↔B from the last completed session of this day type (any day).
    func suggestedRotationTrack(for dayType: DayType) -> RotationTrack {
        let descriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\WorkoutSession.date, order: .reverse)]
        )
        let sessions = (try? modelContext.fetch(descriptor)) ?? []
        // Prefer last completed session that was explicitly A or B for this day.
        if let last = sessions.first(where: {
            $0.isCompleted && $0.day == dayType && ($0.track == .a || $0.track == .b)
        }) {
            return last.track.suggestedNext
        }
        // Fall back: any completed session for this day (including All).
        if let last = sessions.first(where: { $0.isCompleted && $0.day == dayType }) {
            return last.track.suggestedNext
        }
        return .a
    }

    func setSessionRotationTrack(_ track: RotationTrack) {
        guard let session = activeSession else { return }
        session.track = track
        try? modelContext.save()
    }

    /// Move the active session to the background without completing it.
    /// History edits stay completed in the store — just clear the active pointer.
    func suspendSession() {
        guard let session = activeSession else { return }
        if isProtectedHistorySession(session) {
            // Never flip isCompleted; session already remains in History.
            activeSession = nil
            clearRevisiting()
            restEndDate = nil
            return
        }
        suspendedSession = session
        activeSession = nil
        healthKitService.pauseWorkout()
    }

    /// Undo a cancel/park when the user dismisses the confirmation (Keep Training / Keep Editing).
    func resumeSuspendedIfNeeded() {
        // Exit-editing confirm may leave the session active (not suspended).
        if activeSession != nil { return }
        guard let suspended = suspendedSession else { return }
        activeSession = suspended
        suspendedSession = nil
        if !isProtectedHistorySession(suspended) {
            healthKitService.resumeWorkout()
        }
    }

    /// Discard the suspended session and immediately start a new one.
    /// HealthKit disposal follows the >= 5 min threshold logic.
    func abandonSuspendedAndStart(dayType: DayType, rotationTrack: RotationTrack = .a) {
        if let suspended = suspendedSession {
            releaseParkedSession(suspended, discardLiveWork: true)
            suspendedSession = nil
        }
        clearRevisiting()
        // Delay to let the first confirmation dialog dismiss before potentially showing the HealthKit one.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.resolveHealthKitDisposal(.replaceWith(dayType, rotationTrack))
        }
    }

    /// Cancel workout / exit History editing.
    /// History edits: drop the active pointer only (row stays completed, never deleted).
    /// Live workouts: deleted.
    func cancelSuspendedSession() {
        // Prefer parked session; Exit editing may still have an active session.
        let session = suspendedSession ?? activeSession
        let wasRevisit: Bool
        if let session {
            wasRevisit = isProtectedHistorySession(session)
            if wasRevisit {
                // Edits are already saved per set — just leave History alone.
                if suspendedSession?.id == session.id { suspendedSession = nil }
                if activeSession?.id == session.id { activeSession = nil }
            } else {
                releaseParkedSession(session, discardLiveWork: true)
                if suspendedSession?.id == session.id { suspendedSession = nil }
                if activeSession?.id == session.id { activeSession = nil }
            }
        } else {
            wasRevisit = isRevisitingSavedSession
        }
        clearRevisiting()
        restEndDate = nil
        // Revisit edits never started a new HealthKit workout.
        if wasRevisit { return }
        resolveHealthKitDisposal(.cancelOnly)
    }

    // MARK: - History edit protection

    private func isProtectedHistorySession(_ session: WorkoutSession) -> Bool {
        revisitingSessionID == session.id
    }

    private func clearRevisiting() {
        revisitingSessionID = nil
    }

    /// Drop a parked *live* session.
    /// - `discardLiveWork`: delete (Cancel / Abandon).
    /// - keep work: complete if it has sets so it stays in History; delete empties.
    /// History-edit sessions must not call this for delete — they stay completed in-place.
    private func releaseParkedSession(_ session: WorkoutSession, discardLiveWork: Bool) {
        if isProtectedHistorySession(session) {
            // Safety: never delete a History edit target.
            clearRevisiting()
            return
        }
        let hasSets = session.exerciseRecordsArray.contains { !$0.setsArray.isEmpty }
        if !discardLiveWork, hasSets {
            session.isCompleted = true
        } else {
            modelContext.delete(session)
        }
        try? modelContext.save()
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
        case .replaceWith(let dayType, let rotationTrack):
            let session = WorkoutSession(dayType: dayType, rotationTrack: rotationTrack)
            modelContext.insert(session)
            try? modelContext.save()
            activeSession = session
            celebratedExerciseIDsThisSession = []
            startHealthKitWorkout()
        }
    }

    func finishSession() {
        guard let session = activeSession else { return }
        let wasRevisit = isProtectedHistorySession(session)
        // History edits stay completed the whole time; live sessions complete here.
        if !session.isCompleted {
            session.isCompleted = true
        }
        let capturedSession = session
        clearRevisiting()
        restEndDate = nil
        // Don't nil activeSession here — keep the workout screen visible as a
        // stable backdrop while the effort-rating sheet and summary cover show.
        // The summary's Done/View Details handlers clear it so no intermediate
        // screens flash.
        try? modelContext.save()
        HapticService.workoutCompleted()

        // Re-saving a historical workout: no new HealthKit session / effort prompt.
        if wasRevisit {
            sessionPendingSummary = capturedSession
            return
        }

        Task {
            let uuid = await healthKitService.endWorkout()
            capturedSession.healthKitWorkoutUUID = uuid
            try? modelContext.save()
            if uuid != nil {
                sessionPendingEffortRating = capturedSession
            } else {
                sessionPendingSummary = capturedSession
            }
        }
    }

    /// Re-open a completed session for set edits / skipped lifts.
    /// Keeps `isCompleted == true` so History never hides/deletes the workout.
    /// Parks any in-progress live session, skips a new HealthKit workout.
    @discardableResult
    func reopenSessionForEditing(_ session: WorkoutSession) -> Bool {
        if activeSession?.id == session.id {
            wantsFocusOnWorkoutTab = true
            return true
        }

        parkLiveSessionForReopen()

        // Critical: do NOT set isCompleted = false. History only lists completed
        // sessions; flipping that made workouts vanish (and cancel after relaunch
        // could delete them when revisitingSessionID was gone).
        activeSession = session
        revisitingSessionID = session.id
        celebratedExerciseIDsThisSession = []
        restEndDate = nil
        wantsFocusOnWorkoutTab = true
        return true
    }

    /// Suspend or discard whatever is currently live so a saved session can become active.
    private func parkLiveSessionForReopen() {
        if let active = activeSession {
            // History edit in progress — just drop the pointer (row stays completed).
            if isProtectedHistorySession(active) {
                activeSession = nil
                clearRevisiting()
                return
            }
            let hasSets = active.exerciseRecordsArray.contains { !$0.setsArray.isEmpty }
            if hasSets {
                // Prefer suspending; if a suspended session already exists, complete it.
                if let previous = suspendedSession, previous.id != active.id {
                    releaseParkedSession(previous, discardLiveWork: false)
                }
                suspendedSession = active
                if healthKitService.isSessionActive {
                    healthKitService.pauseWorkout()
                }
            } else {
                modelContext.delete(active)
                if healthKitService.isSessionActive {
                    Task { _ = await healthKitService.endWorkout() }
                }
            }
            activeSession = nil
        }
        try? modelContext.save()
    }

    func saveEffortRating(_ rating: Int) {
        guard let session = sessionPendingEffortRating else { return }
        session.effortRating = rating
        try? modelContext.save()
        let uuid = session.healthKitWorkoutUUID
        pendingSummaryAfterRating = session
        sessionPendingEffortRating = nil
        if let uuid {
            Task { await healthKitService.saveEffortRating(rating, workoutUUID: uuid) }
        }
    }

    func skipEffortRating() {
        pendingSummaryAfterRating = sessionPendingEffortRating
        sessionPendingEffortRating = nil
    }

    // MARK: - Post-finish Summary

    /// Presented as a fullScreenCover from WorkoutTabView after the effort
    /// sheet resolves. Staged via `pendingSummaryAfterRating` + the sheet's
    /// onDismiss to avoid the sheet→cover presentation race.
    var sessionPendingSummary: WorkoutSession?
    /// Set while the effort sheet is still dismissing; promoted in onDismiss.
    var pendingSummaryAfterRating: WorkoutSession?
    /// Set when the user taps "View Details" — TodayView pushes this session's
    /// detail via navigationDestination(item:).
    var summaryDetailSession: WorkoutSession?

    func dismissSummaryToToday() {
        sessionPendingSummary = nil
        activeSession = nil
        clearRevisiting()
    }

    func dismissSummaryToDetail() {
        summaryDetailSession = sessionPendingSummary
        sessionPendingSummary = nil
        activeSession = nil
        clearRevisiting()
    }

    // MARK: - Exercises

    func exercises(for dayType: DayType) -> [Exercise] {
        // Fetch all exercises then filter in Swift — avoids #Predicate string pitfalls
        let descriptor = FetchDescriptor<Exercise>(
            sortBy: [SortDescriptor(\Exercise.sortOrder)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        if dayType.includesAllExercises { return all }
        return all.filter { $0.belongs(to: dayType) }
    }

    /// Eagerly create this exercise's record in the current session so it
    /// appears in the exercise list before any set is logged (used by the
    /// add-exercise picker for cross-day-type additions).
    func addExerciseToSession(_ exercise: Exercise) {
        activeSession?.unsuppressExercise(id: exercise.id)
        _ = findOrCreateRecord(for: exercise)
        try? modelContext.save()
    }

    /// Remove from this workout only (does not delete the library exercise).
    /// Hides auto-listed day exercises and deletes this session's sets/record.
    func removeExerciseFromSession(_ exercise: Exercise) {
        guard let session = activeSession else { return }
        let records = session.exerciseRecordsArray.filter { $0.exercise?.id == exercise.id }
        for record in records {
            for set in record.setsArray {
                modelContext.delete(set)
            }
            modelContext.delete(record)
        }
        session.suppressExercise(id: exercise.id)
        try? modelContext.save()
    }

    /// Swap one lift for another in the active session only (library day plan unchanged).
    func replaceExerciseInSession(removing old: Exercise, with new: Exercise) {
        guard old.id != new.id else { return }
        removeExerciseFromSession(old)
        addExerciseToSession(new)
    }

    /// The set holding the all-time best e1RM for this exercise across
    /// completed sessions (non-warmup sets, any mode). nil = no prior history.
    func priorBestE1RMSet(for exercise: Exercise) -> PRDetection.PriorBest? {
        let excludeID = activeSession?.id
        var best: PRDetection.PriorBest?
        for record in exercise.recordsArray
        where record.session?.isCompleted == true && record.session?.id != excludeID {
            let sessionDate = record.session?.date ?? .distantPast
            for set in record.setsArray where !set.isWarmup {
                let load = set.effectiveLoadLbs()
                guard load > 0 else { continue }
                let e1rm = E1RM.estimate(weightLbs: load, reps: set.reps)
                if best == nil || e1rm > best!.e1RM {
                    best = .init(weight: load, reps: set.reps, e1RM: e1rm, date: sessionDate)
                }
            }
        }
        return best
    }

    /// Compact personal-best label for list rows, e.g. `"305×5"`.
    func personalBestSummary(for exercise: Exercise) -> String? {
        exercise.personalBestSummary(excludingSessionID: activeSession?.id)
    }

    /// True when this lift has at least one completed session (any mode).
    func hasTrainingHistory(for exercise: Exercise) -> Bool {
        exercise.hasTrainingHistory(excludingSessionID: activeSession?.id)
    }

    /// Called after a set is persisted; fires the celebration when it's a PR.
    private func checkForPR(exercise: Exercise, weight: Double, reps: Int) {
        guard let outcome = PRDetection.celebration(
            newWeight: weight,
            newReps: reps,
            priorBest: priorBestE1RMSet(for: exercise),
            alreadyCelebrated: celebratedExerciseIDsThisSession.contains(exercise.id)
        ) else { return }
        // priorBest is non-nil whenever an outcome exists
        let prior = priorBestE1RMSet(for: exercise)!
        celebratedExerciseIDsThisSession.insert(exercise.id)
        pendingCelebration = PRCelebrationContext(
            exerciseName: exercise.name,
            weight: weight,
            reps: reps,
            e1RM: outcome.newE1RM,
            previousWeight: prior.weight,
            previousReps: prior.reps,
            previousDateLabel: PrevSessionsStripData.relativeLabel(for: prior.date),
            weightDelta: outcome.weightDelta
        )
    }

    // MARK: - Progression

    func recentAverage(for exercise: Exercise, mode: TrainingMode) -> RecentAverage? {
        ProgressionService.recentAverage(
            for: exercise,
            mode: mode,
            excludingSessionID: activeSession?.id
        )
    }

    func suggestion(for exercise: Exercise, mode: TrainingMode) -> ProgressionSuggestion? {
        let raw = UserDefaults.standard.string(forKey: "progressionAggressiveness") ?? ""
        let aggressiveness = ProgressionAggressiveness(rawValue: raw) ?? .moderate
        return ProgressionService.suggestion(
            for: exercise,
            mode: mode,
            aggressiveness: aggressiveness,
            excludingSessionID: activeSession?.id
        )
    }

    /// True when this exercise already has at least one set in the active session.
    func hasLoggedSets(for exercise: Exercise) -> Bool {
        currentRecord(for: exercise)?.setsArray.isEmpty == false
    }

    /// Explicit “done with this lift” for the active mode — not inferred from set count.
    func isExerciseDone(for exercise: Exercise) -> Bool {
        currentRecord(for: exercise)?.isCompleted == true
    }

    /// Mark the lift finished (any set count, including zero to skip). Next skips done lifts.
    func markExerciseDone(_ exercise: Exercise) {
        let record = findOrCreateRecord(for: exercise)
        record.isCompleted = true
        try? modelContext.save()
    }

    /// Resume a lift after marking done (e.g. add more sets).
    func markExerciseNotDone(_ exercise: Exercise) {
        guard let record = currentRecord(for: exercise) else { return }
        record.isCompleted = false
        try? modelContext.save()
    }

    func toggleExerciseDone(_ exercise: Exercise) {
        if isExerciseDone(for: exercise) {
            markExerciseNotDone(exercise)
        } else {
            markExerciseDone(exercise)
        }
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

    // MARK: - Set Logging

    func addSet(
        exercise: Exercise,
        weight: Double,
        reps: Int,
        isWarmup: Bool = false,
        isEachSide: Bool = false,
        isAssisted: Bool = false
    ) {
        let record = findOrCreateRecord(for: exercise)
        // Logging again means the lift is no longer marked done.
        record.isCompleted = false
        let setNumber = record.setsArray.count + 1
        let set = SetRecord(
            setNumber: setNumber,
            weightLbs: weight,
            reps: reps,
            isWarmup: isWarmup,
            isEachSide: isEachSide,
            isAssisted: isAssisted
        )
        set.exerciseRecord = record
        if record.sets == nil { record.sets = [] }
        record.sets?.append(set)
        modelContext.insert(set)
        try? modelContext.save()
        HapticService.setLogged()
        // Don't re-fire PR celebrations while fixing up an old session.
        if !isWarmup && !isRevisitingSavedSession {
            let load = set.effectiveLoadLbs()
            if load > 0 {
                checkForPR(exercise: exercise, weight: load, reps: reps)
            }
        }
    }

    /// Correct weight/reps (and flags) on an existing set. Does not re-fire PR celebration.
    func updateSet(
        _ set: SetRecord,
        weight: Double,
        reps: Int,
        isWarmup: Bool = false,
        isEachSide: Bool = false,
        isAssisted: Bool = false
    ) {
        set.weightLbs = weight
        set.reps = max(1, reps)
        set.isWarmup = isWarmup
        set.isEachSide = isEachSide
        set.isAssisted = isAssisted
        set.completedAt = .now
        // Editing while marked done keeps the lift open again.
        set.exerciseRecord?.isCompleted = false
        try? modelContext.save()
        HapticService.setLogged()
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
