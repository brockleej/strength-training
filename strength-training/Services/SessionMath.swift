//
//  SessionMath.swift
//  strength-training
//
//  Shared per-session aggregates used by Today's Yesterday card, the
//  Workout Summary, and History. PR rule matches the History PR badge:
//  an exercise "has a PR in this session" when its session-best e1RM ties
//  or beats the all-time best across completed sessions (>=, self-inclusive
//  for completed sessions; warmups excluded; deduped per exercise).
//

import Foundation

enum SessionMath {

    static func volume(of session: WorkoutSession) -> Double {
        session.exerciseRecordsArray
            .flatMap { $0.setsArray }
            .reduce(0) { $0 + $1.volumeContribution }
    }

    static func setCount(of session: WorkoutSession) -> Int {
        session.exerciseRecordsArray.reduce(0) { $0 + $1.setsArray.count }
    }

    /// Minutes string ("47") for UI. Nil when we have no stored or inferred length.
    static func durationMinutesLabel(of session: WorkoutSession) -> String? {
        WorkoutDurationLogic.minutesLabel(durationSeconds(of: session))
    }

    static func durationSeconds(of session: WorkoutSession) -> TimeInterval {
        WorkoutDurationLogic.resolvedSeconds(
            stored: session.durationSeconds,
            sessionStart: session.date,
            setDates: session.exerciseRecordsArray.flatMap { $0.setsArray.map(\.completedAt) }
        )
    }

    static func stampDuration(
        on session: WorkoutSession,
        liveElapsed: TimeInterval,
        now: Date = .now
    ) {
        let setDates = session.exerciseRecordsArray.flatMap { $0.setsArray.map(\.completedAt) }
        let seconds = WorkoutDurationLogic.secondsToStore(
            liveElapsed: liveElapsed,
            sessionStart: session.date,
            setDates: setDates,
            now: now
        )
        if seconds > 0 {
            session.durationSeconds = seconds
        }
    }

