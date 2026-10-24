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
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: RockLogMigrationPlan.self,
            configurations: [config]
        )
        let context = container.mainContext

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

    /// The pre-versioning container: `Schema([...])` and no migration plan.
    private func writeUnversionedFixture(
        url: URL,
        exerciseID: UUID,
        blockID: UUID,
        metricID: UUID
    ) throws {
        let schema = Schema(RockLogSchemaV1.models)
        let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        let exercise = Exercise(name: "Legacy Squat", dayType: .legs, muscleGroup: "Quads", isCustom: true)
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
    }
}
