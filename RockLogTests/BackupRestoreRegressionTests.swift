//
//  BackupRestoreRegressionTests.swift
//  RockLogTests
//
//  Round-trip and failure tests for BackupService. Each case is named
//  after the QA bug it locks in.
//

import XCTest
import SwiftData
@testable import RockLog

@MainActor
final class BackupRestoreRegressionTests: RockLogStoreTestCase {

    override func setUp() async throws {
        try await super.setUp()
        let defaults = UserDefaults.standard
        let kvs = NSUbiquitousKeyValueStore.default
        for key in [
            SeedData.hasConfiguredSplitKey,
            SeedData.preferredSplitPresetKey,
            SeedData.splitSnapshotKey,
            SeedData.dayPlanSnapshotKey,
            SeedData.hasSeededExercisesKey,
            SeedData.strippedUnusedStarterExtrasKey,
        ] {
            defaults.removeObject(forKey: key)
            kvs.removeObject(forKey: key)
        }
    }

    // MARK: - B3

    /// A save failure after the deletes are staged must not commit them.
    func test_b3_restoreSaveFailure_rollsBackToOriginalRows() throws {
        let context = container.mainContext
        let originalExercise = Exercise.make(
            name: "Keep Me",
            dayType: .push,
            muscleGroup: "Chest",
            isCustom: true
        )
        let originalDay = SplitDay(
            name: "Original Day",
            systemImage: "dumbbell.fill",
            subtitle: "stay",
            colorHex: 0x112233,
            includesAllExercises: false,
            sortOrder: 0
        )
        context.insert(originalExercise)
        context.insert(originalDay)
        try context.save()
        let originalExerciseID = originalExercise.id
        let originalDayID = originalDay.id

        let incomingExerciseID = UUID()
        let incomingDayID = UUID()
        let backup = AppBackup(
            version: BackupService.currentVersion,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            exercises: [
                ExerciseBackup(
                    id: incomingExerciseID,
                    name: "Incoming",
                    dayType: "Push",
                    muscleGroup: "Chest",
                    sortOrder: 0,
                    isCustom: true,
                    notes: ""
                ),
            ],
            sessions: [],
            splitDays: [
                SplitDayBackup(
                    id: incomingDayID,
                    name: "Incoming Day",
                    systemImage: "figure.walk",
                    subtitle: "replace",
                    colorHex: 0x445566,
                    includesAllExercises: false,
                    sortOrder: 0
                ),
            ]
        )

        struct InjectedSaveFailure: Error {}
        XCTAssertThrowsError(
            try BackupService.restore(from: try encode(backup), context: context) { _ in
                throw InjectedSaveFailure()
            }
        )

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(exercises.map(\.id), [originalExerciseID])
        XCTAssertEqual(exercises.map(\.name), ["Keep Me"])

        let days = try context.fetch(FetchDescriptor<SplitDay>())
        XCTAssertEqual(days.map(\.id), [originalDayID])
        XCTAssertEqual(days.map(\.name), ["Original Day"])
        XCTAssertFalse(days.contains { $0.name == "Incoming Day" })

        let after = Exercise.make(name: "After Rollback", dayType: .push, muscleGroup: "Chest", isCustom: true)
        context.insert(after)
        try context.save()
        let names = try context.fetch(FetchDescriptor<Exercise>()).map(\.name).sorted()
        XCTAssertEqual(names, ["After Rollback", "Keep Me"])
    }

    /// Settings is destroyed while the store is replaced. The summary has to
    /// live on the root, or the Success alert never appears.
    func test_restoreNotice_keepsTheSummaryAfterSettingsIsGone() {
        RestoreNotice.shared.dismiss()
        RestoreNotice.shared.present("Replaced the split and exercises.")
        XCTAssertEqual(RestoreNotice.shared.message, "Replaced the split and exercises.")
        RestoreNotice.shared.dismiss()
        XCTAssertNil(RestoreNotice.shared.message)
    }

    // MARK: - B1

