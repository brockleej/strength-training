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

    /// False until the first snapshot is ready — Progress tab shows a spinner
    /// so the tab switch is not blocked by a full-history walk.
    private(set) var isReady = false

    enum ModeSplitPeriod: String, CaseIterable {
        case week = "Week"
        case month = "Month"
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Snapshot (filled by refresh)

    private(set) var strengthScore: Double = 0
    private(set) var strengthScoreTrend: TrendDirection = .insufficientData
    private(set) var strengthScoreDelta: Double = 0
    private(set) var workoutCount: Int = 0
    private(set) var workingSetCount: Int = 0
    private(set) var workoutCountDelta: Int?
    private(set) var sessionChartData: [ChartDataPoint] = []
    private(set) var prsThisMonth: [PersonalRecord] = []
    private(set) var monthlyOverload = MonthlyOverload.Review(
        thisMonthLabel: "",
        lastMonthLabel: "",
        thisMonthWorkoutCount: 0,
        lastMonthWorkoutCount: 0,
        groups: []
    )
    private(set) var muscleGroupSetCounts: [MuscleGroupSetCount] = []
    private(set) var modeSplit: [ModeSplitData] = []
    private(set) var exercises: [Exercise] = []

    private var lastSessionCount = -1
    private var lastRange: ProgressTimeRange?
    private var lastModePeriod: ModeSplitPeriod?

    /// One SwiftData pass. Cheap no-op if session count and filters match.
    @MainActor
    func refresh() async {
        await Task.yield()
        guard !Task.isCancelled else { return }

        let count = (try? modelContext.fetchCount(
            FetchDescriptor<WorkoutSession>(
                predicate: #Predicate<WorkoutSession> { $0.isCompleted == true }
            )
        )) ?? 0
        if isReady,
           count == lastSessionCount,
           lastRange == selectedTimeRange,
           lastModePeriod == modeSplitPeriod {
            return
        }

        let built = buildSnapshot(sessionCount: count)
        guard !Task.isCancelled else { return }
        apply(built)
    }

    func allExercises() -> [Exercise] { exercises }

    // MARK: - Build

    private struct Snapshot {
        var sessionCount: Int
        var range: ProgressTimeRange
        var modePeriod: ModeSplitPeriod
        var strengthScore: Double
        var strengthScoreTrend: TrendDirection
        var strengthScoreDelta: Double
        var workoutCount: Int
        var workingSetCount: Int
        var workoutCountDelta: Int?
        var sessionChartData: [ChartDataPoint]
        var prsThisMonth: [PersonalRecord]
        var monthlyOverload: MonthlyOverload.Review
        var muscleGroupSetCounts: [MuscleGroupSetCount]
        var modeSplit: [ModeSplitData]
        var exercises: [Exercise]
    }

    private struct WalkSet {
        let weight: Double
        let reps: Int
        let isWarmup: Bool
        let isEachSide: Bool
        let e1rm: Double
    }

    private struct WalkLift {
        let exerciseID: UUID
        let exerciseName: String
        let dayTypeName: String
        let sortOrder: Int
        let muscle: String
        let mode: TrainingMode
        let sets: [WalkSet]
    }

    private struct WalkSession {
        let date: Date
        let lifts: [WalkLift]
    }

    @MainActor
    private func buildSnapshot(sessionCount: Int) -> Snapshot {
        let now = Date.now
        let calendar = Calendar.current
        let rangeStart = selectedTimeRange.startDate
        let previousStart = selectedTimeRange.previousStartDate
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start
        let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: now)

        let modePeriodStart: Date? = {
            switch modeSplitPeriod {
            case .week: calendar.dateInterval(of: .weekOfYear, for: now)?.start
            case .month: calendar.dateInterval(of: .month, for: now)?.start
            }
        }()

        let sessionDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.isCompleted == true },
            sortBy: [SortDescriptor(\WorkoutSession.date, order: .forward)]
        )
        let storedSessions = (try? modelContext.fetch(sessionDescriptor)) ?? []
        let storedExercises = (try? modelContext.fetch(
            FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\Exercise.sortOrder)])
        )) ?? []

        var walked: [WalkSession] = []
        walked.reserveCapacity(storedSessions.count)
        var overloadInputs: [MonthlyOverload.SessionInput] = []
        overloadInputs.reserveCapacity(storedSessions.count)

        for session in storedSessions {
            var lifts: [WalkLift] = []
            var overloadLifts: [MonthlyOverload.LiftInput] = []
            for record in session.exerciseRecordsArray {
                guard !record.isDeleted, let exercise = record.exercise else { continue }
                var sets: [WalkSet] = []
                var overloadSets: [MonthlyOverload.SetInput] = []
                for set in record.setsArray {
                    let weight = set.effectiveLoadLbs()
                    sets.append(
                        WalkSet(
                            weight: weight,
                            reps: set.reps,
                            isWarmup: set.isWarmup,
                            isEachSide: set.isEachSide,
                            e1rm: set.estimatedE1RM
                        )
                    )
                    overloadSets.append(
                        MonthlyOverload.SetInput(
                            weightLbs: weight,
                            reps: set.reps,
                            isWarmup: set.isWarmup
                        )
                    )
                }
                lifts.append(
                    WalkLift(
                        exerciseID: exercise.id,
                        exerciseName: exercise.name,
                        dayTypeName: exercise.dayTypeNames.first ?? MonthlyOverload.unassignedDayName,
                        sortOrder: exercise.sortIndex(for: exercise.day),
                        muscle: exercise.primaryMuscleGroup,
                        mode: record.trainingMode,
                        sets: sets
                    )
                )
                overloadLifts.append(
                    MonthlyOverload.LiftInput(
                        exerciseID: exercise.id,
                        exerciseName: exercise.name,
                        dayTypeName: exercise.dayTypeNames.first ?? MonthlyOverload.unassignedDayName,
                        sortOrder: exercise.sortIndex(for: exercise.day),
                        sets: overloadSets
                    )
                )
            }
            walked.append(WalkSession(date: session.date, lifts: lifts))
            overloadInputs.append(MonthlyOverload.SessionInput(date: session.date, lifts: overloadLifts))
        }

        func inRange(_ date: Date) -> Bool {
            guard let start = rangeStart else { return true }
            return date >= start
        }

        var rangeBestByMuscle: [String: Double] = [:]
        var allTimeBestByMuscle: [String: Double] = [:]
        var pastBestByMuscle: [String: Double] = [:]
        var workoutsInRange = 0
        var previousWorkouts = 0
        var workingSetsInRange = 0
        var muscleCounts: [String: Int] = [:]
        var modeCounts: [TrainingMode: Double] = [:]
        var buckets: [Date: Double] = [:]

        var hadPastSessions = false
        for session in walked {
            if let cutoff = oneMonthAgo, session.date <= cutoff {
                hadPastSessions = true
            }
            for lift in session.lifts {
                for set in lift.sets where !set.isWarmup {
                    let scoreE1RM = StrengthScore.comparableE1RM(
                        weightLbs: set.weight,
                        reps: set.reps,
                        isEachSide: set.isEachSide
                    )
                    StrengthScore.absorb(e1rm: scoreE1RM, muscle: lift.muscle, into: &allTimeBestByMuscle)
                    if let cutoff = oneMonthAgo, session.date <= cutoff {
                        StrengthScore.absorb(e1rm: scoreE1RM, muscle: lift.muscle, into: &pastBestByMuscle)
                    }
                    if inRange(session.date) {
                        workingSetsInRange += 1
                        StrengthScore.absorb(e1rm: scoreE1RM, muscle: lift.muscle, into: &rangeBestByMuscle)
                        let group = StrengthScore.slot(for: lift.muscle)
                        muscleCounts[group, default: 0] += 1
                        if let start = modePeriodStart {
                            if session.date >= start {
                                modeCounts[lift.mode, default: 0] += 1
                            }
                        } else {
                            modeCounts[lift.mode, default: 0] += 1
                        }
                    }
                }
            }

            if inRange(session.date) {
                workoutsInRange += 1
                if let bucket = calendar.dateInterval(of: selectedTimeRange.bucketUnit, for: session.date)?.start {
                    buckets[bucket, default: 0] += 1
                }
            } else if let start = rangeStart, let prev = previousStart,
                      session.date >= prev, session.date < start {
                previousWorkouts += 1
            }
        }

        let score = StrengthScore.total(rangeBestByMuscle)
        let currentAll = StrengthScore.total(allTimeBestByMuscle)
        let pastAll = StrengthScore.total(pastBestByMuscle)
        let trend: TrendDirection
        if !hadPastSessions {
            trend = .insufficientData
        } else if currentAll > pastAll * 1.01 {
            trend = .up
        } else if currentAll < pastAll * 0.99 {
            trend = .down
        } else {
            trend = .flat
        }

        let chart = buckets
            .map { ChartDataPoint(date: $0.key, value: $0.value) }
            .sorted { $0.date < $1.date }

        let muscles = muscleCounts
            .map { MuscleGroupSetCount(muscleGroup: $0.key, setCount: $0.value) }
            .sorted { $0.setCount > $1.setCount }

        let modeTotal = modeCounts.values.reduce(0, +)
        let modes: [ModeSplitData]
        if modeTotal > 0 {
            modes = TrainingMode.allCases.compactMap { mode in
                let value = modeCounts[mode] ?? 0
                guard value > 0 else { return nil }
                return ModeSplitData(mode: mode, value: value, percentage: value / modeTotal)
            }
        } else {
            modes = []
        }

        let delta: Int? = selectedTimeRange.startDate == nil ? nil : workoutsInRange - previousWorkouts

        return Snapshot(
            sessionCount: sessionCount,
            range: selectedTimeRange,
            modePeriod: modeSplitPeriod,
            strengthScore: score,
            strengthScoreTrend: trend,
            strengthScoreDelta: currentAll - pastAll,
            workoutCount: workoutsInRange,
            workingSetCount: workingSetsInRange,
            workoutCountDelta: delta,
            sessionChartData: chart,
            prsThisMonth: prsThisMonth(from: walked, monthStart: monthStart),
            monthlyOverload: MonthlyOverload.review(
                sessions: overloadInputs,
                now: now,
                calendar: calendar,
                dayOrder: DayTypeRegistry.shared.exerciseHomeDays.map(\.rawValue)
            ),
            muscleGroupSetCounts: muscles,
            modeSplit: modes,
            exercises: storedExercises
        )
    }

    private func apply(_ snapshot: Snapshot) {
        lastSessionCount = snapshot.sessionCount
        lastRange = snapshot.range
        lastModePeriod = snapshot.modePeriod
        strengthScore = snapshot.strengthScore
        strengthScoreTrend = snapshot.strengthScoreTrend
        strengthScoreDelta = snapshot.strengthScoreDelta
        workoutCount = snapshot.workoutCount
        workingSetCount = snapshot.workingSetCount
        workoutCountDelta = snapshot.workoutCountDelta
        sessionChartData = snapshot.sessionChartData
        prsThisMonth = snapshot.prsThisMonth
        monthlyOverload = snapshot.monthlyOverload
        muscleGroupSetCounts = snapshot.muscleGroupSetCounts
        modeSplit = snapshot.modeSplit
        exercises = snapshot.exercises
        isReady = true
    }

    private func prsThisMonth(from sessions: [WalkSession], monthStart: Date?) -> [PersonalRecord] {
        guard let monthStart else { return [] }

        struct Running {
            var bestE1RM: Double = 0
            var bestWeight: Double = 0
            var e1RMPR = false
            var weightPR = false
            var name = ""
            var monthRecords: [(e1rm: Double, weight: Double, date: Date)] = []
        }

        var byExercise: [UUID: Running] = [:]
        var prs: [PersonalRecord] = []

        for session in sessions {
            let isCurrentMonth = session.date >= monthStart
            for lift in session.lifts {
                var bestE1RM: Double = 0
                var bestWeight: Double = 0
                for set in lift.sets where !set.isWarmup {
                    if set.e1rm > bestE1RM { bestE1RM = set.e1rm }
                    if set.weight > bestWeight { bestWeight = set.weight }
                }
                guard bestE1RM > 0 || bestWeight > 0 else { continue }

                var state = byExercise[lift.exerciseID] ?? Running()
                state.name = lift.exerciseName
                if isCurrentMonth {
                    state.monthRecords.append((bestE1RM, bestWeight, session.date))
                }

                if bestE1RM > state.bestE1RM {
                    if isCurrentMonth && state.bestE1RM > 0 && !state.e1RMPR {
                        prs.append(PersonalRecord(
                            exerciseName: lift.exerciseName,
                            type: .estimatedOneRM,
                            value: bestE1RM,
                            date: session.date
                        ))
                        state.e1RMPR = true
                    }
                    state.bestE1RM = bestE1RM
                }
                if bestWeight > state.bestWeight {
                    if isCurrentMonth && state.bestWeight > 0 && !state.weightPR {
                        prs.append(PersonalRecord(
                            exerciseName: lift.exerciseName,
                            type: .topSetWeight,
                            value: bestWeight,
                            date: session.date
                        ))
                        state.weightPR = true
                    }
                    state.bestWeight = bestWeight
                }
                byExercise[lift.exerciseID] = state
            }
        }

        for (_, state) in byExercise {
            if !state.e1RMPR && state.monthRecords.count >= 2 {
                var monthBest: Double = 0
                for record in state.monthRecords {
                    if record.e1rm > monthBest && monthBest > 0 {
                        prs.append(PersonalRecord(
                            exerciseName: state.name,
                            type: .estimatedOneRM,
                            value: record.e1rm,
                            date: record.date
                        ))
                        break
                    }
                    if record.e1rm > monthBest { monthBest = record.e1rm }
                }
            }
            if !state.weightPR && state.monthRecords.count >= 2 {
                var monthBest: Double = 0
                for record in state.monthRecords {
                    if record.weight > monthBest && monthBest > 0 {
                        prs.append(PersonalRecord(
                            exerciseName: state.name,
                            type: .topSetWeight,
                            value: record.weight,
                            date: record.date
                        ))
                        break
                    }
                    if record.weight > monthBest { monthBest = record.weight }
                }
            }
        }

        return prs.sorted { $0.date > $1.date }
    }

    // MARK: - Lift Progression (drill-down helper; not on first paint)

    struct LiftProgress: Identifiable {
        let id: UUID
        let exercise: Exercise
        let topWeight: Double
        let allTimeBest: Double
        let deltaInRange: Double?
        let hasPRInRange: Bool
    }

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

            let rangeBestE1RM = rangeSets.map(\.estimatedE1RM).max() ?? 0
            let allTimeE1RM = allSets.map(\.estimatedE1RM).max() ?? 0

            return LiftProgress(
                id: exercise.id,
                exercise: exercise,
                topWeight: topWeight,
                allTimeBest: allTimeBest,
                deltaInRange: baseline.map { topWeight - $0 },
                hasPRInRange: rangeBestE1RM > 0 && rangeBestE1RM >= allTimeE1RM
            )
        }
    }

    func exercisesGroupedByDayType() -> [(DayType, [Exercise])] {
        let all = allExercises()
        return DayTypeRegistry.shared.exerciseHomeDays.compactMap { dayType in
            let exercises = all.filter { $0.belongs(to: dayType) }
            return exercises.isEmpty ? nil : (dayType, exercises)
        }
    }
}
