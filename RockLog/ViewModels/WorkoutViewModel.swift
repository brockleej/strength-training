//
//  WorkoutViewModel.swift
//  RockLog
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

/// One logged set, kept long enough for the Undo toast to put it back.
struct DeletedSetUndo: Equatable {
    let exerciseID: UUID
    let modeRaw: String
    let setNumber: Int
    let weightLbs: Double
    let reps: Int
    let isWarmup: Bool
    let isEachSide: Bool
    let isAssisted: Bool
    let isTarget: Bool
    let completedAt: Date
    let loadModeRaw: String
    let offeredWeightLbs: Double?
    let bodyWeightUsedLbs: Double
    let plannedRestSeconds: Int
    let actualRestSeconds: Int

    init(set: SetRecord, exerciseID: UUID, modeRaw: String) {
        self.exerciseID = exerciseID
        self.modeRaw = modeRaw
        self.setNumber = set.setNumber
        self.weightLbs = set.weightLbs
        self.reps = set.reps
        self.isWarmup = set.isWarmup
        self.isEachSide = set.isEachSide
        self.isAssisted = set.isAssisted
        self.isTarget = set.isTarget
        self.completedAt = set.completedAt
        self.loadModeRaw = set.loadModeRaw
        self.offeredWeightLbs = set.offeredWeightLbs
        self.bodyWeightUsedLbs = set.bodyWeightUsedLbs
        self.plannedRestSeconds = set.plannedRestSeconds
        self.actualRestSeconds = set.actualRestSeconds
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
        didSet { syncRestCountdownMonitor() }
    }
    /// Bumped when a per-exercise rest on/off changes so Focus re-renders.
    var restTimerPreferenceEpoch: Int = 0
    /// Bumped when sets are added/updated/removed so Focus re-reads SwiftData.
    var setMutationEpoch: Int = 0
    /// Set just removed. The toast offers Undo until this clears.
    var pendingSetUndo: DeletedSetUndo?
    /// How long the Undo toast stays up. Tests shorten it.
    var setUndoSeconds: TimeInterval = 5
    private var setUndoTask: Task<Void, Never>?
    private var setUndoGeneration = 0
    /// True when every lift is marked done — UI asks to finish the workout.
    var offerFinishWorkout: Bool = false

    /// History session opened for edit. While set, that row must never be deleted —
    /// only re-completed. History lists `isCompleted == true` only, so leaving it
    /// incomplete makes the workout look deleted.
    private(set) var revisitingSessionID: UUID?
    /// True when the active/suspended session was reopened from History for edits.
    var isRevisitingSavedSession: Bool { revisitingSessionID != nil }
    /// ContentView flips to the Workout tab when this becomes true.
    var wantsFocusOnWorkoutTab: Bool = false

    var restExerciseName: String = "Rest"
    private var restAlert: RestAlertState?
    private var restStartedAt: Date?
    private var restExerciseID: UUID?
    /// The workout list asks for the reorder sheet. Focus and the list share it.
    var presentSessionReorder = false
    /// Same-weight carry for the live session. Not stored. A finished-workout edit leaves this empty.
    var carryByExercise: [UUID: SessionCarryState] = [:]
    private var restMonitorTask: Task<Void, Never>?
    /// GCD timer survives better than Task.sleep when the app is backgrounded with audio.
    private var restDispatchTimer: DispatchSourceTimer?
    /// Unstructured work that can reach `modelContext.save()` after this object’s store is gone.
    /// Each finish keeps its own save. A later finish does not cancel an earlier one.
    private var finishSaveTasks: [UUID: Task<Void, Never>] = [:]
    private var deferredPlannedStartTask: Task<Void, Never>?
    private var deferredReplaceTask: Task<Void, Never>?
    private var healthKitFollowUpTask: Task<Void, Never>?
    private static var liveInstances: [LiveInstance] = []
    #if DEBUG
    /// Tests can set this to false to let a deferred save run after tearDown.
    nonisolated(unsafe) static var cancelsDeferredSaves = true
    /// Set by the test observer. "-" outside a test.
    nonisolated(unsafe) static var diagnosticTestName = "-"

    nonisolated static func rlDiag(_ event: String, vm: ObjectIdentifier) {
        print("[RLDIAG] \(event) vm=\(vm) test=\(diagnosticTestName)")
    }
    #endif

    /// Release always cancels. Debug builds read `cancelsDeferredSaves`.
    private nonisolated static var shouldCancelDeferredSaves: Bool {
        #if DEBUG
        cancelsDeferredSaves
        #else
        true
        #endif
    }

