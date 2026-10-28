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
    /// Gyms. Nil preserves the phone's gyms (older files). An array replaces them.
    let gyms: [GymBackup]?
    /// Stack profiles keyed by gym and lift. Same nil-vs-empty rule.
    let stackProfiles: [StackProfileBackup]?
    /// "lb" or "kg" at export. Missing on older files, which are pounds.
    let weightUnit: String?

    init(
        version: Int,
        exportedAt: Date,
        exercises: [ExerciseBackup],
        sessions: [WorkoutSessionBackup],
        splitDays: [SplitDayBackup]? = nil,
        dayPlans: [DayPlanBackup]? = nil,
        trainingBlocks: [TrainingBlockBackup]? = nil,
        bodyMetrics: [BodyMetricBackup]? = nil,
        gyms: [GymBackup]? = nil,
        stackProfiles: [StackProfileBackup]? = nil,
        weightUnit: String? = nil
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.exercises = exercises
        self.sessions = sessions
        self.splitDays = splitDays
        self.dayPlans = dayPlans
        self.trainingBlocks = trainingBlocks
        self.bodyMetrics = bodyMetrics
        self.gyms = gyms
        self.stackProfiles = stackProfiles
        self.weightUnit = weightUnit
    }

    private enum CodingKeys: String, CodingKey {
        case version, exportedAt, exercises, sessions, splitDays, dayPlans
        case trainingBlocks, bodyMetrics, gyms, stackProfiles, weightUnit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Backups written before the field existed are version 1.
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        exercises = try container.decode([ExerciseBackup].self, forKey: .exercises)
        sessions = try container.decode([WorkoutSessionBackup].self, forKey: .sessions)
        splitDays = try container.decodeIfPresent([SplitDayBackup].self, forKey: .splitDays)
        dayPlans = try container.decodeIfPresent([DayPlanBackup].self, forKey: .dayPlans)
        trainingBlocks = try container.decodeIfPresent([TrainingBlockBackup].self, forKey: .trainingBlocks)
        bodyMetrics = try container.decodeIfPresent([BodyMetricBackup].self, forKey: .bodyMetrics)
        gyms = try container.decodeIfPresent([GymBackup].self, forKey: .gyms)
        stackProfiles = try container.decodeIfPresent([StackProfileBackup].self, forKey: .stackProfiles)
        weightUnit = try container.decodeIfPresent(String.self, forKey: .weightUnit)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(exportedAt, forKey: .exportedAt)
        try container.encode(exercises, forKey: .exercises)
        try container.encode(sessions, forKey: .sessions)
        try container.encodeIfPresent(splitDays, forKey: .splitDays)
        try container.encodeIfPresent(dayPlans, forKey: .dayPlans)
        try container.encodeIfPresent(trainingBlocks, forKey: .trainingBlocks)
        try container.encodeIfPresent(bodyMetrics, forKey: .bodyMetrics)
        try container.encodeIfPresent(gyms, forKey: .gyms)
        try container.encodeIfPresent(stackProfiles, forKey: .stackProfiles)
        try container.encodeIfPresent(weightUnit, forKey: .weightUnit)
    }
}

struct GymBackup: Codable, Equatable {
    var id: UUID
    var name: String
    var isHome: Bool
    var createdAt: Date
    var sortOrder: Int
    /// Reserved. Missing means location is not set.
    var latitude: Double? = nil
    var longitude: Double? = nil
    var radiusMeters: Double? = nil
}

