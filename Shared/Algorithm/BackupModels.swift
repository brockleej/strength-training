//
//  BackupModels.swift
//  RockLog
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import Foundation

struct AppBackup: Codable {
    let version: Int
    let exportedAt: Date
    let exercises: [ExerciseBackup]
    let sessions: [WorkoutSessionBackup]
    /// Active Today split, in display order. Missing on backups made before this field.
    let splitDays: [SplitDayBackup]?
    /// Per-day exercise IDs in list order. Missing on backups made before this field.
    let dayPlans: [DayPlanBackup]?
    /// Planned programs. Missing on backups made before this field.
    /// Nil means the file did not know about blocks (leave the store's blocks alone).
    /// An empty array means the backup explicitly has none.
    let trainingBlocks: [TrainingBlockBackup]?
    /// Home measurements (weight, girths). Same nil-vs-empty rule as `trainingBlocks`:
    /// nil preserves rows already on the phone; an array replaces them.
    let bodyMetrics: [BodyMetricBackup]?

    init(
        version: Int,
        exportedAt: Date,
        exercises: [ExerciseBackup],
        sessions: [WorkoutSessionBackup],
        splitDays: [SplitDayBackup]? = nil,
        dayPlans: [DayPlanBackup]? = nil,
        trainingBlocks: [TrainingBlockBackup]? = nil,
        bodyMetrics: [BodyMetricBackup]? = nil
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.exercises = exercises
        self.sessions = sessions
        self.splitDays = splitDays
        self.dayPlans = dayPlans
        self.trainingBlocks = trainingBlocks
        self.bodyMetrics = bodyMetrics
    }
}

/// One body-measurement row. `kindRaw` is `BodyMetricKind.rawValue`.
/// `value` is pounds for weight and inches for girths.
struct BodyMetricBackup: Codable, Equatable {
    var id: UUID
    var date: Date
    var kindRaw: String
    var value: Double
    var note: String
}

/// One imported program and the session ids that belong to it.
struct TrainingBlockBackup: Codable, Equatable {
    var id: UUID
    var name: String
    var notes: String
    var startDate: Date
    var importedAt: Date
    var sessionIDs: [UUID]
}

/// Ordered roster for one split day. Source of truth after restore / iCloud merge.
struct DayPlanBackup: Codable, Equatable {
    var dayName: String
    var exerciseIDs: [UUID]
}

struct BackupSummary: Equatable {
    var splitDayNames: [String]
    var assignedExerciseCount: Int
    var exerciseCount: Int
    var sessionCount: Int
    /// Exercise logs whose `trainingMode` this build does not understand.
    var droppedExerciseRecordCount: Int = 0
    /// Distinct unknown mode strings, file order.
    var unknownTrainingModes: [String] = []

    var hasSplitWithExercises: Bool {
        !splitDayNames.isEmpty && assignedExerciseCount > 0
    }

    var hasAnyData: Bool {
        !splitDayNames.isEmpty || exerciseCount > 0 || sessionCount > 0
    }

    var splitPhrase: String {
        let days = splitDayNames.isEmpty ? "no split days" : splitDayNames.joined(separator: ", ")
        let liftWord = assignedExerciseCount == 1 ? "exercise" : "exercises"
        let workoutWord = sessionCount == 1 ? "workout" : "workouts"
        return "\(days) · \(assignedExerciseCount) \(liftWord) on those days · \(sessionCount) \(workoutWord)"
    }
}

struct RestorePrompt: Equatable {
    var title: String
    var message: String
    var confirmTitle: String
    var cancelTitle: String
}

struct SplitDayBackup: Codable, Equatable {
    var id: UUID
    var name: String
    var systemImage: String
    var subtitle: String
    var colorHex: Int
    var includesAllExercises: Bool
    var sortOrder: Int
}

struct ExerciseBackup: Codable {
    let id: UUID
    let name: String
    let dayType: String
    let muscleGroup: String
    let sortOrder: Int
    let isCustom: Bool
    let notes: String
    /// "" / "A" / "B" — optional for older backups.
    let rotationTrack: String?
    /// Comma-separated extra day names — optional for older backups.
    let extraDayTypes: String?
    /// Per-day list order (`Push:0,Legs:3`) — optional for older backups.
    let daySortOrdersRaw: String?

    init(
        id: UUID,
        name: String,
        dayType: String,
        muscleGroup: String,
        sortOrder: Int,
        isCustom: Bool,
        notes: String,
        rotationTrack: String? = nil,
        extraDayTypes: String? = nil,
        daySortOrdersRaw: String? = nil
    ) {
        self.id = id
        self.name = name
        self.dayType = dayType
        self.muscleGroup = muscleGroup
        self.sortOrder = sortOrder
        self.isCustom = isCustom
        self.notes = notes
        self.rotationTrack = rotationTrack
        self.extraDayTypes = extraDayTypes
        self.daySortOrdersRaw = daySortOrdersRaw
    }
}

struct WorkoutSessionBackup: Codable {
    let id: UUID
    let date: Date
    let dayType: String
    let notes: String
    let isCompleted: Bool
    let exerciseRecords: [ExerciseRecordBackup]
    /// "" / "A" / "B" — optional for older backups.
    let rotationTrack: String?
    /// Seconds; optional for older backups.
    let durationSeconds: Double?
    /// "" / "planned" / "skipped" — optional for older backups.
    let planState: String?
    /// Optional for older backups. Planned sessions use their own lift list.
    let followsSessionRoster: Bool?
    /// File-order index in an imported block. Optional for older backups.
    let planOrder: Int?

    init(
        id: UUID,
        date: Date,
        dayType: String,
        notes: String,
        isCompleted: Bool,
        exerciseRecords: [ExerciseRecordBackup],
        rotationTrack: String? = nil,
        durationSeconds: Double? = nil,
        planState: String? = nil,
        followsSessionRoster: Bool? = nil,
        planOrder: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.dayType = dayType
        self.notes = notes
        self.isCompleted = isCompleted
        self.exerciseRecords = exerciseRecords
        self.rotationTrack = rotationTrack
        self.durationSeconds = durationSeconds
        self.planState = planState
        self.followsSessionRoster = followsSessionRoster
        self.planOrder = planOrder
    }
}

struct ExerciseRecordBackup: Codable {
    let id: UUID
    let exerciseID: UUID?
    let trainingMode: String
    let sortOrder: Int
    let isCompleted: Bool
    let notes: String
    let sets: [SetRecordBackup]
}

struct SetRecordBackup: Codable {
    let id: UUID
    let setNumber: Int
    let weightLbs: Double
    let reps: Int
    let isWarmup: Bool
    /// Optional for older backups that predate this field.
    let isEachSide: Bool?
    let isAssisted: Bool?
    let completedAt: Date
    /// Optional for older backups that predate plan targets.
    let isTarget: Bool?

    init(
        id: UUID,
        setNumber: Int,
        weightLbs: Double,
        reps: Int,
        isWarmup: Bool,
        isEachSide: Bool = false,
        isAssisted: Bool = false,
        completedAt: Date,
        isTarget: Bool = false
    ) {
        self.id = id
        self.setNumber = setNumber
        self.weightLbs = weightLbs
        self.reps = reps
        self.isWarmup = isWarmup
        self.isEachSide = isEachSide
        self.isAssisted = isAssisted
        self.completedAt = completedAt
        self.isTarget = isTarget
    }

    var resolvedEachSide: Bool { isEachSide ?? false }
    var resolvedAssisted: Bool { isAssisted ?? false }
    var resolvedTarget: Bool { isTarget ?? false }
}
