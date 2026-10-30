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
        let exercise = Exercise.make(name: "Curl", dayType: .push, muscleGroup: "Biceps", isCustom: true)
        let key = RestPreferenceMigration.legacyKey(for: exercise.id)
        UserDefaults.standard.set(false, forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }
        XCTAssertTrue(RestPreferenceMigration.copyIfNeeded(exercise))
        XCTAssertFalse(exercise.autoRestEnabled)
        exercise.autoRestEnabled = true
        XCTAssertFalse(RestPreferenceMigration.copyIfNeeded(exercise))
        XCTAssertTrue(exercise.autoRestEnabled)

        let context = container.mainContext
        let keeper = Exercise.make(name: "Keep Me", dayType: .push, muscleGroup: "Chest", isCustom: true)
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
        let exercise = Exercise.make(name: "Synthetic Press", dayType: .push, muscleGroup: "Chest", isCustom: true)
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

// MARK: - Pre-TestFlight break tests (checklist 52, 53, 57, 60). Synthetic data only.

@MainActor
final class PreTestFlightBreakTests: RockLogStoreTestCase {
    /// Emoji (ZWJ + skin tone + flag), RTL Hebrew/Arabic, an RTL override,
    /// NFD combining marks, zero-width space/joiner, and a CJK name.
    static let unicodeNames: [String] = [
        "Bench 👨🏽‍🦰💪🏿🇮🇱",
        "לחיצת חזה",
        "ضغط الصدر",
        "Pre\u{202E}ss\u{202C} RLO",
        "Cafe\u{0301} Squa\u{0308}t Z\u{0335}\u{0336}algo\u{0489}",
        "Zero\u{200B}Width\u{200D}Joiner\u{FEFF}",
        "深蹲 スクワット",
    ]

    private func seedUnicode(_ context: ModelContext) throws {
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        for (index, name) in Self.unicodeNames.enumerated() {
            let exercise = Exercise.make(name: name, dayType: .push, muscleGroup: "Chest", isCustom: true)
            exercise.notes = "note " + name
            let session = WorkoutSession(dayType: .push, date: stamp.addingTimeInterval(Double(index) * 86_400))
            session.notes = "s " + name
            session.isCompleted = true
            let record = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
            record.exercise = exercise
            record.session = session
            let set = SetRecord(setNumber: 1, weightLbs: 100, reps: 5)
            set.completedAt = stamp
            set.exerciseRecord = record
            record.sets = [set]
            session.exerciseRecords = [record]
            context.insert(exercise); context.insert(session); context.insert(record); context.insert(set)
        }
        let metric = BodyMetricEntry(kind: .weight, value: 180, date: stamp, note: Self.unicodeNames[0])
        context.insert(metric)
        try context.save()
    }

    private func counts(_ context: ModelContext) throws -> [Int] {
        [try context.fetchCount(FetchDescriptor<Exercise>()),
         try context.fetchCount(FetchDescriptor<WorkoutSession>()),
         try context.fetchCount(FetchDescriptor<SetRecord>()),
         try context.fetchCount(FetchDescriptor<BodyMetricEntry>())]
    }

    /// 57: names and notes survive export -> restore -> export byte-exact.
    func test_57_unicodeBackup_roundTripsByteExact() throws {
        let context = container.mainContext
        try seedUnicode(context)
        let first = try BackupService.export(context: context)
        try BackupService.restore(from: first, context: context)
        let names = try context.fetch(FetchDescriptor<Exercise>()).filter(\.isCustom).map { Array($0.name.utf8) }
        for expected in Self.unicodeNames {
            XCTAssertTrue(names.contains(Array(expected.utf8)), "lost or normalized: \(expected.unicodeScalars.map { String($0.value, radix: 16) })")
        }
        let notes = try context.fetch(FetchDescriptor<WorkoutSession>()).map { Array($0.notes.utf8) }
        for expected in Self.unicodeNames {
            XCTAssertTrue(notes.contains(Array(("s " + expected).utf8)))
        }
        let second = try BackupService.export(context: context)
        let a = try BackupService.open(first).backup, b = try BackupService.open(second).backup
        XCTAssertEqual(Set(a.exercises.map { Array($0.name.utf8) }), Set(b.exercises.map { Array($0.name.utf8) }))
        print("PRETF_57_UNICODE_BACKUP ok names=\(Self.unicodeNames.count) bytes=\(first.count)")
    }

