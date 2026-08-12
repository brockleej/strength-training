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
    /// Default chart: estimated 1RM (strength over time). Top weight is optional view.
    var chartMetric: ChartMetric = .e1RM

    enum ChartMetric: String, CaseIterable, Identifiable {
        case e1RM = "e1RM"
        case topWeight = "Top weight"
        var id: String { rawValue }

        var chartValueLabel: String {
            switch self {
            case .e1RM: return "e1RM"
            case .topWeight: return "Top weight"
            }
        }

        var caption: String {
            switch self {
            case .e1RM:
                return "Best estimated 1-rep max each session (from working sets). PR marks a new all-time high."
            case .topWeight:
                return "Heaviest working-set load each session. PR marks a new all-time top weight."
            }
        }
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

    // MARK: - Primary progress line (default e1RM)

    /// Points for the main chart from `chartMetric` (range-filtered; PRs from all-time running max).
    var primaryTrendData: [AnnotatedChartDataPoint] {
        switch chartMetric {
        case .e1RM: return e1rmTrendData
        case .topWeight: return topWeightTrendData
        }
    }

    // MARK: - Estimated 1RM Trend with PR annotations

    var e1rmTrendData: [AnnotatedChartDataPoint] {
        trendSeries { sets in
            sets.map(\.estimatedE1RM).max()
        }
    }

    /// Heaviest effective load per session; PR = new all-time top weight.
    var topWeightTrendData: [AnnotatedChartDataPoint] {
        trendSeries { sets in
            sets.map { $0.effectiveLoadLbs() }.max()
        }
    }

    /// Chronological sessions → value; running max over all time marks PRs; filter to selected range for display.
    private func trendSeries(
        value: ([SetRecord]) -> Double?
    ) -> [AnnotatedChartDataPoint] {
        var runningMax: Double = 0
        let allRecords = exercise.recordsArray
            .filter { $0.session?.isCompleted == true }
            .sorted { ($0.session?.date ?? .distantPast) < ($1.session?.date ?? .distantPast) }
        let startDate = selectedTimeRange.startDate
        var result: [AnnotatedChartDataPoint] = []
        for record in allRecords {
            guard let date = record.session?.date else { continue }
            let sets = workingSets(record)
            guard let sessionValue = value(sets), sessionValue > 0 else { continue }
            let isPR = sessionValue > runningMax + 0.05
            if isPR { runningMax = sessionValue }
            if let start = startDate, date < start { continue }
            result.append(AnnotatedChartDataPoint(date: date, value: sessionValue, isPR: isPR))
        }
        return result
    }

    // MARK: - Summary Stats

    var allTimeE1RM: Double? {
        let allSets = exercise.recordsArray
            .filter { $0.session?.isCompleted == true }
            .flatMap { $0.setsArray.filter { !$0.isWarmup } }

        let best = allSets.map(\.estimatedE1RM).max()
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

    /// The set holding the all-time best e1RM, with its session date (effective load).
    var personalBestSet: (weight: Double, reps: Int, date: Date)? {
        var best: (weight: Double, reps: Int, date: Date)?
        var bestE1RM: Double = 0
        for record in exercise.recordsArray where record.session?.isCompleted == true {
            guard let date = record.session?.date else { continue }
            for set in record.setsArray where !set.isWarmup {
                let e1rm = set.estimatedE1RM
                if e1rm > bestE1RM {
                    bestE1RM = e1rm
                    best = (set.effectiveLoadLbs(), set.reps, date)
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
            guard let top = sets.max(by: { $0.estimatedE1RM < $1.estimatedE1RM }) else { return nil }
            return (record.id, date, sets.count, top.effectiveLoadLbs(), top.reps, prDates.contains(date))
        }
    }
}
