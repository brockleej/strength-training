//
//  AlgorithmInput.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-05-03.
//
//  Plain value types that the pure progression algorithm operates on.
//  Decoupled from SwiftData so the algorithm can be invoked from any
//  data source (production iOS app, simulator macOS app, tests).
//

import Foundation

/// A single set within an exercise record.
/// Mirrors the fields on `SetRecord` (the SwiftData model) that the
/// algorithm or downstream views care about.
struct SetSnapshot: Equatable {
    let weightLbs: Double
    let reps: Int
    let isWarmup: Bool
    let completedAt: Date
}

/// A single exercise's record within a completed workout session.
///
/// **Invariant:** snapshots represent *completed* records only. The adapter
/// that constructs these (whether from a SwiftData `Exercise.records`
/// relationship or from a JSON backup) must filter `session.isCompleted == true`
/// before constructing the snapshot. The algorithm assumes this invariant
/// and does not re-check.
///
/// Sets are stored as-logged. Progression picks best set among non-warmup
/// sets only (see `ProgressionService.bestSet`).
struct ExerciseRecordSnapshot: Equatable {
    let trainingMode: TrainingMode
    let sessionDate: Date
    let sets: [SetSnapshot]
}
