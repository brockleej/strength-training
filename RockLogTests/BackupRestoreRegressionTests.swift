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
final class BackupRestoreRegressionTests: XCTestCase {

    override func setUp() {
        super.setUp()
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
        let container = try inMemoryContainer()
        let context = container.mainContext
        let originalExercise = Exercise(
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

        let after = Exercise(name: "After Rollback", dayType: .push, muscleGroup: "Chest", isCustom: true)
        context.insert(after)
        try context.save()
        let names = try context.fetch(FetchDescriptor<Exercise>()).map(\.name).sorted()
        XCTAssertEqual(names, ["After Rollback", "Keep Me"])
    }

    // MARK: - Helpers

    private func inMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Exercise.self,
            WorkoutSession.self,
            ExerciseRecord.self,
            SetRecord.self,
            SplitDay.self,
            BodyMetricEntry.self,
            TrainingBlock.self,
            configurations: config
        )
    }

    private func encode(_ backup: AppBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(backup)
    }
}
