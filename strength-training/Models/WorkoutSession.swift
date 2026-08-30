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
    /// Optional, but CloudKit requires an explicit default (`nil` is fine).
    var healthKitWorkoutUUID: UUID? = nil
    /// Optional, but CloudKit requires an explicit default (`nil` is fine).
    var effortRating: Int? = nil
    /// Wall-clock session length in seconds. 0 = unknown (infer from set timestamps).
    var durationSeconds: Double = 0
    /// Session filter: "A", "B", or "" (All). Drives which labeled exercises appear.
    var rotationTrack: String = RotationTrack.a.rawValue
    /// Library exercises hidden from this session only (comma-separated UUIDs).
    var suppressedExerciseIDsRaw: String = ""
    /// "" / "planned" / "skipped". Planned days are imported targets, not trained work.
    var planState: String = ""
    /// Optional block this session was imported with. CloudKit requires a default.
    var trainingBlock: TrainingBlock? = nil

    @Relationship(deleteRule: .cascade, inverse: \ExerciseRecord.session)
    var exerciseRecords: [ExerciseRecord]?

    var exerciseRecordsArray: [ExerciseRecord] { exerciseRecords ?? [] }

    /// Resolved day-type value for UI comparisons and styling.
    var day: DayType { DayType(rawValue: dayType) }

    var track: RotationTrack {
        get { RotationTrack(storage: rotationTrack) }
        set { rotationTrack = newValue.rawValue }
    }

    var planStatus: SessionPlanState {
        get { SessionPlanState(storage: planState) }
        set { planState = newValue.rawValue }
    }

    /// True when this row is an imported plan that has not been started.
    var isPlanned: Bool { planStatus == .planned }

    /// True when a missed plan expired without being logged.
    var isSkippedPlan: Bool { planStatus == .skipped }

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
        self.planState = ""
        self.exerciseRecords = []
    }
}
