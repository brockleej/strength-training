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
            .reduce(0) { $0 + $1.weightLbs * Double($1.reps) }
    }

    static func setCount(of session: WorkoutSession) -> Int {
        session.exerciseRecordsArray.reduce(0) { $0 + $1.setsArray.count }
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
                .map { E1RM.estimate(weightLbs: $0.weightLbs, reps: $0.reps) }
                .max() ?? 0
            guard sessionBest > 0 else { continue }
            let allTimeBest = allSessions
                .flatMap { $0.exerciseRecordsArray }
                .filter { $0.exercise?.id == exercise.id }
                .flatMap { $0.setsArray }
                .filter { !$0.isWarmup }
                .map { E1RM.estimate(weightLbs: $0.weightLbs, reps: $0.reps) }
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
}
