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

nonisolated enum RockLogMigrationPlan: SchemaMigrationPlan {
    nonisolated static var schemas: [any VersionedSchema.Type] {
        [RockLogSchemaV1.self]
    }

    /// Empty until the next schema version.
    nonisolated static var stages: [MigrationStage] { [] }
}