    /// `Task.isCancelled` stops the save when deferred saves are cancelled.
    private nonisolated static func deferredSaveProceeds(
        cancelled: Bool,
        alive: Bool,
        event: String,
        vm: ObjectIdentifier
    ) -> Bool {
        let proceed = (!shouldCancelDeferredSaves || !cancelled) && alive
        #if DEBUG
        rlDiag("\(event) proceed=\(proceed) cancelled=\(cancelled) alive=\(alive)", vm: vm)
        #else
        _ = (event, vm)
        #endif
        return proceed
    }

    private struct LiveInstance {
        weak var viewModel: WorkoutViewModel?
    }

    var isResting: Bool {
        guard let end = restEndDate else { return false }
        return end > .now
    }

    var remainingRestSeconds: TimeInterval {
        guard let end = restEndDate else { return 0 }
        return max(0, end.timeIntervalSinceNow)
    }

    /// Per-exercise auto-start. The countdown length is a different control.
    func isRestTimerEnabled(for exercise: Exercise) -> Bool {
        if RestPreferenceMigration.copyIfNeeded(exercise) {
            try? modelContext.save()
        }
        return exercise.autoRestEnabled
    }

    func restSeconds(for exercise: Exercise) -> Int {
        exercise.resolvedRestSeconds(settingsFallback: RestTimerPreferences.targetSeconds)
    }

    /// After logging a set. A master switch that is off, or this lift's switch, skips the start.
    /// A countdown already running for another lift is left alone.
    func startRestAfterSet(for exercise: Exercise) {
        guard RestTimerPreferences.isEnabled, isRestTimerEnabled(for: exercise) else { return }
        beginRest(seconds: Double(restSeconds(for: exercise)), exercise: exercise)
    }

    /// Toggle auto-start for this lift. Does not change how long the countdown is.
    func toggleRestTimer(for exercise: Exercise) {
        setRestTimerEnabled(!isRestTimerEnabled(for: exercise), for: exercise)
    }

    /// The switch is its own control. The countdown, −15, +15, and Skip do not call this.
    func setRestTimerEnabled(_ enabled: Bool, for exercise: Exercise) {
        _ = RestPreferenceMigration.copyIfNeeded(exercise)
        guard exercise.autoRestEnabled != enabled else { return }
        exercise.autoRestEnabled = enabled
        try? modelContext.save()
        restTimerPreferenceEpoch &+= 1
        if !enabled {
            skipRest()
        }
    }

    /// ±15 by default. Shortening past zero clears the countdown.
    func addRestTime(_ seconds: Double = 15) {
        guard var state = restAlert else {
            if seconds > 0 { startRest(seconds: seconds) }
            return
        }
        let effects = RestAlertPolicy.onNudge(&state, seconds: seconds, now: .now)
        restAlert = state
        if state.endDate.timeIntervalSinceNow <= 0 {
            restEndDate = nil
            restAlert = nil
        } else {
            restEndDate = state.endDate
        }
        RestAlertRuntime.apply(effects, exerciseName: restExerciseName)
    }

    /// Manual start. Works when auto-rest for this lift is off.
    func startRest(seconds: Double? = nil, exercise: Exercise? = nil) {
        let duration = max(1, seconds ?? targetRestSeconds)
        beginRest(seconds: duration, exercise: exercise)
    }

    func skipRest() {
        recordRestSampleIfNeeded(endedAt: .now)
        if var state = restAlert {
            let effects = RestAlertPolicy.onSkip(&state)
            restAlert = nil
            RestAlertRuntime.apply(effects, exerciseName: restExerciseName)
        } else {
            RestTimerNotificationScheduler.cancelBackup()
            RestActivityController.endAll()
        }
        restEndDate = nil
    }

    private func beginRest(seconds: Double, exercise: Exercise?) {
        let now = Date()
        restExerciseName = exercise?.name ?? "Rest"
        restExerciseID = exercise?.id
        restStartedAt = now
        let state = RestAlertState.started(now: now, duration: max(1, seconds))
        restAlert = state
        RestTimerSoundService.prepareIfNeeded()
        restEndDate = state.endDate
        targetRestSeconds = max(1, seconds)
        RestAlertRuntime.apply(RestAlertPolicy.onStart(state, tick: RestAlertRuntime.tickContext(now: now)), exerciseName: restExerciseName)
    }

    private func silenceRestIfCallConnected() {
        guard RestCallMonitor.shared.hasConnectedCall, let state = restAlert else { return }
        RestAlertRuntime.apply(RestAlertPolicy.onCallBegan(state), exerciseName: restExerciseName)
    }

