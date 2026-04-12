//
//  Exercise.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import Foundation
import SwiftData

@Model
final class Exercise {
    var id: UUID = UUID()
    var name: String = ""
    var dayType: DayType = DayType.arms
    var muscleGroup: String = ""
    var sortOrder: Int = 0
    var isCustom: Bool = false
    var notes: String = ""

    @Relationship(deleteRule: .cascade, inverse: \ExerciseRecord.exercise)
    var records: [ExerciseRecord]?

    var recordsArray: [ExerciseRecord] { records ?? [] }

    init(
        name: String,
        dayType: DayType,
        muscleGroup: String = "",
        sortOrder: Int = 0,
        isCustom: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.dayType = dayType
        self.muscleGroup = muscleGroup
        self.sortOrder = sortOrder
        self.isCustom = isCustom
        self.notes = ""
        self.records = []
    }
}
