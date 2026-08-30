//
//  ProgressDashboardViewModel.swift
//  strength-training
//

import SwiftUI
import SwiftData

@Observable
final class ProgressDashboardViewModel {
    var modelContext: ModelContext
    var selectedTimeRange: ProgressTimeRange = .threeMonths
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
                    let e1rm = set.estimatedE1RM
                    if e1rm > (bestE1RMPerExercise[exerciseID] ?? 0) {
                        bestE1RMPerExercise[exerciseID] = e1rm
                    }
                }
            }
        }

        return bestE1RMPerExercise.values.reduce(0, +)
    }

    // MARK: - Activity (workouts & sets — not tonnage)

    /// Completed sessions in the selected range.
    var workoutCount: Int {
        fetchCompletedSessions().count
    }

    /// Non-warmup sets logged in the selected range.
    var workingSetCount: Int {
        allWorkingSets().count
    }

    /// Workouts in the equivalent previous window (nil for All).
    var previousWorkoutCount: Int? {
        guard let start = selectedTimeRange.startDate,
              let prevStart = selectedTimeRange.previousStartDate else { return nil }
        return fetchAllCompletedSessions()
            .filter { $0.date >= prevStart && $0.date < start }
            .count
    }

    /// Delta workouts vs previous window (nil if no baseline).
    var workoutCountDelta: Int? {
        guard let prev = previousWorkoutCount else { return nil }
        return workoutCount - prev
    }

    /// Completed workouts per calendar bucket (day/week/month) for the activity chart.
    var sessionChartData: [ChartDataPoint] {
        let cal = Calendar.current
        var buckets: [Date: Double] = [:]
        for session in fetchCompletedSessions() {
            guard let bucket = cal.dateInterval(of: selectedTimeRange.bucketUnit, for: session.date)?.start
            else { continue }
            buckets[bucket, default: 0] += 1
        }
        return buckets
            .map { ChartDataPoint(date: $0.key, value: $0.value) }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Lift Progression

    struct LiftProgress: Identifiable {
        let id: UUID              // exercise id
        let exercise: Exercise
        let topWeight: Double     // best non-warmup weight within range
        let allTimeBest: Double   // best non-warmup weight ever
        let deltaInRange: Double? // topWeight − best before range start (nil without baseline)
        let hasPRInRange: Bool    // range-best e1RM ties/beats all-time e1RM
    }

    /// One row per exercise with any activity in range, grouped by day type at the call site.
    func liftProgression() -> [LiftProgress] {
        let rangeStart = selectedTimeRange.startDate
        return allExercises().compactMap { exercise in
            let completed = exercise.recordsArray.filter { $0.session?.isCompleted == true }
            let allSets = completed.flatMap { $0.setsArray.filter { !$0.isWarmup } }
            guard !allSets.isEmpty else { return nil }

            func inRange(_ record: ExerciseRecord) -> Bool {
                guard let start = rangeStart else { return true }
                return (record.session?.date ?? .distantPast) >= start
            }

            let rangeSets = completed.filter(inRange).flatMap { $0.setsArray.filter { !$0.isWarmup } }
            guard let topWeight = rangeSets.map({ $0.effectiveLoadLbs() }).max() else { return nil }

            let allTimeBest = allSets.map { $0.effectiveLoadLbs() }.max() ?? 0

            let beforeSets = completed
                .filter { !inRange($0) }
                .flatMap { $0.setsArray.filter { !$0.isWarmup } }
            let baseline = beforeSets.map { $0.effectiveLoadLbs() }.max()
            let delta = baseline.map { topWeight - $0 }

            let rangeBestE1RM = rangeSets.map(\.estimatedE1RM).max() ?? 0
            let allTimeE1RM = allSets.map(\.estimatedE1RM).max() ?? 0

            return LiftProgress(
                id: exercise.id,
                exercise: exercise,
                topWeight: topWeight,
                allTimeBest: allTimeBest,
                deltaInRange: delta,
                hasPRInRange: rangeBestE1RM > 0 && rangeBestE1RM >= allTimeE1RM
            )
        }
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
                    let sessionBestE1RM = sets.map(\.estimatedE1RM).max() ?? 0
                    let sessionBestWeight = sets.map { $0.effectiveLoadLbs() }.max() ?? 0

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
                    let best = sets.map(\.estimatedE1RM).max() ?? 0
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
                    let best = sets.map { $0.effectiveLoadLbs() }.max() ?? 0
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

    // MARK: - Monthly overload (calendar month vs prior month)

    /// Best working set this calendar month vs last, combined across Strength
    /// and Endurance. Warm-ups excluded. Independent of `selectedTimeRange`.
    var monthlyOverload: MonthlyOverload.Review {
        monthlyOverload(now: .now, calendar: .current)
    }

    func monthlyOverload(now: Date, calendar: Calendar) -> MonthlyOverload.Review {
        let inputs = fetchAllCompletedSessions().map(Self.sessionInput(from:))
        return MonthlyOverload.review(
            sessions: inputs,
            now: now,
            calendar: calendar,
            dayOrder: DayTypeRegistry.shared.exerciseHomeDays.map(\.rawValue)
        )
    }

    private static func sessionInput(from session: WorkoutSession) -> MonthlyOverload.SessionInput {
        MonthlyOverload.SessionInput(
            date: session.date,
            lifts: session.exerciseRecordsArray.compactMap { record in
                guard !record.isDeleted, let exercise = record.exercise else { return nil }
                return MonthlyOverload.LiftInput(
                    exerciseID: exercise.id,
                    exerciseName: exercise.name,
                    dayTypeName: exercise.dayTypeNames.first ?? MonthlyOverload.unassignedDayName,
                    sortOrder: exercise.sortIndex(for: exercise.day),
                    sets: record.setsArray.map {
                        MonthlyOverload.SetInput(
                            weightLbs: $0.effectiveLoadLbs(),
                            reps: $0.reps,
                            isWarmup: $0.isWarmup
                        )
                    }
                )
            }
        )
    }

    // MARK: - Muscle group attention (working-set counts)

    /// How many working sets hit each primary muscle group in range (not tonnage).
    var muscleGroupSetCounts: [MuscleGroupSetCount] {
        var counts: [String: Int] = [:]
        for tuple in allWorkingSets() {
            let group = tuple.record.exercise?.primaryMuscleGroup ?? "Other"
            guard !group.isEmpty else { continue }
            counts[group, default: 0] += 1
        }
        return counts
            .map { MuscleGroupSetCount(muscleGroup: $0.key, setCount: $0.value) }
            .sorted { $0.setCount > $1.setCount }
    }

    // MARK: - Mode Split (by set count)

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

        var setsByMode: [TrainingMode: Double] = [:]
        for tuple in sets {
            setsByMode[tuple.record.trainingMode, default: 0] += 1
        }

        let total = setsByMode.values.reduce(0, +)
        guard total > 0 else { return [] }

        return TrainingMode.allCases.compactMap { mode in
            let value = setsByMode[mode] ?? 0
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
        return DayTypeRegistry.shared.exerciseHomeDays.compactMap { dayType in
            let exercises = all.filter { $0.belongs(to: dayType) }
            return exercises.isEmpty ? nil : (dayType, exercises)
        }
    }
}
