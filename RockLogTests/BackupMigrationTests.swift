//
//  BackupMigrationTests.swift
//  RockLogTests
//
//  Synthetic files only. v1 promotes to v2, bad versions are refused,
//  unknown keys are counted, and an export restores to the same export.
//

import XCTest
import SwiftData
@testable import RockLog

@MainActor
final class BackupMigrationTests: XCTestCase {

    func test_v1PromotesToV2_withoutInventingRowsOrDroppingKeys() throws {
        let raw = try InterchangeCodec.parseObject(v1Sample)
        let promoted = try BackupMigration.promoteToCurrent(raw)
        XCTAssertEqual(promoted["version"]?.int, 2)
        XCTAssertEqual(promoted["labNote"]?.string, "synthetic")
        XCTAssertNil(promoted["gyms"])
        XCTAssertNil(promoted["stackProfiles"])
        let again = try BackupMigration.promoteToCurrent(promoted)
        XCTAssertEqual(again, promoted)
    }

    func test_v0AndFutureVersionsAreRefused() throws {
        XCTAssertThrowsError(try BackupService.open(versionJSON(0))) { error in
            guard case BackupError.unsupportedVersion(0) = error else {
                return XCTFail("expected version 0, got \(error)")
            }
        }
        XCTAssertThrowsError(try BackupService.open(versionJSON(3))) { error in
            guard case BackupError.unsupportedVersion(3) = error else {
                return XCTFail("expected version 3, got \(error)")
            }
        }
    }

    func test_duplicateUUIDsAreRefused_andCaseDoesNotMakeASecondID() throws {
        XCTAssertThrowsError(try BackupService.open(duplicateExerciseJSON)) { error in
            guard case BackupError.invalidBackup = error else {
                return XCTFail("expected invalidBackup, got \(error)")
            }
        }
    }

    func test_unknownKeysAndEnumsAreCounted() throws {
        let opened = try BackupService.open(v1Sample)
        XCTAssertGreaterThan(opened.inspection.unknownKeyCount, 0)
        XCTAssertTrue(opened.inspection.unknownKeyPaths.contains("labNote"))
        XCTAssertGreaterThan(opened.inspection.unknownEnumCount, 0)
        XCTAssertEqual(opened.backup.sessions[0].exerciseRecords[0].trainingMode, "Turbo")
        XCTAssertEqual(opened.backup.exercises[0].suggestWarmupRamp, nil)
        let weight = opened.backup.sessions[1].exerciseRecords[0].sets[0].weightLbs
        XCTAssertEqual(weight, 135.125, accuracy: 0.000_000_1)
    }