    func test_b1_trainingBlock_survivesExportRestore() throws {
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let imported = Date(timeIntervalSince1970: 1_700_086_400)
        let sessionDate = Date(timeIntervalSince1970: 1_700_172_800)
        let block = TrainingBlock(name: "Hypertrophy", startDate: start, notes: "8 weeks")
        block.importedAt = imported
        let session = WorkoutSession(dayType: .push, date: sessionDate)
        session.isCompleted = false
        session.planOrder = 2
        session.trainingBlock = block
        context.insert(block)
        context.insert(session)
        try context.save()

        let data = try BackupService.export(context: context)
        let decoded = try BackupService.decode(data)
        XCTAssertEqual(decoded.trainingBlocks?.count, 1)
        XCTAssertEqual(decoded.trainingBlocks?.first?.name, "Hypertrophy")
        XCTAssertEqual(decoded.trainingBlocks?.first?.sessionIDs, [session.id])

        try BackupService.restore(from: data, context: context)

        let blocks = try context.fetch(FetchDescriptor<TrainingBlock>())
        XCTAssertEqual(blocks.count, 1)
        let restored = try XCTUnwrap(blocks.first)
        XCTAssertEqual(restored.id, block.id)
        XCTAssertEqual(restored.name, "Hypertrophy")
        XCTAssertEqual(restored.notes, "8 weeks")
        XCTAssertEqual(restored.startDate.timeIntervalSince1970, start.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(restored.importedAt.timeIntervalSince1970, imported.timeIntervalSince1970, accuracy: 1)
        let restoredSessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(restoredSessions.count, 1)
        XCTAssertEqual(restoredSessions.first?.id, session.id)
        XCTAssertEqual(restoredSessions.first?.trainingBlock?.id, restored.id)
        XCTAssertEqual(restored.sessionsArray.map(\.id), [session.id])
    }

    func test_b1_backupWithoutTrainingBlocks_stillLoadsAndKeepsExistingProgram() throws {
        let context = container.mainContext
        let block = TrainingBlock(
            name: "Keep Program",
            startDate: Date(timeIntervalSince1970: 1_600_000_000),
            notes: "pre-field"
        )
        context.insert(block)
        context.insert(Exercise.make(name: "Old Lift", dayType: .push, muscleGroup: "Chest", isCustom: true))
        try context.save()
        let blockID = block.id

        let exerciseID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let json = """
        {
          "version": 1,
          "exportedAt": "2026-01-01T00:00:00Z",
          "exercises": [
            {
              "id": "\(exerciseID.uuidString)",
              "name": "From Old File",
              "dayType": "Push",
              "muscleGroup": "Chest",
              "sortOrder": 0,
              "isCustom": true,
              "notes": ""
            }
          ],
          "sessions": []
        }
        """
        let data = Data(json.utf8)
        let decoded = try BackupService.decode(data)
        XCTAssertNil(decoded.trainingBlocks)

        try BackupService.restore(from: data, context: context)

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(exercises.map(\.name), ["From Old File"])
        let blocks = try context.fetch(FetchDescriptor<TrainingBlock>())
        XCTAssertEqual(blocks.map(\.id), [blockID])
        XCTAssertEqual(blocks.map(\.name), ["Keep Program"])
        XCTAssertEqual(blocks.map(\.notes), ["pre-field"])
    }

    func test_b1_emptyTrainingBlockArray_replacesExistingProgram() throws {
        let context = container.mainContext
        context.insert(TrainingBlock(name: "Going Away", startDate: Date(timeIntervalSince1970: 1_600_000_000)))
        try context.save()

        let json = """
        {
          "version": 1,
          "exportedAt": "2026-01-01T00:00:00Z",
          "exercises": [],
          "sessions": [],
          "trainingBlocks": []
        }
        """
        try BackupService.restore(from: Data(json.utf8), context: context)
        let blocks = try context.fetch(FetchDescriptor<TrainingBlock>())
        XCTAssertTrue(blocks.isEmpty)
    }

    // MARK: - B2

    func test_b2_bodyMetrics_surviveExportRestore() throws {
        let context = container.mainContext
        let morning = Date(timeIntervalSince1970: 1_700_200_000)
        let evening = Date(timeIntervalSince1970: 1_700_230_000)
        context.insert(BodyMetricEntry(kind: .weight, value: 185.5, date: morning, note: "fasted"))
        context.insert(BodyMetricEntry(kind: .waist, value: 33.25, date: evening, note: ""))
        try context.save()
        let originalIDs = try context.fetch(FetchDescriptor<BodyMetricEntry>())
            .sorted {
                if $0.date != $1.date { return $0.date < $1.date }
                return $0.kindRaw < $1.kindRaw
            }
            .map(\.id)
        XCTAssertEqual(originalIDs.count, 2)

        let data = try BackupService.export(context: context)
        let decoded = try BackupService.decode(data)
        XCTAssertEqual(decoded.bodyMetrics?.count, 2)

        try BackupService.restore(from: data, context: context)

        let restored = try context.fetch(FetchDescriptor<BodyMetricEntry>()).sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            return $0.kindRaw < $1.kindRaw
        }
        XCTAssertEqual(restored.count, 2)
        XCTAssertEqual(restored.map(\.kind), [.weight, .waist])
        XCTAssertEqual(restored.map(\.value), [185.5, 33.25])
        XCTAssertEqual(restored.map(\.note), ["fasted", ""])
        XCTAssertEqual(restored.map(\.id), originalIDs)
        XCTAssertEqual(restored[0].date.timeIntervalSince1970, morning.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(restored[1].date.timeIntervalSince1970, evening.timeIntervalSince1970, accuracy: 1)
    }

    func test_b2_backupWithoutBodyMetrics_stillLoadsAndKeepsExistingMeasurements() throws {
        let context = container.mainContext
        let entry = BodyMetricEntry(
            kind: .neck,
            value: 15.5,
            date: Date(timeIntervalSince1970: 1_600_000_000),
            note: "keep"
        )
        context.insert(entry)
        try context.save()

        let json = """
        {
          "version": 1,
          "exportedAt": "2026-01-01T00:00:00Z",
          "exercises": [],
          "sessions": []
        }
        """
        let decoded = try BackupService.decode(Data(json.utf8))
        XCTAssertNil(decoded.bodyMetrics)
        XCTAssertNil(decoded.trainingBlocks)

        try BackupService.restore(from: Data(json.utf8), context: context)
        let restored = try context.fetch(FetchDescriptor<BodyMetricEntry>())
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored.first?.id, entry.id)
        XCTAssertEqual(restored.first?.kind, .neck)
        XCTAssertEqual(restored.first?.value, 15.5)
        XCTAssertEqual(restored.first?.note, "keep")
    }

