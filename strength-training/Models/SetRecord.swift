//
//  SetRecord.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import Foundation
import SwiftData

@Model
final class SetRecord {
    var id: UUID
    var setNumber: Int
    var weightLbs: Double
    var reps: Int
    var isWarmup: Bool
    var completedAt: Date

    var exerciseRecord: ExerciseRecord?

    init(setNumber: Int, weightLbs: Double, reps: Int, isWarmup: Bool = false) {
        self.id = UUID()
        self.setNumber = setNumber
        self.weightLbs = weightLbs
        self.reps = reps
        self.isWarmup = isWarmup
        self.completedAt = .now
    }
}
