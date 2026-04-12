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
    var id: UUID = UUID()
    var setNumber: Int = 0
    var weightLbs: Double = 0
    var reps: Int = 0
    var isWarmup: Bool = false
    var completedAt: Date = Date.now

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