    func test_b2_emptyBodyMetricArray_replacesExistingMeasurements() throws {
        let context = container.mainContext
        context.insert(BodyMetricEntry(kind: .weight, value: 200, date: Date(timeIntervalSince1970: 1_600_000_000)))
        try context.save()

        let json = """
        {
          "version": 1,
          "exportedAt": "2026-01-01T00:00:00Z",
          "exercises": [],
          "sessions": [],
          "bodyMetrics": []
        }
        """
        try BackupService.restore(from: Data(json.utf8), context: context)
        let restored = try context.fetch(FetchDescriptor<BodyMetricEntry>())
        XCTAssertTrue(restored.isEmpty)
    }

    // MARK: - B4

    func test_b4_unknownTrainingMode_isCountedAndNotInserted() throws {
        let exerciseID = UUID()
        let keptRecordID = UUID()
        let droppedRecordID = UUID()
        let keptSetID = UUID()
        let droppedSetID = UUID()
        let when = Date(timeIntervalSince1970: 1_700_000_000)
        let backup = AppBackup(
            version: 1,
            exportedAt: when,
            exercises: [
                ExerciseBackup(
                    id: exerciseID,
                    name: "Bench",
                    dayType: "Push",
                    muscleGroup: "Chest",
                    sortOrder: 0,
                    isCustom: true,
                    notes: ""
                ),
            ],
            sessions: [
                WorkoutSessionBackup(
                    id: UUID(),
                    date: when,
                    dayType: "Push",
                    notes: "",
                    isCompleted: true,
                    exerciseRecords: [
                        ExerciseRecordBackup(
                            id: keptRecordID,
                            exerciseID: exerciseID,
                            trainingMode: "Strength",
                            sortOrder: 0,
                            isCompleted: true,
                            notes: "",
                            sets: [
                                SetRecordBackup(
                                    id: keptSetID,
                                    setNumber: 1,
                                    weightLbs: 185,
                                    reps: 5,
                                    isWarmup: false,
                                    completedAt: when
                                ),
                            ]
                        ),
                        ExerciseRecordBackup(
                            id: droppedRecordID,
                            exerciseID: exerciseID,
                            trainingMode: "bogus",
                            sortOrder: 1,
                            isCompleted: true,
                            notes: "",
                            sets: [
                                SetRecordBackup(
                                    id: droppedSetID,
                                    setNumber: 1,
                                    weightLbs: 95,
                                    reps: 12,
                                    isWarmup: false,
                                    completedAt: when
                                ),
                            ]
                        ),
                    ]
                ),
            ]
        )
        let data = try encode(backup)
        let decoded = try BackupService.decode(data)
        let summary = BackupService.summarize(backup: decoded)
        XCTAssertEqual(summary.droppedExerciseRecordCount, 1)
        XCTAssertEqual(summary.unknownTrainingModes, ["bogus"])
        let prompt = BackupService.restorePrompt(
            current: BackupSummary(splitDayNames: [], assignedExerciseCount: 0, exerciseCount: 0, sessionCount: 0),
            incoming: summary
        )
        XCTAssertTrue(prompt.message.contains("bogus"))
        XCTAssertTrue(prompt.message.contains("will be skipped"))

        let context = container.mainContext
        let report = try BackupService.restore(from: data, context: context)
        XCTAssertEqual(report.droppedExerciseRecords, 1)
        XCTAssertEqual(report.unknownTrainingModes, ["bogus"])
        XCTAssertTrue(report.userFacingSummary.contains("Skipped 1 exercise log"))
        XCTAssertTrue(report.userFacingSummary.contains("bogus"))

        let records = try context.fetch(FetchDescriptor<ExerciseRecord>())
        XCTAssertEqual(records.map(\.id), [keptRecordID])
        XCTAssertEqual(records.map(\.trainingMode), [.highWeightLowReps])
        let sets = try context.fetch(FetchDescriptor<SetRecord>())
        XCTAssertEqual(sets.map(\.id), [keptSetID])
        XCTAssertFalse(sets.contains { $0.id == droppedSetID })
    }

