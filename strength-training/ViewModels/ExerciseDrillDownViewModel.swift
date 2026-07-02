//
//  ExerciseDrillDownViewModel.swift
//  strength-training
//

import SwiftUI
import SwiftData

@Observable
final class ExerciseDrillDownViewModel {
    var modelContext: ModelContext
    let exercise: Exercise
    var selectedTimeRange: ProgressTimeRange = .threeMonths
    var topSetMetric: TopSetMetric = .weight

    enum TopSetMetric: String, CaseIterable, Identifiable {
        case weight = "Weight"
        case reps = "Reps"
        var id: String { rawValue }
    }

    init(modelContext: ModelContext, exercise: Exercise) {
        self.modelContext = modelContext
        self.exercise = exercise
    }

    // MARK: - Data Fetching

    private func filteredRecords() -> [ExerciseRecord] {
        let startDate = selectedTimeRange.startDate
        return exercise.recordsArray
            .filter { record in
                guard record.session?.isCompleted == true else { return false }
                if let start = startDate, let date = record.session?.date {
                    return date >= start
                }
                return true
            }
            .sorted { ($0.session?.date ?? .distantPast) < ($1.session?.date ?? .distantPast) }
    }

    private func workingSets(_ record: ExerciseRecord) -> [SetRecord] {
        record.setsArray.filter { !$0.isWarmup }
    }

    // MARK: - Top Set Trend

    var topSetTrendData: [ModeChartDataPoint] {
        filteredRecords().compactMap { record in
            guard let date = record.session?.date else { return nil }
            let sets = workingSets(record)
            guard !sets.isEmpty else { return nil }

            let value: Double
            switch topSetMetric {
            case .weight:
                value = sets.map(\.weightLbs).max() ?? 0
            case .reps:
                let bestSet = sets.max(by: { $0.weightLbs < $1.weightLbs })
                value = Double(bestSet?.reps ?? 0)
            }

            return ModeChartDataPoint(date: date, value: value, mode: record.trainingMode)
        }
    }

    // MARK: - Estimated 1RM Trend with PR annotations (2B)

    var e1rmTrendData: [AnnotatedChartDataPoint] {
        var runningMax: Double = 0

        // Include ALL records for PR detection, not just filtered ones
        let allRecords = exercise.recordsArray
            .filter { $0.session?.isCompleted == true }
            .sorted { ($0.session?.date ?? .distantPast) < ($1.session?.date ?? .distantPast) }

        let startDate = selectedTimeRange.startDate

        var result: [AnnotatedChartDataPoint] = []
        for record in allRecords {
            guard let date = record.session?.date else { continue }
            let sets = workingSets(record)
            guard let bestE1RM = sets.map({ E1RM.estimate(weightLbs: $0.weightLbs, reps: $0.reps) }).max() else {
                continue
            }

            let isPR = bestE1RM > runningMax
            if isPR { runningMax = bestE1RM }

            // Only include in display if within the selected time range
            if let start = startDate, date < start { continue }
            result.append(AnnotatedChartDataPoint(date: date, value: bestE1RM, isPR: isPR))
        }

        return result
    }

    // MARK: - Summary Stats

    var allTimeE1RM: Double? {
        let allSets = exercise.recordsArray
            .filter { $0.session?.isCompleted == true }
            .flatMap { $0.setsArray.filter { !$0.isWarmup } }

        let best = allSets.map { E1RM.estimate(weightLbs: $0.weightLbs, reps: $0.reps) }.max()
        return best
    }

    var totalSessions: Int {
        exercise.recordsArray
            .filter { $0.session?.isCompleted == true }
            .count
    }

    var lastSessionDate: Date? {
        exercise.recordsArray
            .compactMap { $0.session?.date }
            .max()
    }

    // MARK: - Top Set Bars (drill-down chart)

    /// Top-set bars (capped to the 20 most recent in range). PR flag = that
    /// session set a new all-time running-max e1RM (reuses e1rmTrendData's rule).
    var topSetBars: [AnnotatedChartDataPoint] {
        let prDates = Set(e1rmTrendData.filter(\.isPR).map(\.date))
        return topSetTrendData.suffix(20).map { point in
            AnnotatedChartDataPoint(date: point.date, value: point.value, isPR: prDates.contains(point.date))
        }
    }

    /// The set holding the all-time best e1RM, with its session date.
    var personalBestSet: (weight: Double, reps: Int, date: Date)? {
        var best: (weight: Double, reps: Int, date: Date)?
        var bestE1RM: Double = 0
        for record in exercise.recordsArray where record.session?.isCompleted == true {
            guard let date = record.session?.date else { continue }
            for set in record.setsArray where !set.isWarmup {
                let e1rm = E1RM.estimate(weightLbs: set.weightLbs, reps: set.reps)
                if e1rm > bestE1RM {
                    bestE1RM = e1rm
                    best = (set.weightLbs, set.reps, date)
                }
            }
        }
        return best
    }

    /// Last 10 sessions in range, newest first: (date, setCount, top set, isPR).
    var recentSessions: [(id: UUID, date: Date, sets: Int, topWeight: Double, topReps: Int, isPR: Bool)] {
        let prDates = Set(e1rmTrendData.filter(\.isPR).map(\.date))
        return filteredRecords().suffix(10).reversed().compactMap { record in
            guard let date = record.session?.date else { return nil }
            let sets = workingSets(record)
            guard let top = sets.max(by: {
                E1RM.estimate(weightLbs: $0.weightLbs, reps: $0.reps) < E1RM.estimate(weightLbs: $1.weightLbs, reps: $1.reps)
            }) else { return nil }
            return (record.id, date, sets.count, top.weightLbs, top.reps, prDates.contains(date))
        }
    }
}
