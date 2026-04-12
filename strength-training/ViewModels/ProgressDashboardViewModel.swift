//
//  ProgressDashboardViewModel.swift
//  strength-training
//

import SwiftUI
import SwiftData

@Observable
final class ProgressDashboardViewModel {
    var modelContext: ModelContext
    var selectedTimeRange: ProgressTimeRange = .twelveWeeks
    var volumeFilterMode: TrainingMode? = nil
    var modeSplitPeriod: ModeSplitPeriod = .week

    enum ModeSplitPeriod: String, CaseIterable {
        case week = "Week"
        case month = "Month"
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Core Data Fetch

    private func fetchCompletedSessions() -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.isCompleted == true },
            sortBy: [SortDescriptor(\WorkoutSession.date, order: .reverse)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []

        guard let startDate = selectedTimeRange.startDate else { return all }
        return all.filter { $0.date >= startDate }
    }

    private func allWorkingSets() -> [(set: SetRecord, record: ExerciseRecord, session: WorkoutSession)] {
        fetchCompletedSessions().flatMap { session in
            session.exerciseRecordsArray.flatMap { record in
                record.setsArray
                    .filter { !$0.isWarmup }
                    .map { (set: $0, record: record, session: session) }
            }
        }
    }

    private func fetchAllCompletedSessions() -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.isCompleted == true },
            sortBy: [SortDescriptor(\WorkoutSession.date, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Strength Score

    var strengthScore: Double {
        computeStrengthScore(from: fetchCompletedSessions())
    }

    var strengthScoreTrend: TrendDirection {
        let allSessions = fetchAllCompletedSessions()
        let current = computeStrengthScore(from: allSessions)

        let calendar = Calendar.current
        guard let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: .now) else {
            return .insufficientData
        }
        let pastSessions = allSessions.filter { $0.date <= oneMonthAgo }
        guard !pastSessions.isEmpty else { return .insufficientData }
        let past = computeStrengthScore(from: pastSessions)

        if current > past * 1.01 { return .up }
        if current < past * 0.99 { return .down }
        return .flat
    }

    var strengthScoreDelta: Double {
        let allSessions = fetchAllCompletedSessions()
        let current = computeStrengthScore(from: allSessions)

        let calendar = Calendar.current
        guard let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: .now) else { return 0 }
        let pastSessions = allSessions.filter { $0.date <= oneMonthAgo }
        let past = computeStrengthScore(from: pastSessions)
        return current - past
    }

    private func computeStrengthScore(from sessions: [WorkoutSession]) -> Double {
        var bestE1RMPerExercise: [UUID: Double] = [:]

        for session in sessions {
            for record in session.exerciseRecordsArray {
                guard let exerciseID = record.exercise?.id else { continue }
                let workingSets = record.setsArray.filter { !$0.isWarmup }
                for set in workingSets {
                    let e1rm = set.weightLbs * (1.0 + Double(set.reps) / 30.0)
                    if e1rm > (bestE1RMPerExercise[exerciseID] ?? 0) {
                        bestE1RMPerExercise[exerciseID] = e1rm
                    }
                }
            }
        }

        return bestE1RMPerExercise.values.reduce(0, +)
    }

    // MARK: - Volume Score

    var volumeScore: Double {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let sets = allWorkingSets()

        return sets
            .filter { tuple in
                tuple.session.date >= startOfWeek &&
                (volumeFilterMode == nil || tuple.record.trainingMode == volumeFilterMode)
            }
            .reduce(0.0) { $0 + $1.set.weightLbs * Double($1.set.reps) }
    }

    var volumeScoreTrend: TrendDirection {
        let calendar = Calendar.current
        let allSessions = fetchAllCompletedSessions()

        guard let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start,
              let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart)
        else { return .insufficientData }

        let thisWeekVolume = weeklyVolume(sessions: allSessions, weekStart: thisWeekStart)
        let lastWeekVolume = weeklyVolume(sessions: allSessions, weekStart: lastWeekStart)

        guard lastWeekVolume > 0 else { return .insufficientData }
        if thisWeekVolume > lastWeekVolume * 1.01 { return .up }
        if thisWeekVolume < lastWeekVolume * 0.99 { return .down }
        return .flat
    }

    var volumeScoreDelta: Double {
        let calendar = Calendar.current
        let allSessions = fetchAllCompletedSessions()

        guard let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start,
              let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart)
        else { return 0 }

        let thisWeek = weeklyVolume(sessions: allSessions, weekStart: thisWeekStart)
        let lastWeek = weeklyVolume(sessions: allSessions, weekStart: lastWeekStart)
        return thisWeek - lastWeek
    }

    private func weeklyVolume(sessions: [WorkoutSession], weekStart: Date) -> Double {
        let calendar = Calendar.current
        guard let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { return 0 }

        let weekSessions = sessions.filter { $0.date >= weekStart && $0.date < weekEnd }
        let allRecords = weekSessions.flatMap { $0.exerciseRecordsArray }

        var total: Double = 0
        for record in allRecords {
            let workingSets = record.setsArray.filter { !$0.isWarmup }
            if volumeFilterMode == nil || record.trainingMode == volumeFilterMode {
                for set in workingSets {
                    total += set.weightLbs * Double(set.reps)
                }
            }
        }
        return total
    }

    // MARK: - PRs This Month

    var prsThisMonth: [PersonalRecord] {
        let calendar = Calendar.current
        guard let monthStart = calendar.dateInterval(of: .month, for: .now)?.start else { return [] }

        let allSessions = fetchAllCompletedSessions()
            .sorted { $0.date < $1.date }
        let currentMonthSessions = allSessions.filter { $0.date >= monthStart }

        var prs: [PersonalRecord] = []
        let allExercises = self.allExercises()

        for exercise in allExercises {
            // All records for this exercise sorted chronologically
            let allRecords = allSessions
                .flatMap { $0.exerciseRecordsArray }
                .filter { $0.exercise?.id == exercise.id }

            let allWorkingSets = allRecords.flatMap { $0.setsArray.filter { !$0.isWarmup } }
            guard !allWorkingSets.isEmpty else { continue }

            // Current month records for this exercise, sorted by date
            let currentRecords = currentMonthSessions
                .sorted { $0.date < $1.date }
                .flatMap { session in
                    session.exerciseRecordsArray
                        .filter { $0.exercise?.id == exercise.id }
                        .map { (record: $0, date: session.date) }
                }

            // Track running best across all sessions up to each point
            var runningBestE1RM: Double = 0
            var runningBestWeight: Double = 0
            var bestE1RMAlreadyPR = false
            var bestWeightAlreadyPR = false

            for session in allSessions {
                let records = session.exerciseRecordsArray.filter { $0.exercise?.id == exercise.id }
                for record in records {
                    let sets = record.setsArray.filter { !$0.isWarmup }
                    let sessionBestE1RM = sets.map { $0.weightLbs * (1.0 + Double($0.reps) / 30.0) }.max() ?? 0
                    let sessionBestWeight = sets.map(\.weightLbs).max() ?? 0

                    let isCurrentMonth = session.date >= monthStart

                    if sessionBestE1RM > runningBestE1RM {
                        if isCurrentMonth && runningBestE1RM > 0 && !bestE1RMAlreadyPR {
                            prs.append(PersonalRecord(
                                exerciseName: exercise.name,
                                type: .estimatedOneRM,
                                value: sessionBestE1RM,
                                date: session.date
                            ))
                            bestE1RMAlreadyPR = true
                        } else if isCurrentMonth && runningBestE1RM == 0 {
                            // First month of data — mark the overall best this month as a PR
                            // We'll handle this after the loop
                        }
                        runningBestE1RM = sessionBestE1RM
                    }

                    if sessionBestWeight > runningBestWeight {
                        if isCurrentMonth && runningBestWeight > 0 && !bestWeightAlreadyPR {
                            prs.append(PersonalRecord(
                                exerciseName: exercise.name,
                                type: .topSetWeight,
                                value: sessionBestWeight,
                                date: session.date
                            ))
                            bestWeightAlreadyPR = true
                        }
                        runningBestWeight = sessionBestWeight
                    }
                }
            }

            // For first month of data: find the best e1RM across multiple sessions this month
            // and mark it as a PR if there are at least 2 sessions
            if !bestE1RMAlreadyPR && currentRecords.count >= 2 {
                var monthRunningBest: Double = 0
                for (record, date) in currentRecords {
                    let sets = record.setsArray.filter { !$0.isWarmup }
                    let best = sets.map { $0.weightLbs * (1.0 + Double($0.reps) / 30.0) }.max() ?? 0
                    if best > monthRunningBest && monthRunningBest > 0 {
                        prs.append(PersonalRecord(
                            exerciseName: exercise.name,
                            type: .estimatedOneRM,
                            value: best,
                            date: date
                        ))
                        bestE1RMAlreadyPR = true
                    }
                    if best > monthRunningBest { monthRunningBest = best }
                }
            }

            if !bestWeightAlreadyPR && currentRecords.count >= 2 {
                var monthRunningBest: Double = 0
                for (record, date) in currentRecords {
                    let sets = record.setsArray.filter { !$0.isWarmup }
                    let best = sets.map(\.weightLbs).max() ?? 0
                    if best > monthRunningBest && monthRunningBest > 0 {
                        prs.append(PersonalRecord(
                            exerciseName: exercise.name,
                            type: .topSetWeight,
                            value: best,
                            date: date
                        ))
                    }
                    if best > monthRunningBest { monthRunningBest = best }
                }
            }
        }

        return prs.sorted { $0.date > $1.date }
    }

    // MARK: - Muscle Group Volume

    var muscleGroupVolumes: [MuscleGroupVolume] {
        var volumeByGroup: [String: Double] = [:]

        for tuple in allWorkingSets() {
            let group = tuple.record.exercise?.muscleGroup ?? "Other"
            guard !group.isEmpty else { continue }
            volumeByGroup[group, default: 0] += tuple.set.weightLbs * Double(tuple.set.reps)
        }

        return volumeByGroup
            .map { MuscleGroupVolume(muscleGroup: $0.key, volume: $0.value) }
            .sorted { $0.volume > $1.volume }
    }

    // MARK: - Mode Split

    var modeSplit: [ModeSplitData] {
        let calendar = Calendar.current
        let periodStart: Date?

        switch modeSplitPeriod {
        case .week:
            periodStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start
        case .month:
            periodStart = calendar.dateInterval(of: .month, for: .now)?.start
        }

        let sets = allWorkingSets().filter { tuple in
            guard let start = periodStart else { return true }
            return tuple.session.date >= start
        }

        var volumeByMode: [TrainingMode: Double] = [:]
        for tuple in sets {
            volumeByMode[tuple.record.trainingMode, default: 0] += tuple.set.weightLbs * Double(tuple.set.reps)
        }

        let total = volumeByMode.values.reduce(0, +)
        guard total > 0 else { return [] }

        return TrainingMode.allCases.compactMap { mode in
            let value = volumeByMode[mode] ?? 0
            guard value > 0 else { return nil }
            return ModeSplitData(mode: mode, value: value, percentage: value / total)
        }
    }

    // MARK: - Exercise List

    func allExercises() -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>(
            sortBy: [SortDescriptor(\Exercise.sortOrder)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func exercisesGroupedByDayType() -> [(DayType, [Exercise])] {
        let all = allExercises()
        return [DayType.arms, DayType.legs].compactMap { dayType in
            let exercises = all.filter { $0.dayType == dayType }
            return exercises.isEmpty ? nil : (dayType, exercises)
        }
    }
}