    /// 57: a program file with unicode lift names imports byte-exact.
    func test_57_unicodeProgramImport_byteExact() throws {
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let exercises = Self.unicodeNames.map { name in
            ProgramExercisePayload(id: UUID(), name: name, muscleGroup: "Chest", trainingMode: "Strength", notes: "n " + name,
                                   sets: [ProgramSetPayload(setNumber: 1, weightLbs: 95, reps: 8, isWarmup: false, isEachSide: false, isAssisted: false)])
        }
        let doc = ProgramDocument(format: ProgramFormat.formatName, schemaVersion: ProgramFormat.schemaVersion,
                                  exportedAt: start,
                                  block: ProgramBlockPayload(id: UUID(), name: "Blöck ✨ בלוק", notes: "synthetic", startDate: start,
                                                             sessions: [ProgramSessionPayload(id: UUID(), date: start, dayType: "Push", rotationTrack: "A", notes: "🏋️‍♀️", exercises: exercises)]))
        let data = try ProgramCodec.encode(doc)
        let decoded = try ProgramCodec.decode(data)
        _ = try ProgramImportService.importDocument(decoded, context: context)
        let names = try context.fetch(FetchDescriptor<Exercise>()).map { Array($0.name.utf8) }
        for expected in Self.unicodeNames {
            XCTAssertTrue(names.contains(Array(expected.utf8)), "program lost: \(expected)")
        }
        print("PRETF_57_UNICODE_PROGRAM ok")
    }

    /// 53 / 60: a truncated file (cut at 10/50/90 %), empty file and a
    /// mid-restore save failure all leave the store unchanged.
    func test_53_60_truncatedOrInterruptedRestore_leavesStoreUnchanged() throws {
        let context = container.mainContext
        try seedUnicode(context)
        let before = try counts(context)
        let good = try BackupService.export(context: context)
        for fraction in [0.1, 0.5, 0.9, 0.999] {
            let cut = good.prefix(Int(Double(good.count) * fraction))
            XCTAssertThrowsError(try BackupService.restore(from: Data(cut), context: context), "cut \(fraction)")
            XCTAssertEqual(try counts(context), before, "store changed after cut \(fraction)")
        }
        XCTAssertThrowsError(try BackupService.restore(from: Data(), context: context))
        XCTAssertEqual(try counts(context), before)

        struct Boom: Error {}
        XCTAssertThrowsError(try BackupService.restore(from: good, context: context, persisting: { _ in throw Boom() }))
        XCTAssertEqual(try counts(context), before, "store changed after failed save")
        let names = try context.fetch(FetchDescriptor<Exercise>()).map { Array($0.name.utf8) }
        XCTAssertTrue(names.contains(Array(Self.unicodeNames[0].utf8)))
        print("PRETF_53_60_TRUNCATED ok counts=\(before)")
    }

    /// 52: a ~100 MB synthetic backup. Pass = no crash and either a clean
    /// refusal or a complete restore. Prints size, time and resident memory.
    func test_52_hundredMegabyteBackup_noCrash() throws {
        // Heavy (~36 s, ~2.2 GB resident on the simulator). Opt-in so Xcode Cloud
        // and the normal suite stay fast: TEST_RUNNER_ROCKLOG_HEAVY_BREAK=1.
        try XCTSkipUnless(ProcessInfo.processInfo.environment["ROCKLOG_HEAVY_BREAK"] == "1", "set ROCKLOG_HEAVY_BREAK=1 to run")
        let context = container.mainContext
        try seedUnicode(context)
        let seed = try BackupService.export(context: context)
        var root = try JSONSerialization.jsonObject(with: seed) as! [String: Any]
        let inPayload = root["payload"] is [String: Any]
        var body = inPayload ? root["payload"] as! [String: Any] : root
        let template = (body["sessions"] as! [[String: Any]])[0]
        let filler = String(repeating: "synthetic filler ", count: 290)   // ~4.9 KB
        func fresh(_ value: Any) -> Any {
            if var dict = value as? [String: Any] {
                for (key, inner) in dict { dict[key] = key == "id" ? UUID().uuidString : fresh(inner) }
                return dict
            }
            if let array = value as? [Any] { return array.map(fresh) }
            return value
        }
        var sessions: [[String: Any]] = []
        let target = 20_000
        sessions.reserveCapacity(target)
        for i in 0..<target {
            var s = fresh(template) as! [String: Any]
            s["notes"] = "#\(i) " + filler
            sessions.append(s)
        }
        body["sessions"] = sessions
        body.removeValue(forKey: "trainingBlocks")
        if inPayload { root["payload"] = body } else { root = body }
        let big = try JSONSerialization.data(withJSONObject: root)
        sessions.removeAll()
        let mb = Double(big.count) / 1_048_576
        let rssBefore = Self.residentMB()
        let t0 = Date()
        var outcome = "restored"
        do {
            try BackupService.restore(from: big, context: context)
            let n = try context.fetchCount(FetchDescriptor<WorkoutSession>())
            outcome = "restored sessions=\(n)"
            XCTAssertEqual(n, target)
        } catch {
            outcome = "refused: \(String(describing: error).prefix(160))"
        }
        let secs = Date().timeIntervalSince(t0)
        print(String(format: "PRETF_52_100MB size_mb=%.1f secs=%.1f rss_before_mb=%.0f rss_after_mb=%.0f outcome=%@",
                     mb, secs, rssBefore, Self.residentMB(), outcome))
        XCTAssertGreaterThan(mb, 95)
    }

    static func residentMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return kr == KERN_SUCCESS ? Double(info.resident_size) / 1_048_576 : -1
    }
}
