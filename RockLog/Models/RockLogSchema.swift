//
//  RockLogSchema.swift
//  RockLog
//
//  Versioned schema for the iCloud-backed SwiftData store.
//

import Foundation
import SwiftData
import os

/// Schema of the store as it existed when versioning was introduced.
///
/// These are the same models the previous unversioned `ModelContainer` used.
/// Opening an existing CloudKit store is a lightweight migration with no
/// stage. Do not edit `V1` once a later version ships — add a later schema
/// and a lightweight `MigrationStage` on `RockLogMigrationPlan`. CloudKit
/// rejects a custom (heavy) stage.
///
/// The types are the V2 snapshots. V1 and V2 share those classes, and V2
/// only adds `Gym` and `MachineStackProfile`. The live classes are V3.
nonisolated enum RockLogSchemaV1: VersionedSchema {
    nonisolated static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    nonisolated static var models: [any PersistentModel.Type] {
        [
            RockLogSchemaV2.Exercise.self,
            RockLogSchemaV2.WorkoutSession.self,
            RockLogSchemaV2.ExerciseRecord.self,
            RockLogSchemaV2.SetRecord.self,
            RockLogSchemaV2.SplitDay.self,
            RockLogSchemaV2.BodyMetricEntry.self,
            RockLogSchemaV2.TrainingBlock.self,
        ]
    }
}

