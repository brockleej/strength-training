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

        let schema = Schema(versionedSchema: RockLogSchemaV3.self)
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
    func test_v1Store_opensUnderV3() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rocklog-v1-under-v2-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("RockLog.store")
        let exerciseID = UUID()
        try writeVersionedV1(url: storeURL, exerciseID: exerciseID)

        let schema = Schema(versionedSchema: RockLogSchemaV3.self)
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

    /// A V1 file on disk, including a logged set, opens as V2 without dropping the set.
    func test_v1OnDiskStore_migratesLoggedSetToV3() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rocklog-v1-set-\(UUID().uuidString)", isDirectory: true)
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
        XCTAssertEqual(sets.first?.exerciseRecord?.exercise?.id, exerciseID)
        XCTAssertEqual(sets.first?.exerciseRecord?.session?.isCompleted, true)
        let gyms = try context.fetch(FetchDescriptor<Gym>())
        XCTAssertTrue(gyms.isEmpty)
    }

    /// A V2 file on disk, including a logged set, opens as V3 and keeps the row.
    /// Entered unit and value stay at the V3 defaults. Synthetic data only.
    func test_v3Store_reopensThroughOpenContainer_withoutFallbackOrLoss() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rocklog-v3-reopen-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("RockLog.store")
        let schema = Schema(versionedSchema: RockLogSchemaV3.self)
        let before = RockLogMigrationPlan.fallbackCount.withLock { $0 }
        let setID = UUID(), gymID = UUID()
        try open(schema: schema, url: url, migrationPlan: true)
        do {
            let c = container!.mainContext
            let session = WorkoutSession(dayType: DayType(rawValue: "Push"))
            let record = ExerciseRecord(trainingMode: .highWeightLowReps)
            record.session = session
            let set = SetRecord(setNumber: 1, weightLbs: 100, reps: 5, isWarmup: false, isEachSide: false, isAssisted: false, isTarget: false)
            set.id = setID
            set.stampEntered(45, unit: .kilograms)
            set.exerciseRecord = record
            let gym = Gym(name: "Synthetic Gym")
            gym.id = gymID
            c.insert(session); c.insert(record); c.insert(set); c.insert(gym)
            try c.save()
        }
        container = nil
        try open(schema: schema, url: url, migrationPlan: true)
        let c = container!.mainContext
        let sets = try c.fetch(FetchDescriptor<SetRecord>())
        XCTAssertEqual(sets.map(\.id), [setID])
        XCTAssertEqual(sets.first?.enteredUnitRaw, MassUnit.kilograms.rawValue)
        XCTAssertNotNil(sets.first?.exerciseRecord?.session)
        XCTAssertEqual(try c.fetch(FetchDescriptor<Gym>()).map(\.id), [gymID])
        XCTAssertEqual(try c.fetchCount(FetchDescriptor<WorkoutSession>()), 1)
        XCTAssertEqual(RockLogMigrationPlan.fallbackCount.withLock { $0 }, before, "A V3 store must open through the plan, not the fallback.")
    }

    // MARK: - CloudKit sync off for the first TestFlight build (Lee, Oct 30)

    func test_cloudKitSyncOff_storeConfigurationHasNoCloudKit() {
        XCTAssertFalse(AppConfig.cloudKitSyncEnabled)
        XCTAssertFalse(CloudKitSyncService.isEnabled)
        let config = RockLogMigrationPlan.storeConfiguration(schema: Schema(versionedSchema: RockLogSchemaV3.self))
        XCTAssertNil(config.cloudKitContainerIdentifier, "Sync off must not attach a CloudKit container.")
        XCTAssertTrue(String(describing: config.cloudKitDatabase).lowercased().contains("none"), "\(config.cloudKitDatabase)")
    }

    @MainActor
    func test_cloudKitSyncOff_dataPersistsAcrossReopen_andBackupRoundTrips() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rocklog-nosync-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("RockLog.store")
        let schema = Schema(versionedSchema: RockLogSchemaV3.self)
        let setID = UUID()
        container = try RockLogMigrationPlan.openContainer(for: schema, configurations: [RockLogMigrationPlan.storeConfiguration(schema: schema, url: url)])
        do {
            let c = container!.mainContext
            let exercise = Exercise.make(name: "Synthetic Row", dayType: DayType(rawValue: "Pull"), muscleGroup: "Back", sortOrder: 0, isCustom: true, rotationTrack: .a)
            let session = WorkoutSession(dayType: DayType(rawValue: "Pull"))
            session.isCompleted = true
            let record = ExerciseRecord(trainingMode: .highWeightLowReps)
            record.session = session
            record.exercise = exercise
            let set = SetRecord(setNumber: 1, weightLbs: 95, reps: 10, isWarmup: false, isEachSide: false, isAssisted: false, isTarget: false)
            set.id = setID
            set.exerciseRecord = record
            c.insert(exercise); c.insert(session); c.insert(record); c.insert(set)
            try c.save()
        }
        container = nil
        // Relaunch: same file, same sync-off configuration.
        container = try RockLogMigrationPlan.openContainer(for: schema, configurations: [RockLogMigrationPlan.storeConfiguration(schema: schema, url: url)])
        let c = container!.mainContext
        XCTAssertEqual(try c.fetch(FetchDescriptor<SetRecord>()).map(\.id), [setID])
        XCTAssertEqual(try c.fetch(FetchDescriptor<SetRecord>()).first?.exerciseRecord?.exercise?.name, "Synthetic Row")

        // Backup: export, wipe by restoring into a second sync-off store, compare.
        let backup = try BackupService.export(context: c)
        let url2 = directory.appendingPathComponent("Restored.store")
        let second = try RockLogMigrationPlan.openContainer(for: schema, configurations: [RockLogMigrationPlan.storeConfiguration(schema: schema, url: url2)])
        try BackupService.restore(from: backup, context: second.mainContext)
        let restored = try second.mainContext.fetch(FetchDescriptor<SetRecord>())
        XCTAssertEqual(restored.map(\.id), [setID])
        XCTAssertEqual(restored.first?.weightLbs, 95)
        XCTAssertEqual(restored.first?.reps, 10)
        XCTAssertEqual(try second.mainContext.fetchCount(FetchDescriptor<WorkoutSession>()), 1)
    }

    func test_fallbackFilter_acceptsOnly134504() {
        XCTAssertTrue(RockLogMigrationPlan.isUnknownModelVersion(NSError(domain: NSCocoaErrorDomain, code: 134504)))
        XCTAssertFalse(RockLogMigrationPlan.isUnknownModelVersion(NSError(domain: NSCocoaErrorDomain, code: 134110)))
        XCTAssertFalse(RockLogMigrationPlan.isUnknownModelVersion(NSError(domain: NSCocoaErrorDomain, code: 134100)))
        XCTAssertFalse(RockLogMigrationPlan.isUnknownModelVersion(NSError(domain: "Other", code: 134504)))
        XCTAssertFalse(RockLogMigrationPlan.isUnknownModelVersion(CocoaError(.fileReadNoPermission)))
    }

    func test_v2Store_usesFallback_for134504Only() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rocklog-v2-fb-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("RockLog.store")
        try writeVersionedV2Workout(url: url, exerciseID: UUID(), setID: UUID())
        let before = RockLogMigrationPlan.fallbackCount.withLock { $0 }
        try open(schema: Schema(versionedSchema: RockLogSchemaV3.self), url: url, migrationPlan: true)
        XCTAssertEqual(RockLogMigrationPlan.fallbackCount.withLock { $0 }, before + 1)
    }

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


    // MARK: One-stage plan: rich synthetic V1 and V2 stores open as V3.

    func test_oneStagePlan_listsOnlyV1AndV3() {
        XCTAssertEqual(RockLogMigrationPlan.schemas.count, 2)
        XCTAssertEqual(RockLogMigrationPlan.stages.count, 1)
    }

    func test_richV1Store_opensAsV3_preservingCountsDatesAndRelationships() throws {
        try assertRichStoreOpensAsV3(writer: RockLogSchemaV1.self, withGym: false)
    }

    func test_richV2Store_opensAsV3_preservingCountsDatesUnitsAndRelationships() throws {
        try assertRichStoreOpensAsV3(writer: RockLogSchemaV2.self, withGym: true)
    }

    private func assertRichStoreOpensAsV3(writer: any VersionedSchema.Type, withGym: Bool) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rocklog-rich-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("RockLog.store")
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let blockID = UUID(), gymID = UUID()
        var exerciseIDs: [UUID] = [], sessionIDs: [UUID] = [], setWeights: [UUID: (Double, Int, Date, Bool)] = [:]
        do {
            try open(schema: Schema(versionedSchema: writer), url: url, migrationPlan: false)
            let c = container!.mainContext
            let block = RockLogSchemaV2.TrainingBlock(name: "Synthetic Block", startDate: base, notes: "n")
            block.id = blockID
            c.insert(block)
            var exercises: [RockLogSchemaV2.Exercise] = []
            for e in 0..<3 {
                let ex = RockLogSchemaV2.Exercise(name: "Synthetic Lift \(e)", dayType: .push, muscleGroup: "Chest", sortOrder: e, isCustom: true)
                c.insert(ex); exercises.append(ex); exerciseIDs.append(ex.id)
            }
            for d in 0..<4 {
                let session = RockLogSchemaV2.WorkoutSession(dayType: .push, date: base.addingTimeInterval(Double(d) * 86_400))
                session.isCompleted = true
                session.trainingBlock = block
                if withGym { session.gymID = gymID; session.gymName = "Synthetic Gym" }
                c.insert(session); sessionIDs.append(session.id)
                for (k, ex) in exercises.enumerated() {
                    let r = RockLogSchemaV2.ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: k)
                    r.exercise = ex; r.session = session; c.insert(r)
                    for n in 1...2 {
                        let w = 100 + Double(d * 10 + k) + 0.25
                        let set = RockLogSchemaV2.SetRecord(setNumber: n, weightLbs: w, reps: 5 + n)
                        set.completedAt = session.date.addingTimeInterval(Double(n) * 60)
                        set.isWarmup = n == 1
                        set.bodyWeightUsedLbs = withGym ? 181.5 : 0
                        set.exerciseRecord = r; c.insert(set)
                        setWeights[set.id] = (w, 5 + n, set.completedAt, n == 1)
                    }
                }
            }
            c.insert(RockLogSchemaV2.BodyMetricEntry(kind: .weight, value: 181.5, date: base, note: ""))
            if withGym {
                let gym = RockLogSchemaV2.Gym(name: "Synthetic Gym", isHome: true)
                gym.id = gymID; c.insert(gym)
                let p = RockLogSchemaV2.MachineStackProfile(gymID: gymID, exerciseID: exerciseIDs[0])
                p.pinsRaw = "20,22.5"; p.pinUnitRaw = "kg"; p.stepPounds = 5; c.insert(p)
            }
            try c.save()
            container = nil
        }

        try open(schema: Schema(versionedSchema: RockLogSchemaV3.self), url: url, migrationPlan: true)
        let c = container!.mainContext
        XCTAssertEqual(Set(try c.fetch(FetchDescriptor<Exercise>()).map(\.id)), Set(exerciseIDs))
        let sessions = try c.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(Set(sessions.map(\.id)), Set(sessionIDs))
        XCTAssertTrue(sessions.allSatisfy { $0.trainingBlock?.id == blockID })
        XCTAssertEqual(sessions.map { $0.exerciseRecords?.count ?? 0 }, Array(repeating: 3, count: 4))
        let sets = try c.fetch(FetchDescriptor<SetRecord>())
        XCTAssertEqual(sets.count, 24)
        for set in sets {
            guard let want = setWeights[set.id] else { XCTFail("unknown set"); continue }
            XCTAssertEqual(set.weightLbs, want.0, accuracy: 0.0001)
            XCTAssertEqual(set.reps, want.1)
            XCTAssertEqual(set.completedAt.timeIntervalSince1970, want.2.timeIntervalSince1970, accuracy: 0.001)
            XCTAssertEqual(set.isWarmup, want.3)
            XCTAssertEqual(set.enteredUnitRaw, "")
            XCTAssertNotNil(set.exerciseRecord?.exercise)
            XCTAssertNotNil(set.exerciseRecord?.session)
            if withGym { XCTAssertEqual(set.bodyWeightUsedLbs, 181.5, accuracy: 0.0001) }
        }
        XCTAssertEqual(try c.fetchCount(FetchDescriptor<BodyMetricEntry>()), 1)
        XCTAssertEqual(try c.fetch(FetchDescriptor<TrainingBlock>()).first?.startDate, base)
        if withGym {
            XCTAssertTrue(sessions.allSatisfy { $0.gymID == gymID })
            let gyms = try c.fetch(FetchDescriptor<Gym>())
            XCTAssertEqual(gyms.map(\.id), [gymID])
            let profiles = try c.fetch(FetchDescriptor<MachineStackProfile>())
            XCTAssertEqual(profiles.first?.pinUnitRaw, "kg")
            XCTAssertEqual(profiles.first?.pinsRaw, "20,22.5")
            XCTAssertEqual(profiles.first?.exerciseID, exerciseIDs[0])
        } else {
            XCTAssertTrue(try c.fetch(FetchDescriptor<Gym>()).isEmpty)
        }
        print("PRETF_47_RICH \(withGym ? "V2" : "V1")->V3 ok exercises=\(exerciseIDs.count) sessions=\(sessions.count) sets=\(sets.count)")
    }

    private func open(schema: Schema, url: URL, migrationPlan: Bool) throws {
        let config = ModelConfiguration(
            "RockLogSchema-\(UUID().uuidString)",
            schema: schema,
            url: url,
            cloudKitDatabase: .none
        )
        if migrationPlan {
            container = try RockLogMigrationPlan.openContainer(
                for: schema,
                configurations: [config]
            )
        } else {
            container = try ModelContainer(for: schema, configurations: [config])
        }
    }
}