    private func recordRestSampleIfNeeded(endedAt: Date) {
        guard RestAlertPreferences.learningEnabled,
              let started = restStartedAt,
              let id = restExerciseID
        else { return }
        let elapsed = Int(endedAt.timeIntervalSince(started).rounded())
        RestSampleStore.record(elapsed, for: id)
        restStartedAt = nil
    }

    // MARK: - Rest countdown audio monitor

    private func syncRestCountdownMonitor() {
        restMonitorTask?.cancel()
        restMonitorTask = nil
        restDispatchTimer?.cancel()
        restDispatchTimer = nil

        guard restEndDate != nil else { return }

        RestTimerSoundService.prepareIfNeeded()

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
        guard restEndDate != nil, var state = restAlert else { return }
        let effects = RestAlertPolicy.onTick(&state, tick: RestAlertRuntime.tickContext(now: .now))
        restAlert = state
        RestAlertRuntime.apply(effects, exerciseName: restExerciseName)
        guard effects.endActivity else { return }
        recordRestSampleIfNeeded(endedAt: .now)
        // Leave the end date up long enough for the chirp to start, then clear the card.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let self, let end = self.restEndDate, end.timeIntervalSinceNow <= 0 else { return }
            self.restAlert = nil
            self.restEndDate = nil
        }
    }

    // MARK: - Cancel / Abandon Workout State

    var showCancelConfirmation = false
    var showHealthKitKeepPrompt = false
    private var pendingAction: PendingAction?
    private var healthKitDecisionMade = false

    private enum PendingAction: Sendable {
        case cancelOnly
        case replaceWith(DayType, RotationTrack)
    }

    init(modelContext: ModelContext, healthKitService: HealthKitWorkoutService) {
        self.modelContext = modelContext
        self.healthKitService = healthKitService
        Self.liveInstances.removeAll { $0.viewModel == nil }
        Self.liveInstances.append(LiveInstance(viewModel: self))
        healthKitService.checkAuthorization()
        healthKitService.cleanUpOrphanedState()
        _ = GymLibrary.ensureHome(in: modelContext)
        RestCallMonitor.shared.start()
        RestCallMonitor.shared.onChange = { [weak self] in
            self?.silenceRestIfCallConnected()
        }
        resolveSessionState()
        if let session = activeSession, !isProtectedHistorySession(session) {
            Task { await healthKitService.recoverOrStartIfNeeded() }
        }
    }

    // MARK: - Session Lifecycle

    /// On launch: resume today's live session or stay idle.
    /// Unused planned sessions stay in the queue — never auto-activated or skipped.
    func resolveSessionState() {
        autoCompleteStaleSession()

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        let liveState = SessionPlanState.none.rawValue

        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> {
                $0.isCompleted == false &&
                $0.planState == liveState &&
                $0.date >= startOfToday &&
                $0.date < endOfToday
            }
        )
        descriptor.fetchLimit = 1

        activeSession = try? modelContext.fetch(descriptor).first
    }

    /// A live workout that crossed midnight stays open until this long after the last logged set.
    static let staleLoggedWorkoutInterval: TimeInterval = 6 * 60 * 60

    static func latestAthleteSetDate(_ session: WorkoutSession) -> Date? {
        session.exerciseRecordsArray
            .flatMap { record in
                record.setsArray.filter { !$0.isTarget }.map(\.completedAt)
            }
            .max()
    }

    static func shouldCompleteStaleLoggedSession(lastLoggedAt: Date, now: Date) -> Bool {
        now.timeIntervalSince(lastLoggedAt) >= staleLoggedWorkoutInterval
    }

    /// Auto-complete unfinished *live* sessions from previous days.
    /// A session with logged sets completes only after `staleLoggedWorkoutInterval`
    /// since the last non-target set, so a workout that crosses midnight stays open.
    /// Unused planned sessions stay queued — never skipped, never History.
    /// Empty live sessions (no sets) from a previous day are deleted so History stays clean.
    /// Today's empty live session is not in this query.
    func autoCompleteStaleSession(now: Date = .now) {
        let startOfToday = Calendar.current.startOfDay(for: now)

        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> {
                $0.isCompleted == false &&
                $0.date < startOfToday
            }
        )

        if let staleSessions = try? modelContext.fetch(descriptor) {
            for session in staleSessions {
                if PlannedBlockQueue.isUnused(session) {
                    session.planStatus = .planned
                    session.isCompleted = false
                    continue
                }
                let hasSets = Self.hasAthleteLoggedSets(session)
                if hasSets {
                    let lastLoggedAt = Self.latestAthleteSetDate(session) ?? session.date
                    if Self.shouldCompleteStaleLoggedSession(lastLoggedAt: lastLoggedAt, now: now) {
                        session.isCompleted = true
                        SessionMath.stampDuration(on: session, liveElapsed: 0, now: now)
                    }
                } else if session.trainingBlock != nil {
                    session.planStatus = .planned
                    session.isCompleted = false
                } else {
                    modelContext.delete(session)
                }
            }
            try? modelContext.save()
        }
    }

    /// First unused session in the imported block (file order).
    func nextUnusedPlannedSession() -> WorkoutSession? {
        PlannedBlockQueue.nextUnused(in: allIncompleteSessions())
    }

    /// Earliest unused planned row of this day type (file order). Avoids a duplicate live session.
    func earliestUnusedPlannedSession(dayType: DayType) -> WorkoutSession? {
        PlannedBlockQueue.unusedSessions(in: allIncompleteSessions()).first { $0.day == dayType }
    }

    /// Drop one leftover planned day. History is untouched.
    func deleteUnusedPlannedSession(_ session: WorkoutSession) {
        guard PlannedBlockQueue.isUnused(session) else { return }
        modelContext.delete(session)
        pruneEmptyTrainingBlocks()
        try? modelContext.save()
    }

    /// Drop every leftover planned day. Finished workouts stay.
    func deleteAllUnusedPlannedSessions() {
        ProgramImportService.removeUnusedPlannedSessions(context: modelContext)
    }

    private func pruneEmptyTrainingBlocks() {
        let blocks = (try? modelContext.fetch(FetchDescriptor<TrainingBlock>())) ?? []
        for block in blocks where block.sessionsArray.isEmpty {
            modelContext.delete(block)
        }
    }

    /// Unused planned sessions, queue order (includes past calendar dates).
    func unusedPlannedSessions(limit: Int = 8) -> [WorkoutSession] {
        let unused = PlannedBlockQueue.unusedSessions(in: allIncompleteSessions())
        return Array(unused.prefix(limit))
    }

    func startSession(dayType: DayType, rotationTrack: RotationTrack? = nil, now: Date = .now) {
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
        activateOrCreateSession(dayType: dayType, rotationTrack: track, now: now)
    }

    /// Start a specific queued planned session (not only the next unused).
    func startPlannedSession(_ session: WorkoutSession, rotationTrack: RotationTrack? = nil, now: Date = .now) {
        if let suspended = suspendedSession, suspended.id == session.id {
            activeSession = suspended
            if let rotationTrack {
                suspended.track = rotationTrack
                try? modelContext.save()
            }
            suspendedSession = nil
            if !isProtectedHistorySession(suspended) {
                healthKitService.resumeWorkout()
            }
            return
        }
        if let suspended = suspendedSession {
            releaseParkedSession(suspended, discardLiveWork: false)
            suspendedSession = nil
        }
        clearRevisiting()
        let track = rotationTrack ?? suggestedRotationTrack(for: session.day)
        activatePlannedSession(session, rotationTrack: track, now: now)
    }

    func abandonSuspendedAndStart(planned session: WorkoutSession, rotationTrack: RotationTrack) {
        if let suspended = suspendedSession {
            releaseParkedSession(suspended, discardLiveWork: true)
            suspendedSession = nil
        }
        clearRevisiting()
        let vmID = ObjectIdentifier(self)
        if Self.shouldCancelDeferredSaves {
            deferredPlannedStartTask?.cancel()
        }
        deferredPlannedStartTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            let cancelled = Task.isCancelled
            guard Self.deferredSaveProceeds(
                cancelled: cancelled,
                alive: self != nil,
                event: "activatePlannedSession",
                vm: vmID
            ), let self else { return }
            self.activatePlannedSession(session, rotationTrack: rotationTrack, now: .now)
        }
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
        let vmID = ObjectIdentifier(self)
        if Self.shouldCancelDeferredSaves {
            deferredReplaceTask?.cancel()
        }
        deferredReplaceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            let cancelled = Task.isCancelled
            guard Self.deferredSaveProceeds(
                cancelled: cancelled,
                alive: self != nil,
                event: "resolveHealthKitDisposal",
                vm: vmID
            ), let self else { return }
            self.resolveHealthKitDisposal(.replaceWith(dayType, rotationTrack))
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
        if session.trainingBlock != nil && !Self.hasAthleteLoggedSets(session) {
            session.planStatus = .planned
            session.isCompleted = false
            try? modelContext.save()
            return
        }
        let hasSets = Self.hasAthleteLoggedSets(session)
        if !discardLiveWork, hasSets {
            session.isCompleted = true
        } else {
            modelContext.delete(session)
        }
        try? modelContext.save()
    }

    /// Target rows from an imported plan do not count as trained work.
    @MainActor
    static func hasAthleteLoggedSets(_ session: WorkoutSession) -> Bool {
        PlannedBlockQueue.hasAthleteLoggedSets(session)
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
        let service = healthKitService
        let vmID = ObjectIdentifier(self)
        if Self.shouldCancelDeferredSaves {
            healthKitFollowUpTask?.cancel()
        }
        healthKitFollowUpTask = Task { @MainActor [weak self] in
            _ = await service.endWorkout()
            let cancelled = Task.isCancelled
            guard Self.deferredSaveProceeds(
                cancelled: cancelled,
                alive: self != nil,
                event: "completePendingAction",
                vm: vmID
            ), let self else { return }
            self.completePendingAction(action)
        }
    }

    func deleteHealthKitWorkout() {
        healthKitDecisionMade = true
        let action = pendingAction
        pendingAction = nil
        let service = healthKitService
        let vmID = ObjectIdentifier(self)
        if Self.shouldCancelDeferredSaves {
            healthKitFollowUpTask?.cancel()
        }
        healthKitFollowUpTask = Task { @MainActor [weak self] in
            await service.discardWorkout()
            let cancelled = Task.isCancelled
            guard Self.deferredSaveProceeds(
                cancelled: cancelled,
                alive: self != nil,
                event: "completePendingAction",
                vm: vmID
            ), let self else { return }
            self.completePendingAction(action)
        }
    }

    /// Number of exercises in the suspended session that have at least one set.
    var suspendedInProgressExerciseCount: Int {
        suspendedSession?.exerciseRecordsArray.filter { !$0.loggedSetsArray.isEmpty }.count ?? 0
    }

    /// True when the suspended session has at least one set logged.
    var suspendedHasSets: Bool {
        suspendedSession?.exerciseRecordsArray.contains { !$0.loggedSetsArray.isEmpty } ?? false
    }

    // MARK: - HealthKit Disposal

    private func resolveHealthKitDisposal(_ action: PendingAction) {
        let elapsed = healthKitService.wallClockElapsed
        if elapsed >= 300 {
            pendingAction = action
            healthKitDecisionMade = false
            showHealthKitKeepPrompt = true
        } else {
            let service = healthKitService
            let vmID = ObjectIdentifier(self)
            if Self.shouldCancelDeferredSaves {
                healthKitFollowUpTask?.cancel()
            }
            healthKitFollowUpTask = Task { @MainActor [weak self] in
                await service.discardWorkout()
                let cancelled = Task.isCancelled
                guard Self.deferredSaveProceeds(
                    cancelled: cancelled,
                    alive: self != nil,
                    event: "completePendingAction",
                    vm: vmID
                ), let self else { return }
                self.completePendingAction(action)
            }
        }
    }

    private func completePendingAction(_ action: PendingAction?) {
        guard let action else { return }
        switch action {
        case .cancelOnly:
            break
        case .replaceWith(let dayType, let rotationTrack):
            activateOrCreateSession(dayType: dayType, rotationTrack: rotationTrack)
        }
    }

    func finishSession() {
        guard let session = activeSession else { return }
        let wasRevisit = isProtectedHistorySession(session)
        if !wasRevisit { learnStacks(from: session) }
        // History edits stay completed the whole time; live sessions complete here.
        if !session.isCompleted {
            session.isCompleted = true
        }
        session.date = Date()
        for record in session.exerciseRecordsArray {
            for set in record.plannedSetsArray {
                modelContext.delete(set)
            }
        }
        let capturedSession = session
        pendingCoachShare = !wasRevisit && CoachAthletePreferences.shouldOfferAfterFinish
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

        SessionMath.stampDuration(
            on: capturedSession,
            liveElapsed: healthKitService.wallClockElapsed
        )
        try? modelContext.save()
        // Always ask for effort. HealthKit UUID used to gate this, so a dead
        // HK session (phone lock) skipped intensity and left Duration as "—".
        sessionPendingEffortRating = capturedSession

        let service = healthKitService
        let vmID = ObjectIdentifier(self)
        let saveID = UUID()
        // Only `cancelPendingWork` cancels a finish save. A second finish must
        // leave the first save running so its HealthKit UUID still lands.
        let task = Task { @MainActor [weak self] in
            defer { self?.finishSaveTasks[saveID] = nil }
            let uuid = await service.endWorkout()
            let cancelled = Task.isCancelled
            guard Self.deferredSaveProceeds(
                cancelled: cancelled,
                alive: self != nil,
                event: "finishSave",
                vm: vmID
            ), let self else { return }
            if let uuid {
                capturedSession.healthKitWorkoutUUID = uuid
            }
            try? self.modelContext.save()
            if let uuid = capturedSession.healthKitWorkoutUUID, let rating = capturedSession.effortRating {
                await service.saveEffortRating(rating, workoutUUID: uuid)
            }
        }
        finishSaveTasks[saveID] = task
    }

    /// Drops deferred saves so a freed store is not written after reset or restore.
    func cancelPendingWork() {
        #if DEBUG
        let vmID = ObjectIdentifier(self)
        #endif
        guard Self.shouldCancelDeferredSaves else {
            #if DEBUG
            Self.rlDiag("cancelPendingWork skipped", vm: vmID)
            #endif
            return
        }
        #if DEBUG
        Self.rlDiag("cancelPendingWork", vm: vmID)
        #endif
        finishSaveTasks.values.forEach { $0.cancel() }
        setUndoGeneration &+= 1
        setUndoTask?.cancel()
        setUndoTask = nil
        deferredPlannedStartTask?.cancel()
        deferredReplaceTask?.cancel()
        healthKitFollowUpTask?.cancel()
        finishSaveTasks.removeAll()
        deferredPlannedStartTask = nil
        deferredReplaceTask = nil
        healthKitFollowUpTask = nil
    }

    /// Every live view model. Restore runs without a reference to the one on screen.
    static func cancelLivePendingWork() {
        for entry in liveInstances {
            entry.viewModel?.cancelPendingWork()
        }
        liveInstances.removeAll { $0.viewModel == nil }
    }

    /// Re-open a completed session for set edits / skipped lifts.
    /// Keeps `isCompleted == true` so History never hides/deletes the workout.
    /// Parks any in-progress live session, skips a new HealthKit workout.
    @discardableResult
    func reopenSessionForEditing(_ session: WorkoutSession) -> Bool {
        if activeSession?.id == session.id {
            wantsFocusOnWorkoutTab = true
            // Finish leaves the completed session active under the effort sheet.
            // Re-opening that same row is a history edit: the next finish must
            // not ask for effort again. A still-live session stays unprotected.
            if session.isCompleted {
                revisitingSessionID = session.id
            }
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
            let hasSets = active.exerciseRecordsArray.contains { !$0.loggedSetsArray.isEmpty }
            if hasSets {
                // Prefer suspending; if a suspended session already exists, complete it.
                if let previous = suspendedSession, previous.id != active.id {
                    releaseParkedSession(previous, discardLiveWork: false)
                }
                suspendedSession = active
                if healthKitService.isSessionActive {
                    healthKitService.pauseWorkout()
                }
            } else if active.trainingBlock != nil
                || active.exerciseRecordsArray.contains(where: { !$0.plannedSetsArray.isEmpty })
            {
                active.planStatus = .planned
                if healthKitService.isSessionActive {
                    Task { _ = await healthKitService.endWorkout() }
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
    /// True after a live finish when Settings “Offer to send after finish” is on.
    private var pendingCoachShare = false

    /// Returns true once after a live finish that should auto-present the send sheet.
    func consumeCoachShareOffer() -> Bool {
        let offer = pendingCoachShare
        pendingCoachShare = false
        return offer
    }

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
        guard activeSession != nil else { return }
        activeSession?.unsuppressExercise(id: exercise.id)
        _ = findOrCreateRecord(for: exercise)
        try? modelContext.save()
    }

    /// Remove from this workout only (does not delete the library exercise).
    /// Hides auto-listed day exercises and deletes this session's sets/record.
    func removeExerciseFromSession(_ exercise: Exercise) {
        guard let session = activeSession else { return }
        detachFromCircuits(exercise)
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

    /// Unassign from the day plan and hide it in this session.
    func removeExerciseFromDayPlan(_ exercise: Exercise, day: DayType) {
        exercise.removeDayType(day)
        removeExerciseFromSession(exercise)
        SeedData.persistUserPlan(context: modelContext)
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
            for set in record.loggedSetsArray where !set.isWarmup {
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
        currentRecord(for: exercise)?.loggedSetsArray.isEmpty == false
    }

    /// Explicit “done with this lift” for the active mode — not inferred from set count.
    func isExerciseDone(for exercise: Exercise) -> Bool {
        currentRecord(for: exercise)?.isCompleted == true
    }

    /// Mark the lift finished (any set count, including zero to skip). Next skips done lifts.
    func markExerciseDone(_ exercise: Exercise) {
        guard let record = findOrCreateRecord(for: exercise) else { return }
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
        guard let session = activeSession, !session.isDeleted else { return nil }
        let modeRaw = selectedMode.rawValue
        return session.exerciseRecordsArray.first { record in
            guard !record.isDeleted else { return false }
            return record.exercise?.id == exercise.id &&
                record.trainingMode.rawValue == modeRaw
        }
    }

    /// Restore deletes every SwiftData row. Drop in-memory session refs so
    /// the workout tab cannot read or save zombie records (TF 13 crashes).
    func resetAfterStoreReplace() {
        _activeSession = nil
        _suspendedSession = nil
        sessionPendingEffortRating = nil
        sessionPendingSummary = nil
        pendingSummaryAfterRating = nil
        summaryDetailSession = nil
        pendingCelebration = nil
        celebratedExerciseIDsThisSession = []
        offerFinishWorkout = false
        revisitingSessionID = nil
        restEndDate = nil
        expirePendingSetUndo()
        setMutationEpoch &+= 1
    }

    // MARK: - Set Logging

    func addSet(
        exercise: Exercise,
        weight: Double,
        reps: Int,
        isWarmup: Bool = false,
        isEachSide: Bool = false,
        isAssisted: Bool = false,
        offeredWeight: Double? = nil,
        loadMode: LoadMode? = nil
    ) {
        guard let record = findOrCreateRecord(for: exercise) else { return }
        // Logging again means the lift is no longer marked done.
        record.isCompleted = false
        let setNumber = record.loggedSetsArray.count + 1
        let set = SetRecord(
            setNumber: setNumber,
            weightLbs: weight,
            reps: reps,
            isWarmup: isWarmup,
            isEachSide: isEachSide,
            isAssisted: isAssisted
        )
        set.exerciseRecord = record
        let mode = loadMode ?? exercise.loadMode
        if mode != .bar || isAssisted {
            set.loadModeRaw = (isAssisted && mode == .bar) ? LoadMode.assist.rawValue : mode.rawValue
        }
        if isAssisted { set.isAssisted = true }
        if !isWarmup, let offeredWeight, !MassMath.sameStoredPounds(offeredWeight, weight) {
            set.offeredWeightLbs = offeredWeight
        }
        let body = bodyWeightForLogging(exercise: exercise)
        if body > 0 { set.bodyWeightUsedLbs = body }
        if record.sets == nil { record.sets = [] }
        record.sets?.append(set)
        modelContext.insert(set)
        setMutationEpoch &+= 1
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
        set.isTarget = false
        // Editing while marked done keeps the lift open again.
        set.exerciseRecord?.isCompleted = false
        setMutationEpoch &+= 1
        try? modelContext.save()
        HapticService.setLogged()
    }

    func deleteSet(_ set: SetRecord, from exercise: Exercise) {
        let modeRaw = set.exerciseRecord?.trainingMode.rawValue ?? selectedMode.rawValue
        let snapshot = DeletedSetUndo(set: set, exerciseID: exercise.id, modeRaw: modeRaw)
        HapticService.swipeToDelete()
        SetMutation.delete(set, from: currentRecord(for: exercise), in: modelContext)
        setMutationEpoch &+= 1
        try? modelContext.save()
        pendingSetUndo = snapshot
        armSetUndoExpiry()
    }

    /// Put the set from the Undo toast back on its lift.
    func undoDeletedSet() {
        guard let snapshot = pendingSetUndo else { return }
        setUndoGeneration &+= 1
        setUndoTask?.cancel()
        setUndoTask = nil
        pendingSetUndo = nil
        restoreDeletedSet(snapshot)
    }

    /// Drop the Undo offer without restoring. The set stays deleted.
    func expirePendingSetUndo() {
        setUndoGeneration &+= 1
        setUndoTask?.cancel()
        setUndoTask = nil
        pendingSetUndo = nil
    }

    private func armSetUndoExpiry() {
        setUndoGeneration &+= 1
        let generation = setUndoGeneration
        let seconds = setUndoSeconds
        setUndoTask?.cancel()
        setUndoTask = Task { @MainActor [weak self] in
            let delay = max(0, seconds)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self, self.setUndoGeneration == generation else { return }
            self.pendingSetUndo = nil
            self.setUndoTask = nil
        }
    }

    private func restoreDeletedSet(_ snapshot: DeletedSetUndo) {
        let session = activeSession ?? suspendedSession
        guard let record = session?.exerciseRecordsArray.first(where: {
            $0.exercise?.id == snapshot.exerciseID && $0.trainingMode.rawValue == snapshot.modeRaw
        }) else { return }
        let set = SetRecord(
            setNumber: snapshot.setNumber,
            weightLbs: snapshot.weightLbs,
            reps: snapshot.reps,
            isWarmup: snapshot.isWarmup,
            isEachSide: snapshot.isEachSide,
            isAssisted: snapshot.isAssisted,
            isTarget: snapshot.isTarget
        )
        set.completedAt = snapshot.completedAt
        set.loadModeRaw = snapshot.loadModeRaw
        set.offeredWeightLbs = snapshot.offeredWeightLbs
        set.bodyWeightUsedLbs = snapshot.bodyWeightUsedLbs
        set.plannedRestSeconds = snapshot.plannedRestSeconds
        set.actualRestSeconds = snapshot.actualRestSeconds
        set.exerciseRecord = record
        set.setNumber = Int.max
        if record.sets == nil { record.sets = [] }
        record.sets?.append(set)
        modelContext.insert(set)
        var logged = record.loggedSetsArray.filter { $0.id != set.id }
            .sorted { $0.setNumber < $1.setNumber }
        let index = min(max(snapshot.setNumber - 1, 0), logged.count)
        logged.insert(set, at: index)
        for (offset, item) in logged.enumerated() {
            item.setNumber = offset + 1
        }
        record.isCompleted = false
        setMutationEpoch &+= 1
        try? modelContext.save()
    }

    /// Persist a cue on the exercise (and this session's record when one exists).
    func saveExerciseNote(_ text: String, for exercise: Exercise) {
        let trimmed = String(text.prefix(280)).trimmingCharacters(in: .whitespacesAndNewlines)
        exercise.notes = trimmed
        if let record = currentRecord(for: exercise) {
            record.notes = trimmed
        }
        try? modelContext.save()
    }

    /// After marking a lift done, offer finish when every visible lift is done.
    func offerFinishIfAllLiftsDone(in exercises: [Exercise]) {
        let doneCount = exercises.filter { isExerciseDone(for: $0) }.count
        let hasAnySets = activeSession?.exerciseRecordsArray.contains { !$0.loggedSetsArray.isEmpty } ?? false
        if WorkoutCompletionLogic.shouldOfferFinish(
            liftCount: exercises.count,
            doneCount: doneCount,
            hasAnySets: hasAnySets
        ) {
            offerFinishWorkout = true
        }
    }

    // MARK: - Helpers

    /// Start the next unused queued session when its day type matches.
    /// A different day type leaves the queue untouched.
    private func activateOrCreateSession(
        dayType: DayType,
        rotationTrack: RotationTrack,
        now: Date = .now
    ) {
        if let planned = earliestUnusedPlannedSession(dayType: dayType) {
            activatePlannedSession(planned, rotationTrack: rotationTrack, now: now)
            return
        }
        let session = WorkoutSession(dayType: dayType, date: now, rotationTrack: rotationTrack)
        modelContext.insert(session)
        assignCurrentGym(to: session)
        try? modelContext.save()
        activeSession = session
        celebratedExerciseIDsThisSession = []
        startHealthKitWorkout()
    }

    private func activatePlannedSession(
        _ session: WorkoutSession,
        rotationTrack: RotationTrack,
        now: Date
    ) {
        session.planStatus = .none
        session.track = rotationTrack
        session.isCompleted = false
        session.date = now
        assignCurrentGym(to: session)
        suppressUnplannedDayLifts(on: session)
        try? modelContext.save()
        activeSession = session
        celebratedExerciseIDsThisSession = []
        startHealthKitWorkout()
    }

    private func allIncompleteSessions() -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.isCompleted == false }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Hide day-plan lifts that are not in this planned session (session-only).
    private func suppressUnplannedDayLifts(on session: WorkoutSession) {
        let plannedIDs = Set(session.exerciseRecordsArray.compactMap { $0.exercise?.id })
        guard !plannedIDs.isEmpty else { return }
        for exercise in exercises(for: session.day) where !plannedIDs.contains(exercise.id) {
            session.suppressExercise(id: exercise.id)
        }
    }

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

    /// Nil when the live session is gone (restore, cancel, or a deleted row).
    /// Logging must not crash in that state.
    private func findOrCreateRecord(for exercise: Exercise) -> ExerciseRecord? {
        if let existing = currentRecord(for: exercise) {
            return existing
        }

        guard let session = activeSession, !session.isDeleted else {
            return nil
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

    private func bodyWeightForLogging(exercise: Exercise) -> Double {
        let entries = (try? modelContext.fetch(FetchDescriptor<BodyMetricEntry>())) ?? []
        let weighIns = entries.filter { $0.kind == .weight }.map {
            LoadMath.WeighIn(date: $0.date, pounds: $0.value)
        }
        return LoadMath.bodyWeight(asOf: .now, weighIns: weighIns, settingsPounds: BodyWeightPreferences.pounds)
    }
}
