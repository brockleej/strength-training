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
    var id: UUID = UUID()
    var date: Date = Date.now
    /// Day-type name (e.g. "Arms", "Push"). Metadata lives in SplitDay / DayTypeRegistry.
    var dayType: String = DayType.arms.rawValue
    var notes: String = ""
    var isCompleted: Bool = false
    var healthKitWorkoutUUID: UUID?
    var effortRating: Int?
    /// Session filter: "A", "B", or "" (All). Drives which labeled exercises appear.
    var rotationTrack: String = RotationTrack.a.rawValue
    /// Library exercises hidden from this session only (comma-separated UUIDs).
    var suppressedExerciseIDsRaw: String = ""

    @Relationship(deleteRule: .cascade, inverse: \ExerciseRecord.session)
    var exerciseRecords: [ExerciseRecord]?

    var exerciseRecordsArray: [ExerciseRecord] { exerciseRecords ?? [] }

    /// Resolved day-type value for UI comparisons and styling.
    var day: DayType { DayType(rawValue: dayType) }

    var track: RotationTrack {
        get { RotationTrack(storage: rotationTrack) }
        set { rotationTrack = newValue.rawValue }
    }

    var suppressedExerciseIDs: Set<UUID> {
        get {
            Set(
                suppressedExerciseIDsRaw
                    .split(separator: ",")
                    .compactMap { UUID(uuidString: $0.trimmingCharacters(in: .whitespaces)) }
            )
        }
        set {
            suppressedExerciseIDsRaw = newValue.map(\.uuidString).sorted().joined(separator: ",")
        }
    }

    func suppressExercise(id: UUID) {
        var ids = suppressedExerciseIDs
        ids.insert(id)
        suppressedExerciseIDs = ids
    }

    func unsuppressExercise(id: UUID) {
        var ids = suppressedExerciseIDs
        ids.remove(id)
        suppressedExerciseIDs = ids
    }

    init(dayType: DayType, date: Date = .now, rotationTrack: RotationTrack = .a) {
        self.id = UUID()
        self.date = date
        self.dayType = dayType.rawValue
        self.notes = ""
        self.isCompleted = false
        self.rotationTrack = rotationTrack.rawValue
        self.suppressedExerciseIDsRaw = ""
        self.exerciseRecords = []
    }
}
