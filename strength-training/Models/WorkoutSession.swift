//
//  WorkoutSession.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import Foundation
import SwiftData

@Model
final class WorkoutSession {
    var id: UUID
    var date: Date
    var dayType: DayType
    var notes: String
    var isCompleted: Bool
    var healthKitWorkoutUUID: UUID?
    var effortRating: Int?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseRecord.session)
    var exerciseRecords: [ExerciseRecord]

    init(dayType: DayType, date: Date = .now) {
        self.id = UUID()
        self.date = date
        self.dayType = dayType
        self.notes = ""
        self.isCompleted = false
        self.exerciseRecords = []
    }
}
