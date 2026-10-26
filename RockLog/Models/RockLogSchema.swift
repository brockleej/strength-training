//
//  RockLogSchema.swift
//  RockLog
//
//  Versioned schema for the iCloud-backed SwiftData store.
//

import SwiftData

/// Schema of the store as it existed when versioning was introduced.
///
/// These are the same models the previous unversioned `ModelContainer` used.
/// Opening an existing CloudKit store is a lightweight migration with no
/// stage. Do not edit `V1` once a later version ships — add `RockLogSchemaV2`
/// and a lightweight `MigrationStage` on `RockLogMigrationPlan`. CloudKit
/// rejects a custom (heavy) stage.
nonisolated enum RockLogSchemaV1: VersionedSchema {
    nonisolated static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
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
nonisolated enum RockLogSchemaV2: VersionedSchema {
    nonisolated static var versionIdentifier: Schema.Version {
        Schema.Version(2, 0, 0)
    }

    nonisolated static var models: [any PersistentModel.Type] {
        RockLogSchemaV1.models + [
            Gym.self,
            MachineStackProfile.self,
        ]
    }
}

nonisolated enum RockLogMigrationPlan: SchemaMigrationPlan {
    nonisolated static var schemas: [any VersionedSchema.Type] {
        [RockLogSchemaV1.self, RockLogSchemaV2.self]
    }

    nonisolated static var stages: [MigrationStage] {
        [
            .lightweight(
                fromVersion: RockLogSchemaV1.self,
                toVersion: RockLogSchemaV2.self
            ),
        ]
    }
}
