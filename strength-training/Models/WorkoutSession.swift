//
//  WorkoutSession.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import Foundation
import SwiftData

@Model
final class WorkoutSession: Identifiable {
    var id: UUID = UUID()
    var date: Date = Date.now
    var dayType: DayType = DayType.arms
    var notes: String = ""
    var isCompleted: Bool = false
    var healthKitWorkoutUUID: UUID?
    var effortRating: Int?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseRecord.session)
    var exerciseRecords: [ExerciseRecord]?

    var exerciseRecordsArray: [ExerciseRecord] { exerciseRecords ?? [] }

    init(dayType: DayType, date: Date = .now) {
        self.id = UUID()
        self.date = date
        self.dayType = dayType
        self.notes = ""
        self.isCompleted = false
        self.exerciseRecords = []
    }
}
