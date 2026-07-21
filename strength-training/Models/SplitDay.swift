//
//  SplitDay.swift
//  strength-training
//
//  User-configured training-day definition. The active set of SplitDay rows
//  is the user's split (bro, PPL, custom, …). Exercise / session rows store
//  the day *name* as a string; presentation metadata is looked up here.
//

import Foundation
import SwiftData

@Model
final class SplitDay {
    var id: UUID = UUID()
    var name: String = ""
    var systemImage: String = "dumbbell.fill"
    var subtitle: String = ""
    /// RGB packed as 0xRRGGBB (same as Color(hex:)).
    var colorHex: Int = 0xFF4D88
    /// When true (e.g. Full Body), sessions list every exercise home day.
    var includesAllExercises: Bool = false
    var sortOrder: Int = 0

    init(
        name: String,
        systemImage: String,
        subtitle: String = "",
        colorHex: UInt32,
        includesAllExercises: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.systemImage = systemImage
        self.subtitle = subtitle
        self.colorHex = Int(colorHex)
        self.includesAllExercises = includesAllExercises
        self.sortOrder = sortOrder
    }

    convenience init(definition: DayTypeDefinition) {
        self.init(
            name: definition.name,
            systemImage: definition.systemImage,
            subtitle: definition.subtitle,
            colorHex: definition.colorHex,
            includesAllExercises: definition.includesAllExercises,
            sortOrder: definition.sortOrder
        )
    }

    var definition: DayTypeDefinition {
        DayTypeDefinition(
            name: name,
            systemImage: systemImage,
            subtitle: subtitle,
            colorHex: UInt32(truncatingIfNeeded: colorHex),
            includesAllExercises: includesAllExercises,
            sortOrder: sortOrder
        )
    }

    var asDayType: DayType { DayType(rawValue: name) }
}
