//
//  SplitImportEdgeTests.swift
//  RockLogTests
//
//  Edges around rocklog.split / rocklog.program that ProgramImportTests
//  does not cover. ProgramImportTests stays untouched (PR #9 fixes its
//  stale replaceSplit call).
//

import XCTest
import SwiftData
@testable import RockLog

@MainActor
final class SplitImportEdgeTests: RockLogStoreTestCase {

    func test_importSplit_rejectsEmptyWrongFormat() throws {
        let empty = makeDocument(format: ProgramFormat.splitFormatName, sessions: [])
        XCTAssertThrowsError(try ProgramImportService.importSplit(empty, context: container.mainContext)) { error in
            guard let programError = error as? ProgramDocument.ProgramFormatError,
                  case .emptyBlock = programError else {
                return XCTFail("Expected emptyBlock, got \(error)")
            }
        }

        let wrong = makeDocument(format: "not-a-split", sessions: [pushSession(name: "UI Row")])
        XCTAssertThrowsError(try ProgramImportService.importSplit(wrong, context: container.mainContext)) { error in
            guard let programError = error as? ProgramDocument.ProgramFormatError,
                  case .wrongFormat = programError else {
                return XCTFail("Expected wrongFormat, got \(error)")
            }
        }
    }

    func test_codec_rejectsUnsupportedVersionAndBadJSON() {
        let badVersion = """
        {"format":"rocklog.split","schemaVersion":99,"exportedAt":"2026-01-01T00:00:00Z","block":{"id":"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA","name":"X","startDate":"2026-01-01T00:00:00Z","sessions":[{"id":"BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB","date":"2026-01-02T00:00:00Z","dayType":"Push","exercises":[]}]}}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try ProgramCodec.decode(badVersion)) { error in
            guard let programError = error as? ProgramDocument.ProgramFormatError,
                  case .unsupportedVersion = programError else {
                return XCTFail("Expected unsupportedVersion, got \(error)")
            }
        }
        XCTAssertThrowsError(try IncomingRockLogFile.parse(Data("{".utf8))) { error in
            guard let fileError = error as? IncomingRockLogFile.IncomingFileError,
                  case .unrecognized = fileError else {
                return XCTFail("Expected unrecognized, got \(error)")
            }
        }
    }

    func test_incomingFile_rejectsCoachFormat() {
        let coach = """
        {"format":"rocklog.coach.session","schemaVersion":1}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try IncomingRockLogFile.parse(coach)) { error in
            guard let fileError = error as? IncomingRockLogFile.IncomingFileError,
                  case .unrecognized = fileError else {
                return XCTFail("Expected unrecognized, got \(error)")
            }
        }
    }

    func test_importDocument_createsUnknownLift_andStoresZeroAndHugeTargets() throws {
        let context = container.mainContext
        let mystery = ProgramExercisePayload(
            id: UUID(),
            name: "UI Mystery Lift",
            muscleGroup: "Chest",
            trainingMode: TrainingMode.highWeightLowReps.rawValue,
            notes: nil,
            sets: [
                ProgramSetPayload(setNumber: 1, weightLbs: 0, reps: 10, isWarmup: false, isEachSide: false, isAssisted: false),
                ProgramSetPayload(setNumber: 2, weightLbs: 10_000, reps: 1, isWarmup: false, isEachSide: false, isAssisted: false),
            ]
        )
        let session = ProgramSessionPayload(
            id: UUID(),
            date: Date(),
            dayType: "Push",
            rotationTrack: nil,
            notes: nil,
            exercises: [mystery]
        )
        let document = makeDocument(format: ProgramFormat.formatName, sessions: [session])
        let result = try ProgramImportService.importDocument(document, context: context)
        XCTAssertEqual(result.summary.createdExerciseCount, 1)
        XCTAssertEqual(result.summary.sessionCount, 1)

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(exercises.map(\.name), ["UI Mystery Lift"])
        let sets = try context.fetch(FetchDescriptor<SetRecord>()).sorted { $0.setNumber < $1.setNumber }
        XCTAssertEqual(sets.map(\.weightLbs), [0, 10_000])
        XCTAssertTrue(sets.allSatisfy(\.isTarget))
        let planned = try context.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(planned.count, 1)
        XCTAssertTrue(planned[0].isPlanned)
    }

    func test_importSplit_collapsesDuplicateDayNames_andDoesNotQueueSessions() throws {
        let context = container.mainContext
        let first = pushSession(name: "UI Alpha Lift", day: "Push")
        let second = pushSession(name: "UI Beta Lift", day: " push ")
        let document = makeDocument(format: ProgramFormat.splitFormatName, sessions: [first, second])

        XCTAssertEqual(ProgramImportService.splitSchedule(from: document).map(\.name), ["Push"])
        try ProgramImportService.importSplit(document, context: context)

        let days = try context.fetch(FetchDescriptor<SplitDay>())
        XCTAssertEqual(days.map(\.name), ["Push"])
        let names = Set(try context.fetch(FetchDescriptor<Exercise>()).map(\.name))
        XCTAssertEqual(names, ["UI Alpha Lift", "UI Beta Lift"])
        XCTAssertTrue(try context.fetch(FetchDescriptor<WorkoutSession>()).isEmpty)
    }

    func test_importSplit_removeUnusedPlanFalse_keepsWaitingQueue() throws {
        let context = container.mainContext
        let waiting = WorkoutSession(dayType: .push, date: Date().addingTimeInterval(-86_400))
        waiting.planStatus = .planned
        waiting.planOrder = 0
        context.insert(waiting)
        try context.save()

        let document = makeDocument(
            format: ProgramFormat.splitFormatName,
            sessions: [pushSession(name: "UI Split Only", day: "UI Alpha")]
        )
        try ProgramImportService.importSplit(document, context: context, removeUnusedPlan: false)

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(sessions.map(\.id), [waiting.id])
        XCTAssertTrue(PlannedBlockQueue.isUnused(sessions[0]))
        let days = try context.fetch(FetchDescriptor<SplitDay>())
        XCTAssertEqual(days.map(\.name), ["UI Alpha"])
    }

    private func pushSession(name: String, day: String = "Push") -> ProgramSessionPayload {
        ProgramSessionPayload(
            id: UUID(),
            date: Date(),
            dayType: day,
            rotationTrack: nil,
            notes: nil,
            exercises: [
                ProgramExercisePayload(
                    id: UUID(),
                    name: name,
                    muscleGroup: "Chest",
                    trainingMode: "Strength",
                    notes: nil,
                    sets: [
                        ProgramSetPayload(setNumber: 1, weightLbs: 135, reps: 5, isWarmup: false, isEachSide: false, isAssisted: false),
                    ]
                )
            ]
        )
    }

    private func makeDocument(format: String, sessions: [ProgramSessionPayload]) -> ProgramDocument {
        ProgramDocument(
            format: format,
            schemaVersion: ProgramFormat.schemaVersion,
            exportedAt: Date(),
            block: ProgramBlockPayload(
                id: UUID(),
                name: "UI Import",
                notes: nil,
                startDate: Date(),
                sessions: sessions
            )
        )
    }
}
