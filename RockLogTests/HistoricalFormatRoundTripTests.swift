//
//  HistoricalFormatRoundTripTests.swift
//  RockLogTests
//
//  Synthetic files shaped like the backups, coach files, and program files
//  RockLog has shipped. No real workout history.
//

import XCTest
@testable import RockLog

final class HistoricalFormatRoundTripTests: XCTestCase {
    func test_everyShippedShape_roundTrips_andKeepsUnknownKeys() throws {
        for sample in HistoricalFormatFixtures.all {
            let data = Data(sample.json.utf8)
            var object = try InterchangeCodec.parseObject(data)
            let originalUnknown = object["labNote"]?.string ?? object["payload"]?["labNote"]?.string
            try InterchangeCodec.migrate(&object, to: InterchangeFormat.walkableVersion)
            XCTAssertEqual(object["format"]?.string, InterchangeFormat.name, sample.name)
            XCTAssertEqual(object["formatVersion"]?.int, 2, sample.name)
            XCTAssertEqual(object["weightUnit"]?.string, "lb", sample.name)
            let kept = object["payload"]?["labNote"]?.string
            XCTAssertEqual(kept, originalUnknown ?? "synthetic", sample.name)
            let issues = InterchangeCodec.validate(object)
            XCTAssertTrue(issues.isEmpty, "\(sample.name): \(issues.map(\.message).joined(separator: ", "))")
            try InterchangeCodec.migrate(&object, to: 1)
            XCTAssertEqual(object["formatVersion"]?.int, 1, sample.name)
            XCTAssertNotNil(object["payload"]?["labNote"])
            let legacy = try InterchangeCodec.downgradeToLegacy(try InterchangeCodec.encode(object))
            let legacyObject = try InterchangeCodec.parseObject(legacy)
            XCTAssertEqual(legacyObject["labNote"]?.string, "synthetic", sample.name)
        }
    }

    func test_hugeWeight_isRejected_andEmptyPayloadKindStillValidatesShape() throws {
        var object = InterchangeCodec.wrap(kind: .backup, payload: ["weightLbs": .number(50_000)], exportedAt: "2026-01-01T00:00:00Z")
        XCTAssertFalse(InterchangeCodec.validate(object).isEmpty)
        object = InterchangeCodec.wrap(kind: .split, payload: [:], exportedAt: "2026-01-01T00:00:00Z")
        XCTAssertTrue(InterchangeCodec.validate(object).isEmpty)
    }
}

enum HistoricalFormatFixtures {
    struct Sample {
        var name: String
        var json: String
    }

    static let id = "11111111-1111-4111-8111-111111111111"
    static let session = "22222222-2222-4222-8222-222222222222"

    static var all: [Sample] {
        [
            Sample(name: "19940d0 backup", json: backup(extra: "")),
            Sample(name: "3dc37b3 day plans absent", json: backup(extra: #""rotationTrack":"","extraDayTypes":"","#)),
            Sample(name: "ba3c02f assist flags", json: backup(extra: #""isEachSide":false,"isAssisted":false,"#)),
            Sample(name: "c0bc533 split days", json: backup(extra: #""splitDays":[{"id":"\#(id)","name":"Push","sortOrder":0}],"#)),
            Sample(name: "4602b83 day plan and duration", json: backup(extra: #""dayPlans":[{"dayType":"Push","exerciseIDs":["\#(id)"]}],"durationSeconds":1800,"#)),
            Sample(name: "de2d45f program", json: program),
            Sample(name: "3be66a4 session roster", json: backup(extra: #""followsSessionRoster":true,"planState":"planned","#)),
            Sample(name: "17fbd92 plan queue", json: backup(extra: #""planOrder":1,"planState":"planned","followsSessionRoster":true,"#)),
            Sample(name: "fa9d140 training blocks", json: backup(extra: #""trainingBlocks":[],"#)),
            Sample(name: "d649053 body metrics", json: backup(extra: #""bodyMetrics":[{"id":"\#(id)","kind":"weight","value":180,"date":"2026-01-02T00:00:00Z","note":""}],"#)),
            Sample(name: "c0bc533 coach session", json: coachSession),
            Sample(name: "c0bc533 coach batch", json: coachBatch),
            Sample(name: "b578c52 split", json: split),
        ]
    }

    static func backup(extra: String) -> String {
        """
        {"version":1,"exportedAt":"2026-01-01T00:00:00Z","labNote":"synthetic",\(extra)"exercises":[{"id":"\(id)","name":"Back Squat","dayType":"Legs","muscleGroup":"Quads","sortOrder":0,"isCustom":false,"notes":""}],"sessions":[{"id":"\(session)","date":"2026-01-01T00:00:00Z","dayType":"Legs","notes":"","isCompleted":true,"exerciseRecords":[]}]}
        """
    }

    static let program = """
    {"format":"rocklog.program","version":1,"labNote":"synthetic","blocks":[{"name":"Synthetic","weeks":1}]}
    """

    static let split = """
    {"format":"rocklog.split","version":1,"labNote":"synthetic","days":[{"name":"Push","exercises":["Bench Press"]}]}
    """

    static let coachSession = """
    {"format":"rocklog.coach.session","schemaVersion":1,"labNote":"synthetic","id":"\(session)","exportedAt":"2026-01-01T00:00:00Z","exercises":[]}
    """

    static let coachBatch = """
    {"format":"rocklog.coach.batch","schemaVersion":1,"labNote":"synthetic","sessions":[]}
    """
}
