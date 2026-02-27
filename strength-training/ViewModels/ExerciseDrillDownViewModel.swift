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
    var selectedTimeRange: ProgressTimeRange = .twelveWeeks
    var topSetMetric: TopSetMetric = .e1RM

    enum TopSetMetric: String, CaseIterable, Identifiable {
        case weight = "Weight"
        case reps = "Reps"
        case e1RM = "Est. 1RM"
        var id: String { rawValue }
    }

    init(modelContext: ModelContext, exercise: Exercise) {
        self.modelContext = modelContext
        self.exercise = exercise
    }

    // MARK: - Data Fetching

    private func filteredRecords() -> [ExerciseRecord] {
        let startDate = selectedTimeRange.startDate
        return exercise.records
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
        record.sets.filter { !$0.isWarmup }
    }

    // MARK: - Top Set Trend (2A + 2D mode overlay)

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
            case .e1RM:
                value = sets.map { $0.weightLbs * (1.0 + Double($0.reps) / 30.0) }.max() ?? 0
            }

            return ModeChartDataPoint(date: date, value: value, mode: record.trainingMode)
        }
    }

    // MARK: - Estimated 1RM Trend with PR annotations (2B)

    var e1rmTrendData: [AnnotatedChartDataPoint] {
        var runningMax: Double = 0

        // Include ALL records for PR detection, not just filtered ones
        let allRecords = exercise.records
            .filter { $0.session?.isCompleted == true }
            .sorted { ($0.session?.date ?? .distantPast) < ($1.session?.date ?? .distantPast) }

        let startDate = selectedTimeRange.startDate

        var result: [AnnotatedChartDataPoint] = []
        for record in allRecords {
            guard let date = record.session?.date else { continue }
            let sets = workingSets(record)
            guard let bestE1RM = sets.map({ $0.weightLbs * (1.0 + Double($0.reps) / 30.0) }).max() else {
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

    // MARK: - Volume per Session (2C + 2D mode overlay)

    var volumePerSessionData: [ModeChartDataPoint] {
        filteredRecords().compactMap { record in
            guard let date = record.session?.date else { return nil }
            let volume = workingSets(record).reduce(0.0) { $0 + $1.weightLbs * Double($1.reps) }
            guard volume > 0 else { return nil }
            return ModeChartDataPoint(date: date, value: volume, mode: record.trainingMode)
        }
    }

    // MARK: - Summary Stats

    var allTimeE1RM: Double? {
        let allSets = exercise.records
            .filter { $0.session?.isCompleted == true }
            .flatMap { $0.sets.filter { !$0.isWarmup } }

        let best = allSets.map { $0.weightLbs * (1.0 + Double($0.reps) / 30.0) }.max()
        return best
    }

    var totalSessions: Int {
        exercise.records
            .filter { $0.session?.isCompleted == true }
            .count
    }

    var lastSessionDate: Date? {
        exercise.records
            .compactMap { $0.session?.date }
            .max()
    }
}
