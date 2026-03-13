//
//  RecoveryViewModel.swift
//  strength-training
//

import SwiftUI
import SwiftData

@Observable
final class RecoveryViewModel {
    var modelContext: ModelContext

    private(set) var dayTypeReadiness: [DayType: ReadinessLevel] = [:]
    private(set) var dayTypeWarnings: [DayType: [OvertrainingWarning]] = [:]

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        refresh()
    }

    func refresh() {
        let sessions = fetchRecentSessions(days: 28)
        let allSessions = fetchAllCompletedSessions()
        let exercises = fetchExercises()

        // Compute readiness per day type
        var readiness: [DayType: ReadinessLevel] = [:]
        for dayType in DayType.allCases {
            readiness[dayType] = RecoveryService.dayTypeReadiness(
                sessions: sessions,
                dayType: dayType
            )
        }
        dayTypeReadiness = readiness

        // Compute overtraining warnings per day type
        let allWarnings = RecoveryService.overtrainingWarnings(
            sessions: allSessions,
            exercises: exercises
        )
        var warningsByDayType: [DayType: [OvertrainingWarning]] = [:]
        for dayType in DayType.allCases {
            let dayTypeExerciseNames = Set(
                exercises
                    .filter { dayType == .fullBody || $0.dayType == dayType }
                    .map(\.name)
            )
            warningsByDayType[dayType] = allWarnings.filter {
                dayTypeExerciseNames.contains($0.exerciseName)
            }
        }
        dayTypeWarnings = warningsByDayType
    }

    func muscleGroupDetail(for dayType: DayType) -> [MuscleGroupFatigue] {
        let sessions = fetchRecentSessions(days: 28)
        return RecoveryService.muscleGroupReadiness(
            sessions: sessions,
            for: dayType.muscleGroups
        )
    }

    func readiness(for dayType: DayType) -> ReadinessLevel {
        dayTypeReadiness[dayType] ?? .fresh
    }

    func warnings(for dayType: DayType) -> [OvertrainingWarning] {
        dayTypeWarnings[dayType] ?? []
    }

    // MARK: - Data Fetching

    private func fetchRecentSessions(days: Int) -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.isCompleted == true },
            sortBy: [SortDescriptor(\WorkoutSession.date, order: .reverse)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        return all.filter { $0.date >= cutoff }
    }

    private func fetchAllCompletedSessions() -> [WorkoutSession] {
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
}
