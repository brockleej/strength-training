//
//  BackupLoaderTests.swift
//  progression-lab-tests
//

import XCTest
@testable import ProgressionLab

final class BackupLoaderTests: XCTestCase {

    private func fixtureURL(_ name: String) throws -> URL {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            XCTFail("Fixture \(name).json not found in test bundle — confirm it's a member of progression-lab-tests")
            throw NSError(domain: "BackupLoaderTests", code: 0)
        }
        return url
    }

    func test_minimalBackup_loadsOneExerciseOneSession() throws {
        let url = try fixtureURL("minimal-backup")
        let dataset = try BackupLoader.load(from: url)

        XCTAssertEqual(dataset.exercises.count, 1)
        let exerciseRecords = dataset.exercises[0]
        XCTAssertEqual(exerciseRecords.exercise.name, "Test Exercise")
        XCTAssertEqual(exerciseRecords.snapshots.count, 1)
        XCTAssertEqual(exerciseRecords.snapshots[0].sets.count, 1)
        XCTAssertEqual(exerciseRecords.snapshots[0].sets[0].weightLbs, 50.0)
        XCTAssertEqual(exerciseRecords.snapshots[0].sets[0].reps, 8)
        XCTAssertEqual(dataset.summary.exerciseCount, 1)
        XCTAssertEqual(dataset.summary.sessionCount, 1)
        XCTAssertEqual(dataset.summary.skipReasons.values.reduce(0, +), 0)
    }

    func test_backupWithOrphans_skipsOrphansAndUnknownModes() throws {
        let url = try fixtureURL("backup-with-orphans")
        let dataset = try BackupLoader.load(from: url)

        XCTAssertEqual(dataset.exercises.count, 1)
        XCTAssertEqual(dataset.exercises[0].snapshots.count, 1)
        XCTAssertEqual(dataset.summary.skipReasons[.orphanedExerciseID], 1)
        XCTAssertEqual(dataset.summary.skipReasons[.unknownTrainingMode], 1)
        XCTAssertNil(dataset.summary.skipReasons[.incompleteSession])
        XCTAssertTrue(dataset.summary.displayLine.contains("orphaned exerciseID"))
        XCTAssertTrue(dataset.summary.displayLine.contains("unknown trainingMode"))
    }

    func test_unsupportedVersion_throws() throws {
        let url = try fixtureURL("unsupported-version")
        XCTAssertThrowsError(try BackupLoader.load(from: url)) { error in
            guard case BackupLoaderError.unsupportedVersion(let found, let supported) = error else {
                XCTFail("Expected .unsupportedVersion, got \(error)")
                return
            }
            XCTAssertEqual(found, 999)
            XCTAssertEqual(supported, 1)
        }
    }

    func test_summaryDisplayLine_zeroSkips_omitsParenthetical() {
        let summary = LoadedDatasetSummary(
            exerciseCount: 5,
            sessionCount: 12,
            dateRangeStart: nil,
            dateRangeEnd: nil,
            skipReasons: [:]
        )
        XCTAssertFalse(summary.displayLine.contains("("))
    }
}
