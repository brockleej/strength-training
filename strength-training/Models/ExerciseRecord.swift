//
//  ExerciseRecord.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import Foundation
import SwiftData

@Model
final class ExerciseRecord {
    var id: UUID = UUID()
    var trainingMode: TrainingMode = TrainingMode.highWeightLowReps
    var sortOrder: Int = 0
    var isCompleted: Bool = false
    var notes: String = ""

    var exercise: Exercise?
    var session: WorkoutSession?

    @Relationship(deleteRule: .cascade, inverse: \SetRecord.exerciseRecord)
    var sets: [SetRecord]?

    var setsArray: [SetRecord] { sets ?? [] }

    init(trainingMode: TrainingMode, sortOrder: Int = 0) {
        self.id = UUID()
        self.trainingMode = trainingMode
        self.sortOrder = sortOrder
        self.isCompleted = false
        self.notes = ""
        self.sets = []
    }
}
