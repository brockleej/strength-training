//
//  ProgressDataTypes.swift
//  strength-training
//

import Foundation
import SwiftUI

// MARK: - Time Range

enum ProgressTimeRange: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case threeMonths = "3 mo"
    case year = "Year"
    case all = "All"

    var id: String { rawValue }

    /// Inclusive start of the period anchored to `now`. Returns nil for `.all`.
    func startDate(now: Date = .now, calendar: Calendar = .current) -> Date? {
        switch self {
        case .week:        return calendar.date(byAdding: .weekOfYear, value: -1, to: now)
        case .month:       return calendar.date(byAdding: .month, value: -1, to: now)
        case .threeMonths: return calendar.date(byAdding: .month, value: -3, to: now)
        case .year:        return calendar.date(byAdding: .year, value: -1, to: now)
        case .all:         return nil
        }
    }

    /// Convenience for legacy call sites that read the property directly.
    var startDate: Date? { startDate() }
}

// MARK: - Chart Data Points

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct ModeChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let mode: TrainingMode
}

struct AnnotatedChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let isPR: Bool
}

// MARK: - Dashboard Data

struct MuscleGroupVolume: Identifiable {
    let id = UUID()
    let muscleGroup: String
    let volume: Double
}

struct ModeSplitData: Identifiable {
    let id = UUID()
    let mode: TrainingMode
    let value: Double
    let percentage: Double
}

struct PersonalRecord: Identifiable {
    let id = UUID()
    let exerciseName: String
    let type: PRType
    let value: Double
    let date: Date

    enum PRType: String {
        case estimatedOneRM = "Best e1RM"
        case topSetWeight = "Top Set"
        case mostRepsAtWeight = "Most Reps"
    }
}

// MARK: - Trend

enum TrendDirection {
    case up, down, flat, insufficientData

    var systemImage: String {
        switch self {
        case .up:   "arrow.up.right"
        case .down: "arrow.down.right"
        case .flat: "arrow.right"
        case .insufficientData: "minus"
        }
    }

    var color: Color {
        switch self {
        case .up:   .green
        case .down: .red
        case .flat: .secondary
        case .insufficientData: .secondary
        }
    }
}
