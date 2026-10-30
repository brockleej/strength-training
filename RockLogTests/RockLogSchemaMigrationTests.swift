//
//  RockLogSchemaMigrationTests.swift
//  RockLogTests
//
//  B6: a store written the way the previous build wrote it (unversioned
//  schema, same models) must open through RockLogMigrationPlan.
//

import XCTest
import SwiftData
@testable import RockLog

@MainActor
final class RockLogSchemaMigrationTests: XCTestCase {
    /// The store currently open. Cleared in tearDown. The writer is released
    /// before the reader opens the same file, so SQLite is not left locked.
    private var container: ModelContainer?

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    func test_b6_unversionedStore_opensThroughMigrationPlan() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rocklog-schema-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("RockLog.store")

        let exerciseID = UUID()
        let blockID = UUID()
        let metricID = UUID()
        try writeUnversionedFixture(
            url: storeURL,
            exerciseID: exerciseID,
            blockID: blockID,
            metricID: metricID
        )

        let schema = Schema(versionedSchema: RockLogSchemaV1.self)
        try open(schema: schema, url: storeURL, migrationPlan: true)
        let context = container!.mainContext

        let exercises = try context.fetch(FetchDescriptor<RockLogSchemaV2.Exercise>())
        XCTAssertEqual(exercises.map(\.id), [exerciseID])
        XCTAssertEqual(exercises.map(\.name), ["Legacy Squat"])

        let blocks = try context.fetch(FetchDescriptor<RockLogSchemaV2.TrainingBlock>())
        XCTAssertEqual(blocks.map(\.id), [blockID])
        XCTAssertEqual(blocks.map(\.name), ["Legacy Block"])
        XCTAssertEqual(blocks.map(\.notes), ["from the unversioned store"])

