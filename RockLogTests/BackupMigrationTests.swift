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
final class BackupMigrationTests: RockLogStoreTestCase {

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

    func test_restCopy_isSafeToRunTwice_andRollsBackWithTheSave() throws {
        let exercise = Exercise(name: "Curl", dayType: .push, muscleGroup: "Biceps", isCustom: true)
        let key = RestPreferenceMigration.legacyKey(for: exercise.id)
        UserDefaults.standard.set(false, forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }
        XCTAssertTrue(RestPreferenceMigration.copyIfNeeded(exercise))
        XCTAssertFalse(exercise.autoRestEnabled)
        exercise.autoRestEnabled = true
        XCTAssertFalse(RestPreferenceMigration.copyIfNeeded(exercise))
        XCTAssertTrue(exercise.autoRestEnabled)

        let context = container.mainContext
        let keeper = Exercise(name: "Keep Me", dayType: .push, muscleGroup: "Chest", isCustom: true)
        context.insert(keeper)
        try context.save()
        let incomingID = UUID(uuidString: "99999999-9999-4999-8999-999999999999")!
        UserDefaults.standard.set(false, forKey: RestPreferenceMigration.legacyKey(for: incomingID))
        defer { UserDefaults.standard.removeObject(forKey: RestPreferenceMigration.legacyKey(for: incomingID)) }
        let payload = Data("""
        {"version":1,"exportedAt":"2026-01-01T00:00:00Z","exercises":[
        {"id":"\(incomingID.uuidString)","name":"Incoming","dayType":"Push","muscleGroup":"Chest","sortOrder":0,"isCustom":true,"notes":""}
        ],"sessions":[],"splitDays":[]}
        """.utf8)

        struct InjectedSaveFailure: Error {}
        XCTAssertThrowsError(
            try BackupService.restore(from: payload, context: context) { _ in throw InjectedSaveFailure() }
        )
        let afterFailure = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(afterFailure.map(\.name), ["Keep Me"])

        try BackupService.restore(from: payload, context: context)
        let incoming = try XCTUnwrap(try context.fetch(FetchDescriptor<Exercise>()).first { $0.id == incomingID })
        XCTAssertFalse(incoming.autoRestEnabled)
        XCTAssertTrue(incoming.autoRestCopied)
        incoming.autoRestEnabled = true
        XCTAssertFalse(RestPreferenceMigration.copyIfNeeded(incoming))
        XCTAssertTrue(incoming.autoRestEnabled)
    }

    func test_orphanedGroup_isClearedOnRestore() throws {
        let context = container.mainContext
        let json = Data("""
        {"version":2,"exportedAt":"2026-01-01T00:00:00Z","exercises":[
        {"id":"11111111-1111-4111-8111-111111111111","name":"A","dayType":"Push","muscleGroup":"Chest","sortOrder":0,"isCustom":true,"notes":""},
        {"id":"22222222-2222-4222-8222-222222222222","name":"B","dayType":"Push","muscleGroup":"Chest","sortOrder":1,"isCustom":true,"notes":""},
        {"id":"33333333-3333-4333-8333-333333333333","name":"C","dayType":"Push","muscleGroup":"Chest","sortOrder":2,"isCustom":true,"notes":""}
        ],"sessions":[{"id":"44444444-4444-4444-8444-444444444444","date":"2026-01-02T00:00:00Z","dayType":"Push","notes":"","isCompleted":false,"exerciseRecords":[
        {"id":"55555555-5555-4555-8555-555555555555","exerciseID":"11111111-1111-4111-8111-111111111111","trainingMode":"Strength","sortOrder":0,"isCompleted":false,"notes":"","sets":[],"groupID":"AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA","groupPosition":1},
        {"id":"66666666-6666-4666-8666-666666666666","exerciseID":"22222222-2222-4222-8222-222222222222","trainingMode":"Strength","sortOrder":1,"isCompleted":false,"notes":"","sets":[],"groupID":"AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA","groupPosition":2},
        {"id":"77777777-7777-4777-8777-777777777777","exerciseID":"33333333-3333-4333-8333-333333333333","trainingMode":"Strength","sortOrder":2,"isCompleted":false,"notes":"","sets":[],"groupID":"BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB","groupPosition":1}
        ]}],"splitDays":[]}
        """.utf8)
        let report = try BackupService.restore(from: json, context: context)
        XCTAssertEqual(report.orphanedGroupIDs, [UUID(uuidString: "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB")!])
        let records = try context.fetch(FetchDescriptor<ExerciseRecord>())
        let kept = records.filter { $0.groupID != nil }
        XCTAssertEqual(kept.count, 2)
        XCTAssertTrue(kept.allSatisfy { $0.groupID == UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA") })
    }

    func test_exportRestoreExport_matchesApartFromExportedAt() throws {
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

    func test_missingVersion_decodesAsVersionOne() throws {
        let fixture = Data("""
        {"exportedAt":"2026-01-01T00:00:00Z","exercises":[],"sessions":[],"labNote":"synthetic-old"}
        """.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AppBackup.self, from: fixture)
        XCTAssertEqual(decoded.version, 1)
        let opened = try BackupService.open(fixture)
        XCTAssertEqual(opened.backup.version, BackupMigration.currentVersion)
        XCTAssertTrue(opened.backup.exercises.isEmpty)
        XCTAssertTrue(opened.backup.sessions.isEmpty)
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
