//
//  ProgressionParameters.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-05-03.
//

import Foundation

/// All the tunable knobs of the progression algorithm, exposed as a single
/// value type so the algorithm can run with arbitrary parameter sets (the
/// simulator) and the iOS app can map its `ProgressionAggressiveness` enum
/// onto a concrete instance.
struct ProgressionParameters: Codable, Equatable {
    var averageWindow: Int            // production: 4
    var consistencyThreshold: Int     // production: 2 (moderate) or 3 (conservative)
    var strengthRepCap: Int           // production: 20
    var enduranceCeilingOffset: Int   // production: 20
    var weightIncrement: Double       // production: 5.0
    var repIncrement: Int             // production: 1

    /// Defaults matching the iOS app's `.moderate` aggressiveness setting.
    /// This is the comparison baseline for `comparisonStats.vsProduction`
    /// in exported config artifacts.
    static let productionModerate = ProgressionParameters(
        averageWindow: 4,
        consistencyThreshold: 2,
        strengthRepCap: 20,
        enduranceCeilingOffset: 20,
        weightIncrement: 5.0,
        repIncrement: 1
    )

    /// Defaults matching the iOS app's `.conservative` aggressiveness setting.
    static let productionConservative = ProgressionParameters(
        averageWindow: 4,
        consistencyThreshold: 3,
        strengthRepCap: 20,
        enduranceCeilingOffset: 20,
        weightIncrement: 5.0,
        repIncrement: 1
    )
}