        let metrics = try context.fetch(FetchDescriptor<RockLogSchemaV2.BodyMetricEntry>())
        XCTAssertEqual(metrics.map(\.id), [metricID])
        XCTAssertEqual(metrics.map(\.kind), [.weight])
        XCTAssertEqual(metrics.map(\.value), [180])
    }

    /// A store that was opened as version 1.0.0, then opened by this build.
    /// Synthetic rows only. This does not touch the production CloudKit schema.
    func test_v1Store_opensUnderV2() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rocklog-v1-under-v2-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("RockLog.store")
        let exerciseID = UUID()
        try writeVersionedV1(url: storeURL, exerciseID: exerciseID)

        let schema = Schema(versionedSchema: RockLogSchemaV2.self)
        try open(schema: schema, url: storeURL, migrationPlan: true)
        let context = container!.mainContext
        let exercises = try context.fetch(FetchDescriptor<RockLogSchemaV2.Exercise>())
        XCTAssertEqual(exercises.map(\.id), [exerciseID])
        XCTAssertEqual(exercises.first?.defaultRestSeconds, 0)
        XCTAssertEqual(exercises.first?.autoRestEnabled, true)
        XCTAssertEqual(exercises.first?.autoRestCopied, false)
        XCTAssertEqual(exercises.first?.suggestWarmupRamp, false)
        XCTAssertEqual(exercises.first?.loadModeRaw, "")
        let gyms = try context.fetch(FetchDescriptor<RockLogSchemaV2.Gym>())
        XCTAssertTrue(gyms.isEmpty)
        let profiles = try context.fetch(FetchDescriptor<RockLogSchemaV2.MachineStackProfile>())
        XCTAssertTrue(profiles.isEmpty)
    }

    /// A V1 file on disk, including a logged set, opens as V2 without dropping the set.
    func test_v1OnDiskStore_migratesLoggedSetToV2() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rocklog-v1-set-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("RockLog.store")
        let exerciseID = UUID()
        let setID = UUID()
        try writeVersionedV1Workout(url: storeURL, exerciseID: exerciseID, setID: setID)

        let schema = Schema(versionedSchema: RockLogSchemaV2.self)
        try open(schema: schema, url: storeURL, migrationPlan: true)
        let context = container!.mainContext
        let sets = try context.fetch(FetchDescriptor<RockLogSchemaV2.SetRecord>())
        XCTAssertEqual(sets.map(\.id), [setID])
        XCTAssertEqual(sets.first?.weightLbs, 135)
        XCTAssertEqual(sets.first?.reps, 8)
        XCTAssertEqual(sets.first?.exerciseRecord?.exercise?.id, exerciseID)
        XCTAssertEqual(sets.first?.exerciseRecord?.session?.isCompleted, true)
        let gyms = try context.fetch(FetchDescriptor<RockLogSchemaV2.Gym>())
        XCTAssertTrue(gyms.isEmpty)
    }

    /// Pre-TestFlight #47: a V1 store (what main / the last TestFlight
    /// wrote) opens straight into the live V3 schema through both
    /// lightweight stages in one launch. Synthetic data only.
    func test_v1OnDiskStore_migratesThroughBothStagesToV3() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rocklog-v1-v3-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("RockLog.store")
        let exerciseID = UUID()
        let setID = UUID()
        try writeVersionedV1Workout(url: storeURL, exerciseID: exerciseID, setID: setID)

        let schema = Schema(versionedSchema: RockLogSchemaV3.self)
        try open(schema: schema, url: storeURL, migrationPlan: true)
        let context = container!.mainContext
        let sets = try context.fetch(FetchDescriptor<SetRecord>())
        XCTAssertEqual(sets.map(\.id), [setID])
        XCTAssertEqual(sets.first?.weightLbs, 135)
        XCTAssertEqual(sets.first?.reps, 8)
        XCTAssertEqual(sets.first?.enteredUnitRaw, "")
        XCTAssertEqual(sets.first?.enteredValue, 0)
        XCTAssertEqual(sets.first?.exerciseRecord?.exercise?.id, exerciseID)
        XCTAssertEqual(sets.first?.exerciseRecord?.session?.isCompleted, true)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Gym>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<MachineStackProfile>()).isEmpty)
    }

    /// A V2 file on disk, including a logged set, opens as V3 and keeps the row.
    /// Entered unit and value stay at the V3 defaults. Synthetic data only.
    func test_v2OnDiskStore_migratesLoggedSetToV3() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rocklog-v2-set-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("RockLog.store")
        let exerciseID = UUID()
        let setID = UUID()
        try writeVersionedV2Workout(url: storeURL, exerciseID: exerciseID, setID: setID)

        let schema = Schema(versionedSchema: RockLogSchemaV3.self)
        try open(schema: schema, url: storeURL, migrationPlan: true)
        let context = container!.mainContext
        let sets = try context.fetch(FetchDescriptor<SetRecord>())
        XCTAssertEqual(sets.map(\.id), [setID])
        XCTAssertEqual(sets.first?.weightLbs, 135)
        XCTAssertEqual(sets.first?.reps, 8)
        XCTAssertEqual(sets.first?.enteredUnitRaw, "")
        XCTAssertEqual(sets.first?.enteredValue, 0)
        XCTAssertEqual(sets.first?.exerciseRecord?.exercise?.id, exerciseID)
        XCTAssertEqual(sets.first?.exerciseRecord?.exercise?.name, "Frozen V2 Press")
        XCTAssertEqual(sets.first?.exerciseRecord?.session?.isCompleted, true)
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(exercises.map(\.id), [exerciseID])
        let gyms = try context.fetch(FetchDescriptor<Gym>())
        XCTAssertTrue(gyms.isEmpty)
    }

    private func writeVersionedV2Workout(url: URL, exerciseID: UUID, setID: UUID) throws {
        let schema = Schema(versionedSchema: RockLogSchemaV2.self)
        try open(schema: schema, url: url, migrationPlan: false)
        let context = container!.mainContext
        insertLoggedSet(
            in: context,
            name: "Frozen V2 Press",
            exerciseID: exerciseID,
            setID: setID
        )
        try context.save()
        container = nil
    }

    private func writeVersionedV1Workout(url: URL, exerciseID: UUID, setID: UUID) throws {
        let schema = Schema(versionedSchema: RockLogSchemaV1.self)
        try open(schema: schema, url: url, migrationPlan: false)
        let context = container!.mainContext
        insertLoggedSet(
            in: context,
            name: "Version One Press",
            exerciseID: exerciseID,
            setID: setID
        )
        try context.save()
        container = nil
    }

    private func insertLoggedSet(
        in context: ModelContext,
        name: String,
        exerciseID: UUID,
        setID: UUID
    ) {
        let exercise = RockLogSchemaV2.Exercise(name: name, dayType: .push, muscleGroup: "Chest", isCustom: true)
        exercise.id = exerciseID
        let session = RockLogSchemaV2.WorkoutSession(dayType: .push, date: Date(timeIntervalSince1970: 1_700_000_000))
        session.isCompleted = true
        let record = RockLogSchemaV2.ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
        record.exercise = exercise
        record.session = session
        let set = RockLogSchemaV2.SetRecord(setNumber: 1, weightLbs: 135, reps: 8)
        set.id = setID
        set.exerciseRecord = record
        record.sets = [set]
        session.exerciseRecords = [record]
        context.insert(exercise)
        exercise.id = exerciseID
        context.insert(session)
        context.insert(record)
        context.insert(set)
        set.id = setID
    }

    private func writeVersionedV1(url: URL, exerciseID: UUID) throws {
        let schema = Schema(versionedSchema: RockLogSchemaV1.self)
        try open(schema: schema, url: url, migrationPlan: false)
        let exercise = RockLogSchemaV2.Exercise(name: "Version One Press", dayType: .push, muscleGroup: "Chest", isCustom: true)
        exercise.id = exerciseID
        container!.mainContext.insert(exercise)
        exercise.id = exerciseID
        try container!.mainContext.save()
        container = nil
    }

    /// The pre-versioning container: `Schema([...])` and no migration plan.
    private func writeUnversionedFixture(
        url: URL,
        exerciseID: UUID,
        blockID: UUID,
        metricID: UUID
    ) throws {
        let schema = Schema(RockLogSchemaV1.models)
        try open(schema: schema, url: url, migrationPlan: false)
        let context = container!.mainContext

        let exercise = RockLogSchemaV2.Exercise(name: "Legacy Squat", dayType: .legs, muscleGroup: "Quads", isCustom: true)
        exercise.id = exerciseID
        let block = RockLogSchemaV2.TrainingBlock(
            name: "Legacy Block",
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            notes: "from the unversioned store"
        )
        block.id = blockID
        let metric = RockLogSchemaV2.BodyMetricEntry(
            kind: .weight,
            value: 180,
            date: Date(timeIntervalSince1970: 1_700_000_000)
        )
        metric.id = metricID
        context.insert(exercise)
        exercise.id = exerciseID
        context.insert(block)
        block.id = blockID
        context.insert(metric)
        metric.id = metricID
        try context.save()
        container = nil
    }

    private func open(schema: Schema, url: URL, migrationPlan: Bool) throws {
        let config = ModelConfiguration(
            "RockLogSchema-\(UUID().uuidString)",
            schema: schema,
            url: url,
            cloudKitDatabase: .none
        )
        if migrationPlan {
            container = try ModelContainer(
                for: schema,
                migrationPlan: RockLogMigrationPlan.self,
                configurations: [config]
            )
        } else {
            container = try ModelContainer(for: schema, configurations: [config])
        }
    }
}