/// Additive stage. New fields have defaults. New models are Gym and
/// MachineStackProfile. The stack offset, the session's gym id, and the
/// gym's empty location fields are part of this first V2, not a later one.
/// Nothing in V1 is removed or renamed. No unique
/// constraints. The pin list is a string on the profile. Do not promote
/// the production CloudKit schema from a build that contains this stage
/// until that deploy is an explicit choice. See docs/specs/schema-v2-rollback.md.
///
/// Rollback: do not ship a build that opens this version if you need the
/// previous build to open the same store. SwiftData will not step a V2
/// store back to V1. A phone that already migrated can restore a backup
/// JSON onto a V1 build only after the V2 rows are gone (delete and
/// reinstall, then restore). See docs/specs/schema-v2-rollback.md.
///
/// The nested classes are the frozen V2 shape. They do not include the
/// entered-unit fields. Those land in V3, on the live models. Nested
/// model names stay the short names (`SetRecord`, not the parent enum)
/// so a lightweight stage can match a store written by the previous build.
nonisolated enum RockLogSchemaV2: VersionedSchema {
    nonisolated static var versionIdentifier: Schema.Version {
        Schema.Version(2, 0, 0)
    }

    nonisolated static var models: [any PersistentModel.Type] {
        RockLogSchemaV1.models + [
            RockLogSchemaV2.Gym.self,
            RockLogSchemaV2.MachineStackProfile.self,
        ]
    }

    @Model
    final class Exercise {
        var id: UUID = UUID()
        var name: String = ""
        var dayType: String = ""
        var extraDayTypes: String = ""
        var muscleGroup: String = ""
        var sortOrder: Int = 0
        var isCustom: Bool = false
        var notes: String = ""
        var rotationTrack: String = ""
        var daySortOrdersRaw: String = ""
        var defaultRestSeconds: Int = 0
        var autoRestEnabled: Bool = true
        var autoRestCopied: Bool = false
        var loadModeRaw: String = ""
        var suggestWarmupRamp: Bool = false

        @Relationship(deleteRule: .cascade, inverse: \ExerciseRecord.exercise)
        var records: [ExerciseRecord]? = nil

        init(
            name: String,
            dayType: DayType? = nil,
            muscleGroup: String = "",
            sortOrder: Int = 0,
            isCustom: Bool = false
        ) {
            self.name = name
            self.dayType = dayType?.rawValue ?? ""
            self.muscleGroup = muscleGroup
            self.sortOrder = sortOrder
            self.isCustom = isCustom
        }
    }

    @Model
    final class WorkoutSession {
        var id: UUID = UUID()
        var date: Date = Date.now
        var dayType: String = DayType.arms.rawValue
        var notes: String = ""
        var isCompleted: Bool = false
        var healthKitWorkoutUUID: UUID? = nil
        var effortRating: Int? = nil
        var durationSeconds: Double = 0
        var rotationTrack: String = RotationTrack.a.rawValue
        var suppressedExerciseIDsRaw: String = ""
        var planState: String = ""
        var planOrder: Int = 0
        var followsSessionRoster: Bool = false
        var gymID: UUID? = nil
        var gymName: String = ""
        var trainingBlock: TrainingBlock? = nil

        @Relationship(deleteRule: .cascade, inverse: \ExerciseRecord.session)
        var exerciseRecords: [ExerciseRecord]?

        init(dayType: DayType, date: Date = .now) {
            self.date = date
            self.dayType = dayType.rawValue
            self.exerciseRecords = []
        }
    }

    @Model
    final class ExerciseRecord {
        var id: UUID = UUID()
        var trainingMode: TrainingMode = TrainingMode.highWeightLowReps
        var sortOrder: Int = 0
        var isCompleted: Bool = false
        var notes: String = ""
        var groupID: UUID? = nil
        var groupPosition: Int = 0

        var exercise: Exercise?
        var session: WorkoutSession?

        @Relationship(deleteRule: .cascade, inverse: \SetRecord.exerciseRecord)
        var sets: [SetRecord]?

        init(trainingMode: TrainingMode, sortOrder: Int = 0) {
            self.trainingMode = trainingMode
            self.sortOrder = sortOrder
            self.sets = []
        }
    }

    @Model
    final class SetRecord {
        var id: UUID = UUID()
        var setNumber: Int = 0
        var weightLbs: Double = 0
        var reps: Int = 0
        var isWarmup: Bool = false
        var isEachSide: Bool = false
        var isAssisted: Bool = false
        var completedAt: Date = Date.now
        var isTarget: Bool = false
        var offeredWeightLbs: Double? = nil
        var loadModeRaw: String = ""
        var bodyWeightUsedLbs: Double = 0
        var plannedRestSeconds: Int = 0
        var actualRestSeconds: Int = 0

        var exerciseRecord: ExerciseRecord?

        init(setNumber: Int, weightLbs: Double, reps: Int) {
            self.setNumber = setNumber
            self.weightLbs = weightLbs
            self.reps = reps
        }
    }

    @Model
    final class SplitDay {
        var id: UUID = UUID()
        var name: String = ""
        var systemImage: String = "dumbbell.fill"
        var subtitle: String = ""
        var colorHex: Int = 0xFF4D88
        var includesAllExercises: Bool = false
        var sortOrder: Int = 0

        init(name: String, systemImage: String = "dumbbell.fill", sortOrder: Int = 0) {
            self.name = name
            self.systemImage = systemImage
            self.sortOrder = sortOrder
        }
    }

    @Model
    final class BodyMetricEntry {
        var id: UUID = UUID()
        var date: Date = Date.now
        var kindRaw: String = BodyMetricKind.weight.rawValue
        var value: Double = 0
        var note: String = ""

        var kind: BodyMetricKind {
            get { BodyMetricKind(rawValue: kindRaw) ?? .weight }
            set { kindRaw = newValue.rawValue }
        }

        init(kind: BodyMetricKind, value: Double, date: Date = .now, note: String = "") {
            self.date = date
            self.kindRaw = kind.rawValue
            self.value = value
            self.note = note
        }
    }

    @Model
    final class TrainingBlock {
        var id: UUID = UUID()
        var name: String = ""
        var notes: String = ""
        var startDate: Date = Date.now
        var importedAt: Date = Date.now

        @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.trainingBlock)
        var sessions: [WorkoutSession]?

        init(name: String, startDate: Date, notes: String = "") {
            self.name = name
            self.notes = notes
            self.startDate = startDate
            self.sessions = []
        }
    }

    @Model
    final class Gym {
        var id: UUID = UUID()
        var name: String = "Home"
        var isHome: Bool = false
        var createdAt: Date = Date.now
        var sortOrder: Int = 0
        var latitude: Double? = nil
        var longitude: Double? = nil
        var radiusMeters: Double? = nil

        init(name: String, isHome: Bool = false, sortOrder: Int = 0) {
            self.name = name
            self.isHome = isHome
            self.sortOrder = sortOrder
        }
    }

    @Model
    final class MachineStackProfile {
        var id: UUID = UUID()
        var gymID: UUID = UUID()
        var exerciseID: UUID = UUID()
        var stepPounds: Double = 0
        var offsetPounds: Double = 0
        var pinsRaw: String = ""
        var pinUnitRaw: String = "lb"
        var addOnsRaw: String = ""
        var policyRaw: String = "nearest"
        var originRaw: String = ""
        var learnedSessionIDsRaw: String = ""
        var clearedAt: Date? = nil
        var learningEnabled: Bool = true
        var rangeMin: Double = 0
        var rangeMax: Double = 0
        var updatedAt: Date? = nil

        init(gymID: UUID, exerciseID: UUID) {
            self.gymID = gymID
            self.exerciseID = exerciseID
        }
    }
}

