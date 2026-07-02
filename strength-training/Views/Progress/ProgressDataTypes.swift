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

    /// Days the window spans; nil = unbounded.
    var dayCount: Int? {
        switch self {
        case .week: 7
        case .month: 30
        case .threeMonths: 90
        case .year: 365
        case .all: nil
        }
    }

    var startDate: Date? {
        dayCount.flatMap { Calendar.current.date(byAdding: .day, value: -$0, to: .now) }
    }

    /// Start of the equivalent window immediately before this one (for deltas).
    var previousStartDate: Date? {
        dayCount.flatMap { Calendar.current.date(byAdding: .day, value: -2 * $0, to: .now) }
    }

    /// Bucketing unit for the volume chart.
    var bucketUnit: Calendar.Component {
        switch self {
        case .week: .day
        case .month, .threeMonths: .weekOfYear
        case .year, .all: .month
        }
    }
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
