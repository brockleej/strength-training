//
//  RecoveryViewModel.swift
//  strength-training
//

import SwiftUI
import SwiftData

extension Notification.Name {
    static let workoutDataDidChange = Notification.Name("workoutDataDidChange")
}

@Observable
final class RecoveryViewModel {
    var modelContext: ModelContext

    private(set) var dayTypeReadiness: [DayType: ReadinessLevel] = [:]
    private(set) var dayTypeWarnings: [DayType: [OvertrainingWarning]] = [:]

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        refresh()

        NotificationCenter.default.addObserver(
            forName: .workoutDataDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        let allSessions = fetchCompletedSessions()
        let exercises = fetchExercises()

        // Filter recent sessions for readiness (reuse the single fetch)
        let cutoff = Calendar.current.date(byAdding: .day, value: -28, to: .now)!
        let recentSessions = allSessions.filter { $0.date >= cutoff }

        // Compute readiness per day type using exercises for dynamic muscle groups
        var readiness: [DayType: ReadinessLevel] = [:]
        for dayType in DayType.allCases {
            let muscleGroups = Self.muscleGroups(for: dayType, from: exercises)
            let fatigueData = RecoveryService.muscleGroupReadiness(sessions: recentSessions, for: muscleGroups)
            let minScore = fatigueData.map(\.readinessScore).min() ?? 1.0
            readiness[dayType] = ReadinessLevel(score: minScore)
        }
        dayTypeReadiness = readiness

        // Compute overtraining warnings per day type (group by exercise ID)
        let allWarnings = RecoveryService.overtrainingWarnings(
            sessions: allSessions,
            exercises: exercises
        )
        var warningsByDayType: [DayType: [OvertrainingWarning]] = [:]
        for dayType in DayType.allCases {
            let dayTypeExerciseIDs = Set(
                exercises
                    .filter { dayType == .fullBody || $0.dayType == dayType }
                    .map(\.id)
            )
            warningsByDayType[dayType] = allWarnings.filter {
                dayTypeExerciseIDs.contains($0.id)
            }
        }
        dayTypeWarnings = warningsByDayType
    }

    func muscleGroupDetail(for dayType: DayType) -> [MuscleGroupFatigue] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -28, to: .now)!
        let sessions = fetchCompletedSessions().filter { $0.date >= cutoff }
        let exercises = fetchExercises()
        let muscleGroups = Self.muscleGroups(for: dayType, from: exercises)
        return RecoveryService.muscleGroupReadiness(
            sessions: sessions,
            for: muscleGroups
        )
    }

    func readiness(for dayType: DayType) -> ReadinessLevel {
        dayTypeReadiness[dayType] ?? .fresh
    }

    func warnings(for dayType: DayType) -> [OvertrainingWarning] {
        dayTypeWarnings[dayType] ?? []
    }

    // MARK: - Data Fetching

    private func fetchCompletedSessions() -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.isCompleted == true },
            sortBy: [SortDescriptor(\WorkoutSession.date, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchExercises() -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>(
            sortBy: [SortDescriptor(\Exercise.sortOrder)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Helpers

    static func muscleGroups(for dayType: DayType, from exercises: [Exercise]) -> [String] {
        let filtered = exercises.filter { dayType == .fullBody || $0.dayType == dayType }
        let dynamic = Array(Set(filtered.map(\.muscleGroup)).filter { !$0.isEmpty })
        // Fall back to hardcoded defaults if no exercises exist yet
        return dynamic.isEmpty ? dayType.muscleGroups : dynamic
    }
}