struct StackProfileBackup: Codable, Equatable {
    var id: UUID
    var gymID: UUID
    var exerciseID: UUID
    var stepPounds: Double
    /// Missing means offset 0. A 10 lb step with offset 5 is 145, 155, 165.
    var offsetPounds: Double? = nil
    var pinsRaw: String
    var pinUnitRaw: String
    var addOnsRaw: String
    var policyRaw: String
    var originRaw: String
    var learnedSessionIDsRaw: String
    var clearedAt: Date?
    var learningEnabled: Bool
    var rangeMin: Double
    var rangeMax: Double
    /// When this row was last typed, learned, or cleared. Nil on files from before the field.
    var updatedAt: Date? = nil
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
    /// Keys this build does not store. Reported, not applied.
    var unknownKeyCount: Int = 0
    var unknownKeyPaths: [String] = []
    /// Enum strings this build does not know. Reported, not applied.
    var unknownEnumCount: Int = 0
    var unknownEnums: [String] = []

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
    /// 0 or missing means the seed / Settings rest still applies.
    let defaultRestSeconds: Int?
    /// Missing means the lift follows the global rest switch.
    let autoRestEnabled: Bool?
    /// "bar", "assist", "added", or missing.
    let loadModeRaw: String?
    /// Missing means the lift does not offer a warm-up ramp.
    let suggestWarmupRamp: Bool?

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
        daySortOrdersRaw: String? = nil,
        defaultRestSeconds: Int? = nil,
        autoRestEnabled: Bool? = nil,
        loadModeRaw: String? = nil,
        suggestWarmupRamp: Bool? = nil
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
        self.defaultRestSeconds = defaultRestSeconds
        self.autoRestEnabled = autoRestEnabled
        self.loadModeRaw = loadModeRaw
        self.suggestWarmupRamp = suggestWarmupRamp
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
    /// Missing means Home, filled in on restore when Home exists.
    let gymID: UUID?
    /// Name at the time of the workout. Kept after the gym row is deleted.
    let gymName: String?

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
        planOrder: Int? = nil,
        gymID: UUID? = nil,
        gymName: String? = nil
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
        self.gymID = gymID
        self.gymName = gymName
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
    /// Circuit id. Missing means the lift is not in a group.
    let groupID: UUID?
    /// 1...4, or missing.
    let groupPosition: Int?

    init(
        id: UUID,
        exerciseID: UUID?,
        trainingMode: String,
        sortOrder: Int,
        isCompleted: Bool,
        notes: String,
        sets: [SetRecordBackup],
        groupID: UUID? = nil,
        groupPosition: Int? = nil
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.trainingMode = trainingMode
        self.sortOrder = sortOrder
        self.isCompleted = isCompleted
        self.notes = notes
        self.sets = sets
        self.groupID = groupID
        self.groupPosition = groupPosition
    }
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
    let offeredWeightLbs: Double?
    let loadModeRaw: String?
    let bodyWeightUsedLbs: Double?
    let plannedRestSeconds: Int?
    let actualRestSeconds: Int?
    /// Missing on older files. Empty means the set was stored as pounds only.
    let enteredUnitRaw: String?
    let enteredValue: Double?

    init(
        id: UUID,
        setNumber: Int,
        weightLbs: Double,
        reps: Int,
        isWarmup: Bool,
        isEachSide: Bool = false,
        isAssisted: Bool = false,
        completedAt: Date,
        isTarget: Bool = false,
        offeredWeightLbs: Double? = nil,
        loadModeRaw: String? = nil,
        bodyWeightUsedLbs: Double? = nil,
        plannedRestSeconds: Int? = nil,
        actualRestSeconds: Int? = nil,
        enteredUnitRaw: String? = nil,
        enteredValue: Double? = nil
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
        self.offeredWeightLbs = offeredWeightLbs
        self.loadModeRaw = loadModeRaw
        self.bodyWeightUsedLbs = bodyWeightUsedLbs
        self.plannedRestSeconds = plannedRestSeconds
        self.actualRestSeconds = actualRestSeconds
        self.enteredUnitRaw = enteredUnitRaw
        self.enteredValue = enteredValue
    }

    var resolvedEachSide: Bool { isEachSide ?? false }
    var resolvedAssisted: Bool { isAssisted ?? false }
    var resolvedTarget: Bool { isTarget ?? false }
}
