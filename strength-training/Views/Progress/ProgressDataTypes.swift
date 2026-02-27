//
//  ProgressDataTypes.swift
//  strength-training
//

import Foundation
import SwiftUI

// MARK: - Time Range

enum ProgressTimeRange: String, CaseIterable, Identifiable {
    case fourWeeks = "4W"
    case twelveWeeks = "12W"
    case oneYear = "1Y"
    case all = "All"

    var id: String { rawValue }

    var startDate: Date? {
        let calendar = Calendar.current
        switch self {
        case .fourWeeks:  return calendar.date(byAdding: .weekOfYear, value: -4, to: .now)
        case .twelveWeeks: return calendar.date(byAdding: .weekOfYear, value: -12, to: .now)
        case .oneYear:    return calendar.date(byAdding: .year, value: -1, to: .now)
        case .all:        return nil
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