    // MARK: - B5

    func test_b5_versionZeroAndNegative_areRejected() throws {
        for version in [0, -1] {
            let json = """
            {"version":\(version),"exportedAt":"2026-01-01T00:00:00Z","exercises":[],"sessions":[]}
            """
            XCTAssertThrowsError(try BackupService.decode(Data(json.utf8))) { error in
                guard case BackupError.unsupportedVersion(let found) = error else {
                    return XCTFail("Expected unsupportedVersion, got \(error)")
                }
                XCTAssertEqual(found, version)
                XCTAssertTrue(error.localizedDescription.contains("version \(version)"))
            }
        }
    }

    func test_b5_negativeReps_areRejected() throws {
        let data = try encode(backupWithSet(weight: 100, reps: -1))
        XCTAssertThrowsError(try BackupService.decode(data)) { error in
            guard case BackupError.invalidBackup(let message) = error else {
                return XCTFail("Expected invalidBackup, got \(error)")
            }
            XCTAssertTrue(message.contains("reps -1"), message)
            XCTAssertTrue(message.contains("nothing was changed"), message)
        }
    }

    func test_b5_negativeAndAbsurdWeight_areRejected() throws {
        for weight in [-50.0, 1_000_000_000.0] {
            let data = try encode(backupWithSet(weight: weight, reps: 5))
            XCTAssertThrowsError(try BackupService.decode(data)) { error in
                guard case BackupError.invalidBackup(let message) = error else {
                    return XCTFail("Expected invalidBackup for \(weight), got \(error)")
                }
                XCTAssertTrue(message.contains("weight"), message)
                XCTAssertTrue(message.contains("nothing was changed"), message)
            }
        }
    }

    func test_b5_duplicateExerciseIDs_areRejected() throws {
        let shared = UUID()
        let backup = AppBackup(
            version: 1,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            exercises: [
                exerciseBackup(id: shared, name: "First"),
                exerciseBackup(id: shared, name: "Second"),
            ],
            sessions: []
        )
        XCTAssertThrowsError(try BackupService.decode(try encode(backup))) { error in
            guard case BackupError.invalidBackup(let message) = error else {
                return XCTFail("Expected invalidBackup, got \(error)")
            }
            XCTAssertTrue(message.contains("exercise"), message)
            XCTAssertTrue(message.contains(shared.uuidString), message)
            XCTAssertTrue(message.contains("nothing was changed"), message)
        }
    }

