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

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(exercises.map(\.id), [exerciseID])
        XCTAssertEqual(exercises.map(\.name), ["Legacy Squat"])

        let blocks = try context.fetch(FetchDescriptor<TrainingBlock>())
        XCTAssertEqual(blocks.map(\.id), [blockID])
        XCTAssertEqual(blocks.map(\.name), ["Legacy Block"])
        XCTAssertEqual(blocks.map(\.notes), ["from the unversioned store"])

        let metrics = try context.fetch(FetchDescriptor<BodyMetricEntry>())
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
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(exercises.map(\.id), [exerciseID])
        XCTAssertEqual(exercises.first?.defaultRestSeconds, 0)
        XCTAssertEqual(exercises.first?.autoRestEnabled, true)
        XCTAssertEqual(exercises.first?.autoRestCopied, false)
        XCTAssertEqual(exercises.first?.suggestWarmupRamp, false)
        XCTAssertEqual(exercises.first?.loadModeRaw, "")
        let gyms = try context.fetch(FetchDescriptor<Gym>())
        XCTAssertTrue(gyms.isEmpty)
        let profiles = try context.fetch(FetchDescriptor<MachineStackProfile>())
        XCTAssertTrue(profiles.isEmpty)
    }

    private func writeVersionedV1(url: URL, exerciseID: UUID) throws {
        let schema = Schema(versionedSchema: RockLogSchemaV1.self)
        try open(schema: schema, url: url, migrationPlan: false)
        let exercise = Exercise.make(name: "Version One Press", dayType: .push, muscleGroup: "Chest", isCustom: true)
        exercise.id = exerciseID
        container!.mainContext.insert(exercise)
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

        let exercise = Exercise.make(name: "Legacy Squat", dayType: .legs, muscleGroup: "Quads", isCustom: true)
        exercise.id = exerciseID
        let block = TrainingBlock(
            name: "Legacy Block",
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            notes: "from the unversioned store"
        )
        block.id = blockID
        let metric = BodyMetricEntry(
            kind: .weight,
            value: 180,
            date: Date(timeIntervalSince1970: 1_700_000_000)
        )
        metric.id = metricID
        context.insert(exercise)
        context.insert(block)
        context.insert(metric)
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
