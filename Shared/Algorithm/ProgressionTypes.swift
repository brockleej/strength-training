//
//  ProgressionTypes.swift
//  strength-training
//

import Foundation

// How aggressively to suggest weight increases.
// Stored in UserDefaults as its rawValue String.
enum ProgressionAggressiveness: String, CaseIterable, Identifiable {
    case moderate     = "Moderate"      // 2 consistent sessions required (default)
    case conservative = "Conservative"  // 3 consistent sessions required

    var id: String { rawValue }

    // Number of consecutive sessions that must hit the threshold
    // before a weight increase is recommended.
    var consistencyThreshold: Int {
        switch self {
        case .moderate: 2
        case .conservative: 3
        }
    }

    /// The full parameter set this aggressiveness level represents.
    /// Used by the iOS-facing wrapper to call into the pure algorithm.
    var parameters: ProgressionParameters {
        switch self {
        case .moderate: .productionModerate
        case .conservative: .productionConservative
        }
    }
}

// Rolling average of the best set per session across the last N sessions.
struct RecentAverage {
    let weight: Double
    let reps: Int
    let sessionCount: Int  // how many sessions were actually available
}

// The recommended target for the next set of this exercise.
struct ProgressionSuggestion {
    let targetWeight: Double  // already snapped to nearest 5 lbs
    let targetReps: Int
    let basis: Basis

    enum Basis {
        case notEnoughData  // < 2 sessions — show raw best set, no "Target:" label
        case consistent     // hitting threshold → weight bump suggested (show ↑)
        case improving      // building toward threshold → rep bump suggested
    }
}