    func test_b5_duplicateSetIDs_areRejected() throws {
        let shared = UUID()
        let when = Date(timeIntervalSince1970: 1_700_000_000)
        let exerciseID = UUID()
        let backup = AppBackup(
            version: 1,
            exportedAt: when,
            exercises: [exerciseBackup(id: exerciseID, name: "Bench")],
            sessions: [
                WorkoutSessionBackup(
                    id: UUID(),
                    date: when,
                    dayType: "Push",
                    notes: "",
                    isCompleted: true,
                    exerciseRecords: [
                        ExerciseRecordBackup(
                            id: UUID(),
                            exerciseID: exerciseID,
                            trainingMode: "Strength",
                            sortOrder: 0,
                            isCompleted: true,
                            notes: "",
                            sets: [
                                SetRecordBackup(id: shared, setNumber: 1, weightLbs: 100, reps: 5, isWarmup: false, completedAt: when),
                                SetRecordBackup(id: shared, setNumber: 2, weightLbs: 100, reps: 5, isWarmup: false, completedAt: when),
                            ]
                        ),
                    ]
                ),
            ]
        )
        XCTAssertThrowsError(try BackupService.decode(try encode(backup))) { error in
            guard case BackupError.invalidBackup(let message) = error else {
                return XCTFail("Expected invalidBackup, got \(error)")
            }
            XCTAssertTrue(message.contains("set"), message)
            XCTAssertTrue(message.contains(shared.uuidString), message)
        }
    }

    func test_b5_unknownBodyMetricKind_isRejected() throws {
        let metricID = UUID()
        let backup = AppBackup(
            version: 1,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            exercises: [],
            sessions: [],
            bodyMetrics: [
                BodyMetricBackup(
                    id: metricID,
                    date: Date(timeIntervalSince1970: 1_700_000_000),
                    kindRaw: "wingspan",
                    value: 70,
                    note: ""
                ),
            ]
        )
        XCTAssertThrowsError(try BackupService.decode(try encode(backup))) { error in
            guard case BackupError.invalidBackup(let message) = error else {
                return XCTFail("Expected invalidBackup, got \(error)")
            }
            XCTAssertTrue(message.contains("wingspan"), message)
            XCTAssertTrue(message.contains("nothing was changed"), message)
        }
    }

    func test_b5_rejectedBackup_leavesExistingRows() throws {
        let context = container.mainContext
        let exercise = Exercise.make(name: "Keep Me", dayType: .push, muscleGroup: "Chest", isCustom: true)
        context.insert(exercise)
        context.insert(BodyMetricEntry(kind: .weight, value: 180, date: Date(timeIntervalSince1970: 1_600_000_000)))
        try context.save()
        let exerciseID = exercise.id

        XCTAssertThrowsError(
            try BackupService.restore(from: try encode(backupWithSet(weight: -50, reps: 5)), context: context)
        )

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(exercises.map(\.id), [exerciseID])
        XCTAssertEqual(exercises.map(\.name), ["Keep Me"])
        let metrics = try context.fetch(FetchDescriptor<BodyMetricEntry>())
        XCTAssertEqual(metrics.map(\.value), [180])
    }

    // MARK: - Helpers

    private func exerciseBackup(id: UUID, name: String) -> ExerciseBackup {
        ExerciseBackup(
            id: id,
            name: name,
            dayType: "Push",
            muscleGroup: "Chest",
            sortOrder: 0,
            isCustom: true,
            notes: ""
        )
    }

    private func backupWithSet(weight: Double, reps: Int) -> AppBackup {
        let when = Date(timeIntervalSince1970: 1_700_000_000)
        let exerciseID = UUID()
        return AppBackup(
            version: 1,
            exportedAt: when,
            exercises: [exerciseBackup(id: exerciseID, name: "Bench")],
            sessions: [
                WorkoutSessionBackup(
                    id: UUID(),
                    date: when,
                    dayType: "Push",
                    notes: "",
                    isCompleted: true,
                    exerciseRecords: [
                        ExerciseRecordBackup(
                            id: UUID(),
                            exerciseID: exerciseID,
                            trainingMode: "Strength",
                            sortOrder: 0,
                            isCompleted: true,
                            notes: "",
                            sets: [
                                SetRecordBackup(
                                    id: UUID(),
                                    setNumber: 1,
                                    weightLbs: weight,
                                    reps: reps,
                                    isWarmup: false,
                                    completedAt: when
                                ),
                            ]
                        ),
                    ]
                ),
            ]
        )
    }

    private func encode(_ backup: AppBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(backup)
    }
}