/// Entered unit and entered value on each set. Defaults cover older rows.
/// This version is the live model the app fetches. V2→V3 is lightweight:
/// `enteredUnitRaw` defaults to "" and `enteredValue` defaults to 0.
nonisolated enum RockLogSchemaV3: VersionedSchema {
    nonisolated static var versionIdentifier: Schema.Version {
        Schema.Version(3, 0, 0)
    }

    nonisolated static var models: [any PersistentModel.Type] {
        [
            Exercise.self,
            WorkoutSession.self,
            ExerciseRecord.self,
            SetRecord.self,
            SplitDay.self,
            BodyMetricEntry.self,
            TrainingBlock.self,
            Gym.self,
            MachineStackProfile.self,
        ]
    }
}

/// One upgrade step (QA checklist #47, Lee's decision Oct 30, 2026):
/// the plan lists only the shipped schema (V1) and the live schema (V3),
/// joined by ONE lightweight stage. V2 is kept above only as a frozen
/// description of the shape that pre-release development builds wrote.
///
/// A V2 store is not in the plan, so the staged migrator refuses it
/// ("unknown coordinator model version"). `openContainer` then opens the
/// same file without a plan, which is Core Data's inferred lightweight
/// migration from the model saved in the store to V3. V2→V3 only adds
/// defaulted fields, so nothing is dropped. If that also fails, the
/// original error is thrown and nothing is deleted. Both paths are
/// covered by RockLogSchemaMigrationTests with synthetic V1 and V2 stores.
nonisolated enum RockLogMigrationPlan: SchemaMigrationPlan {
    nonisolated static var schemas: [any VersionedSchema.Type] {
        [RockLogSchemaV1.self, RockLogSchemaV3.self]
    }

    nonisolated static var stages: [MigrationStage] {
        [
            .lightweight(
                fromVersion: RockLogSchemaV1.self,
                toVersion: RockLogSchemaV3.self
            ),
        ]
    }

    /// Opens the store with the one-stage plan, falling back to inferred
    /// lightweight migration for a V2 store written by a development build.
    nonisolated static func openContainer(
        for schema: Schema,
        configurations: [ModelConfiguration]
    ) throws -> ModelContainer {
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: RockLogMigrationPlan.self,
                configurations: configurations
            )
        } catch let planned {
            let ns = planned as NSError
            // Only "unknown coordinator model version" (a V2 dev store not in the plan)
            // falls back to inferred lightweight migration. Every other error is rethrown.
            guard isUnknownModelVersion(planned) else {
                throw planned
            }
            migrationLog.error("Planned open failed domain=\(ns.domain, privacy: .public) code=\(ns.code, privacy: .public); retrying without the plan")
            fallbackCount.withLock { $0 += 1 }
            do {
                return try ModelContainer(for: schema, configurations: configurations)
            } catch {
                throw planned
            }
        }
    }

    /// True only for Core Data 134504 ("Cannot use staged migration with an unknown
    /// model version"). SwiftData surfaces that one as SwiftDataError
    /// .unknownDataStoreSchema with no underlying NSError, so both forms count.
    nonisolated static func isUnknownModelVersion(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain && ns.code == unknownModelVersionCode { return true }
        if let swiftData = error as? SwiftDataError {
            return String(describing: swiftData).contains("unknownDataStoreSchema")
        }
        return false
    }

    /// NSPersistentStoreIncompatibleVersionHashError-family code Core Data uses for
    /// "unknown coordinator model version".
    nonisolated static let unknownModelVersionCode = 134504
    /// Times openContainer used the no-plan fallback in this process. Tests read it.
    nonisolated static let fallbackCount = OSAllocatedUnfairLock(initialState: 0)
    nonisolated private static let migrationLog = Logger(subsystem: "com.lee.lift2026", category: "migration")
}