    /// Names of exercises whose session-best e1RM ties/beats the all-time best.
    static func e1RMPRExerciseNames(for session: WorkoutSession, allSessions: [WorkoutSession]) -> [String] {
        var counted = Set<UUID>()
        var names: [String] = []
        // Relationship arrays are unordered — sort so callout name order is stable.
        for record in session.exerciseRecordsArray.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            guard let exercise = record.exercise, !counted.contains(exercise.id) else { continue }
            let sessionBest = session.exerciseRecordsArray
                .filter { $0.exercise?.id == exercise.id }
                .flatMap { $0.setsArray }
                .filter { !$0.isWarmup }
                .map(\.estimatedE1RM)
                .max() ?? 0
            guard sessionBest > 0 else { continue }
            let allTimeBest = allSessions
                .flatMap { $0.exerciseRecordsArray }
                .filter { $0.exercise?.id == exercise.id }
                .flatMap { $0.setsArray }
                .filter { !$0.isWarmup }
                .map(\.estimatedE1RM)
                .max() ?? 0
            if sessionBest >= allTimeBest {
                counted.insert(exercise.id)
                names.append(exercise.name)
            }
        }
        return names
    }

    static func e1RMPRCount(for session: WorkoutSession, allSessions: [WorkoutSession]) -> Int {
        e1RMPRExerciseNames(for: session, allSessions: allSessions).count
    }

    /// One-pass all-time best e1RM per exercise across the given sessions.
    /// Precompute once, then use the dictionary overloads below — turns
    /// History's per-row scans from O(sessions × sets) into O(records).
    static func allTimeBestE1RMs(across sessions: [WorkoutSession]) -> [UUID: Double] {
        var best: [UUID: Double] = [:]
        for session in sessions {
            for record in session.exerciseRecordsArray {
                guard let exerciseID = record.exercise?.id else { continue }
                for set in record.setsArray where !set.isWarmup {
                    let e1rm = set.estimatedE1RM
                    if e1rm > best[exerciseID, default: 0] {
                        best[exerciseID] = e1rm
                    }
                }
            }
        }
        return best
    }

    /// Dictionary-backed variant of e1RMPRCount (same >= self-inclusive rule).
    static func e1RMPRCount(for session: WorkoutSession, allTimeBests: [UUID: Double]) -> Int {
        var counted = Set<UUID>()
        var count = 0
        for record in session.exerciseRecordsArray.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            guard let exercise = record.exercise, !counted.contains(exercise.id) else { continue }
            let sessionBest = session.exerciseRecordsArray
                .filter { $0.exercise?.id == exercise.id }
                .flatMap { $0.setsArray }
                .filter { !$0.isWarmup }
                .map(\.estimatedE1RM)
                .max() ?? 0
            guard sessionBest > 0 else { continue }
            if sessionBest >= allTimeBests[exercise.id, default: 0] {
                counted.insert(exercise.id)
                count += 1
            }
        }
        return count
    }

    // MARK: - vs previous session

    /// Snapshot used on Workout Summary / Session Detail for “vs last time”.
    struct SessionComparison: Equatable {
        /// Prior completed session of the same day type (prefer same A/B track).
        let previous: WorkoutSession
        let volume: Double
        let setCount: Int
        let volumeDelta: Double
        let setDelta: Int
        /// True when previous matched rotation track (A/B), not just day type.
        let matchedRotation: Bool
        let prNames: [String]

        var volumeDeltaPercent: Double? {
            guard previousVolume > 0 else { return nil }
            return (volumeDelta / previousVolume) * 100
        }

        private var previousVolume: Double { volume - volumeDelta }
    }

    /// Most recent completed session before `session` on the same day type.
    /// Prefers same rotation track (A/B); falls back to any prior of that day.
    static func previousComparableSession(
        to session: WorkoutSession,
        among completed: [WorkoutSession]
    ) -> (session: WorkoutSession, matchedRotation: Bool)? {
        let sameDay = completed.filter {
            $0.id != session.id
                && $0.isCompleted
                && $0.dayType == session.dayType
                && $0.date < session.date
        }
        .sorted { $0.date > $1.date }

        guard !sameDay.isEmpty else { return nil }

        let track = session.track
        if track == .a || track == .b,
           let sameTrack = sameDay.first(where: { $0.track == track }) {
            return (sameTrack, true)
        }
        if let any = sameDay.first {
            return (any, false)
        }
        return nil
    }

    static func comparison(
        for session: WorkoutSession,
        among completed: [WorkoutSession]
    ) -> SessionComparison? {
        guard let prior = previousComparableSession(to: session, among: completed) else {
            return nil
        }
        let vol = volume(of: session)
        let sets = setCount(of: session)
        let prevVol = volume(of: prior.session)
        let prevSets = setCount(of: prior.session)
        return SessionComparison(
            previous: prior.session,
            volume: vol,
            setCount: sets,
            volumeDelta: vol - prevVol,
            setDelta: sets - prevSets,
            matchedRotation: prior.matchedRotation,
            prNames: e1RMPRExerciseNames(for: session, allSessions: completed)
        )
    }

    static func formatSignedVolume(_ delta: Double) -> String {
        let absText = TodayStats.formatVolume(abs(delta))
        if delta > 0 { return "+\(absText)" }
        if delta < 0 { return "−\(absText)" }
        return absText
    }

    static func formatSignedCount(_ delta: Int) -> String {
        if delta > 0 { return "+\(delta)" }
        if delta < 0 { return "−\(abs(delta))" }
        return "0"
    }
}

/// Gym duration is first logged set → last logged set.
/// Start-button idle and a late Finish must not inflate the time.
enum WorkoutDurationLogic {
    /// Max extra after the last set when Finish is tapped (put-away / effort screen).
    static let wrapUpAllowance: TimeInterval = 15 * 60

    static func resolvedSeconds(
        stored: TimeInterval,
        sessionStart: Date,
        setDates: [Date]
    ) -> TimeInterval {
        let inferred = inferredSeconds(sessionStart: sessionStart, setDates: setDates)
        if stored > 0 {
            if inferred > 0, stored > inferred + wrapUpAllowance {
                return inferred
            }
            return stored
        }
        return inferred
    }

    static func inferredSeconds(sessionStart: Date, setDates: [Date]) -> TimeInterval {
        guard let first = setDates.min(), let last = setDates.max() else { return 0 }
        return max(0, last.timeIntervalSince(first))
    }

    static func secondsToStore(
        liveElapsed: TimeInterval,
        sessionStart: Date,
        setDates: [Date],
        now: Date
    ) -> TimeInterval {
        let inferred = inferredSeconds(sessionStart: sessionStart, setDates: setDates)
        guard let last = setDates.max() else {
            return 0
        }
        let wrapUp = min(max(0, now.timeIntervalSince(last)), wrapUpAllowance)
        return inferred + wrapUp
    }

    static func minutesLabel(_ seconds: TimeInterval) -> String? {
        guard seconds > 0 else { return nil }
        return "\(max(1, Int((seconds / 60).rounded())))"
    }
}