    func test_clearTimeAndPinUnit_surviveTheCodec() throws {
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        let profile = StackProfileBackup(
            id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
            gymID: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
            exerciseID: UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!,
            stepPounds: 0,
            pinsRaw: "20,22.5",
            pinUnitRaw: "kg",
            addOnsRaw: "",
            policyRaw: "nearest",
            originRaw: "typed",
            learnedSessionIDsRaw: "",
            clearedAt: stamp,
            learningEnabled: false,
            rangeMin: 0,
            rangeMax: 0,
            updatedAt: stamp
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let round = try decoder.decode(StackProfileBackup.self, from: encoder.encode(profile))
        XCTAssertEqual(round.clearedAt, stamp)
        XCTAssertEqual(round.pinsRaw, "20,22.5")
        XCTAssertEqual(round.pinUnitRaw, "kg")
        XCTAssertEqual(round.updatedAt, stamp)
    }

    func test_exportRestoreExport_matchesApartFromExportedAt() throws {
        let container = try store()
        let context = container.mainContext
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        let exercise = Exercise(name: "Synthetic Press", dayType: .push, muscleGroup: "Chest", isCustom: true)
        exercise.notes = "keep"
        exercise.defaultRestSeconds = 90
        let session = WorkoutSession(dayType: .push, date: stamp)
        session.notes = "session"
        session.isCompleted = true
        let record = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
        record.exercise = exercise
        record.session = session
        let set = SetRecord(setNumber: 1, weightLbs: 135.125, reps: 5)
        set.completedAt = stamp
        set.bodyWeightUsedLbs = 181.25
        set.exerciseRecord = record
        record.sets = [set]
        session.exerciseRecords = [record]
        let block = TrainingBlock(name: "Synthetic Block", startDate: stamp, notes: "block")
        block.importedAt = stamp
        session.trainingBlock = block
        let metric = BodyMetricEntry(kind: .weight, value: 181.25, date: stamp, note: "scale")
        let gym = Gym(name: "Home", isHome: true, sortOrder: 0)
        gym.createdAt = stamp
        let profile = MachineStackProfile(gymID: gym.id, exerciseID: exercise.id)
        profile.pinsRaw = "20,22.5"
        profile.pinUnitRaw = "kg"
        profile.originRaw = "typed"
        profile.clearedAt = stamp
        profile.updatedAt = stamp
        profile.learningEnabled = false
        context.insert(exercise)
        context.insert(session)
        context.insert(record)
        context.insert(set)
        context.insert(block)
        context.insert(metric)
        context.insert(gym)
        context.insert(profile)
        try context.save()

        let first = try BackupService.export(context: context)
        try BackupService.restore(from: first, context: context)
        let second = try BackupService.export(context: context)
        XCTAssertEqual(try canonical(first), try canonical(second))
        let restored = try BackupService.open(second)
        XCTAssertEqual(restored.backup.version, 2)
        XCTAssertEqual(restored.backup.stackProfiles?.first?.pinUnitRaw, "kg")
        XCTAssertEqual(restored.backup.stackProfiles?.first?.pinsRaw, "20,22.5")
        XCTAssertNotNil(restored.backup.stackProfiles?.first?.clearedAt)
        XCTAssertEqual(restored.backup.bodyMetrics?.count, 1)
        XCTAssertEqual(restored.backup.trainingBlocks?.count, 1)
        XCTAssertEqual(restored.backup.sessions.first?.exerciseRecords.first?.sets.first?.weightLbs ?? 0, 135.125, accuracy: 0.000_000_1)
    }

    private func canonical(_ data: Data) throws -> String {
        var object = try InterchangeCodec.parseObject(data)
        object.removeValue(forKey: "exportedAt")
        if var payload = object["payload"]?.object {
            payload.removeValue(forKey: "exportedAt")
            object["payload"] = .object(payload)
        }
        let encoded = try InterchangeCodec.encode(object)
        return String(decoding: encoded, as: UTF8.self)
    }

    private func store() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Exercise.self,
            WorkoutSession.self,
            ExerciseRecord.self,
            SetRecord.self,
            SplitDay.self,
            BodyMetricEntry.self,
            TrainingBlock.self,
            Gym.self,
            MachineStackProfile.self,
            configurations: config
        )
    }

    private func versionJSON(_ version: Int) -> Data {
        Data("""
        {"version":\(version),"exportedAt":"2026-01-01T00:00:00Z","exercises":[],"sessions":[]}
        """.utf8)
    }

    private var duplicateExerciseJSON: Data {
        let id = "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
        return Data("""
        {"version":1,"exportedAt":"2026-01-01T00:00:00Z","exercises":[
        {"id":"\(id)","name":"A","dayType":"Push","muscleGroup":"Chest","sortOrder":0,"isCustom":true,"notes":""},
        {"id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","name":"B","dayType":"Push","muscleGroup":"Chest","sortOrder":1,"isCustom":true,"notes":""}
        ],"sessions":[]}
        """.utf8)
    }

    /// Two sessions: the first log is an unknown mode and is counted, not stored.
    /// The second keeps a full-precision pound weight. `labNote` is an unknown key.
    private var v1Sample: Data {
        Data("""
        {"version":1,"exportedAt":"2026-01-01T00:00:00Z","labNote":"synthetic","exercises":[
        {"id":"11111111-1111-1111-1111-111111111111","name":"Synthetic Press","dayType":"Push","muscleGroup":"Chest","sortOrder":0,"isCustom":true,"notes":""}
        ],"sessions":[
        {"id":"22222222-2222-2222-2222-222222222222","date":"2026-01-01T00:00:00Z","dayType":"Push","notes":"","isCompleted":true,"exerciseRecords":[
        {"id":"33333333-3333-3333-3333-333333333333","exerciseID":"11111111-1111-1111-1111-111111111111","trainingMode":"Turbo","sortOrder":0,"isCompleted":true,"notes":"","sets":[]}
        ]},
        {"id":"44444444-4444-4444-4444-444444444444","date":"2026-01-02T00:00:00Z","dayType":"Push","notes":"","isCompleted":true,"exerciseRecords":[
        {"id":"55555555-5555-5555-5555-555555555555","exerciseID":"11111111-1111-1111-1111-111111111111","trainingMode":"Strength","sortOrder":0,"isCompleted":true,"notes":"","sets":[
        {"id":"66666666-6666-6666-6666-666666666666","setNumber":1,"weightLbs":135.125,"reps":5,"isWarmup":false,"completedAt":"2026-01-02T00:00:00Z"}
        ]}
        ]}
        ]}
        """.utf8)
    }
}
