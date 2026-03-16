//
//  RecoveryService.swift
//  strength-training
//

import Foundation
import SwiftUI

// MARK: - Data Types

enum ReadinessLevel: Comparable {
    case fatigued   // red    — score < 0.4
    case moderate   // yellow — score 0.4..<0.7
    case fresh      // green  — score >= 0.7

    var color: Color {
        switch self {
        case .fresh: .green
        case .moderate: .yellow
        case .fatigued: .red
        }
    }

    var label: String {
        switch self {
        case .fresh: "Fresh"
        case .moderate: "Moderate"
        case .fatigued: "Fatigued"
        }
    }

    init(score: Double) {
        if score >= 0.7 {
            self = .fresh
        } else if score >= 0.4 {
            self = .moderate
        } else {
            self = .fatigued
        }
    }
}

struct MuscleGroupFatigue: Identifiable {
    var id: String { muscleGroup }
    let muscleGroup: String
    let readinessScore: Double
    let readinessLevel: ReadinessLevel
    let recentVolume: Double
    let averageVolume: Double
    let hoursSinceLastTrained: Double?
}

struct OvertrainingWarning: Identifiable {
    let id: UUID
    let exerciseName: String
    let consecutiveDeclines: Int
    let e1rmDeclinePercent: Double
}

// MARK: - Recovery Service

enum RecoveryService {

    // MARK: - Per-Muscle-Group Readiness

    static func muscleGroupReadiness(
        sessions: [WorkoutSession],
        for muscleGroups: [String]
    ) -> [MuscleGroupFatigue] {
        let now = Date.now
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let twentyEightDaysAgo = calendar.date(byAdding: .day, value: -28, to: now)!

        return muscleGroups.map { muscleGroup in
            // Collect all working sets for this muscle group with their session dates
            let setsWithDates = sessions.flatMap { session in
                session.exerciseRecords
                    .filter { $0.exercise?.muscleGroup == muscleGroup }
                    .flatMap { record in
                        record.sets
                            .filter { !$0.isWarmup }
                            .map { (set: $0, date: session.date) }
                    }
            }

            // 7-day rolling volume
            let recentVolume = setsWithDates
                .filter { $0.date >= sevenDaysAgo }
                .reduce(0.0) { $0 + $1.set.weightLbs * Double($1.set.reps) }

            // 28-day volume ÷ 4 for weekly average
            let fourWeekVolume = setsWithDates
                .filter { $0.date >= twentyEightDaysAgo }
                .reduce(0.0) { $0 + $1.set.weightLbs * Double($1.set.reps) }
            let averageWeeklyVolume = fourWeekVolume / 4.0

            // Volume ratio (clamped to avoid division by zero)
            let volumeRatio: Double
            if averageWeeklyVolume > 0 {
                volumeRatio = recentVolume / averageWeeklyVolume
            } else {
                volumeRatio = 0
            }

            // Recovery decay — hours since last session that worked this muscle group
            let lastSessionDate = sessions
                .filter { session in
                    session.exerciseRecords.contains { $0.exercise?.muscleGroup == muscleGroup }
                }
                .map(\.date)
                .max()

            let hoursSinceLastTrained: Double?
            let recoveryFactor: Double

            if let lastDate = lastSessionDate {
                let hours = now.timeIntervalSince(lastDate) / 3600.0
                hoursSinceLastTrained = hours

                // Adjust half-life based on training frequency (sessions per week for this group)
                let sessionsIn28Days = sessions
                    .filter { session in
                        session.date >= twentyEightDaysAgo &&
                        session.exerciseRecords.contains { $0.exercise?.muscleGroup == muscleGroup }
                    }
                    .count
                let weeklyFrequency = Double(sessionsIn28Days) / 4.0

                let halfLife: Double
                if weeklyFrequency >= 4 {
                    halfLife = 24.0
                } else if weeklyFrequency >= 2 {
                    halfLife = 18.0
                } else {
                    halfLife = 14.0
                }

                // Exponential recovery: approaches 1.0 as hours increase
                recoveryFactor = 1.0 - exp(-hours / halfLife)
            } else {
                hoursSinceLastTrained = nil
                recoveryFactor = 1.0 // Never trained = fully fresh
            }

            // Combined readiness: 50% recovery time + 50% volume load
            let volumeLoadFactor = 1.0 - min(volumeRatio / 2.0, 1.0)
            let readinessScore = max(0, min(1, recoveryFactor * 0.5 + volumeLoadFactor * 0.5))

            return MuscleGroupFatigue(
                muscleGroup: muscleGroup,
                readinessScore: readinessScore,
                readinessLevel: ReadinessLevel(score: readinessScore),
                recentVolume: recentVolume,
                averageVolume: averageWeeklyVolume,
                hoursSinceLastTrained: hoursSinceLastTrained
            )
        }
    }

    // MARK: - Day Type Readiness

    static func dayTypeReadiness(
        sessions: [WorkoutSession],
        dayType: DayType
    ) -> ReadinessLevel {
        let fatigueData = muscleGroupReadiness(sessions: sessions, for: dayType.muscleGroups)
        guard let minScore = fatigueData.map(\.readinessScore).min() else {
            return .fresh
        }
        return ReadinessLevel(score: minScore)
    }

    // MARK: - Overtraining Detection

    static func overtrainingWarnings(
        sessions: [WorkoutSession],
        exercises: [Exercise]
    ) -> [OvertrainingWarning] {
        let sortedSessions = sessions.sorted { $0.date < $1.date }
        var warnings: [OvertrainingWarning] = []

        for exercise in exercises {
            // Get per-session best e1RM and volume, chronologically
            var sessionData: [(e1rm: Double, volume: Double)] = []

            for session in sortedSessions {
                let records = session.exerciseRecords.filter { $0.exercise?.id == exercise.id }
                let workingSets = records.flatMap { $0.sets.filter { !$0.isWarmup } }
                guard !workingSets.isEmpty else { continue }

                let bestE1RM = workingSets
                    .map { $0.weightLbs * (1.0 + Double($0.reps) / 30.0) }
                    .max() ?? 0
                let volume = workingSets
                    .reduce(0.0) { $0 + $1.weightLbs * Double($1.reps) }

                sessionData.append((e1rm: bestE1RM, volume: volume))
            }

            guard sessionData.count >= 3 else { continue }

            // Check trailing consecutive e1RM declines where volume didn't decrease
            var consecutiveDeclines = 0
            let lastIndex = sessionData.count - 1

            for i in stride(from: lastIndex, through: 1, by: -1) {
                let current = sessionData[i]
                let previous = sessionData[i - 1]

                if current.e1rm < previous.e1rm && current.volume >= previous.volume * 0.9 {
                    consecutiveDeclines += 1
                } else {
                    break
                }
            }

            if consecutiveDeclines >= 3 {
                let peakE1RM = sessionData[lastIndex - consecutiveDeclines].e1rm
                let currentE1RM = sessionData[lastIndex].e1rm

                guard peakE1RM > 0 else { continue }
                let declinePercent = ((peakE1RM - currentE1RM) / peakE1RM) * 100

                warnings.append(OvertrainingWarning(
                    id: exercise.id,
                    exerciseName: exercise.name,
                    consecutiveDeclines: consecutiveDeclines,
                    e1rmDeclinePercent: declinePercent
                ))
            }
        }

        return warnings
    }
}
