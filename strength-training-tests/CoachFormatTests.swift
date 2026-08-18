//
//  CoachFormatTests.swift
//  strength-training-tests
//

import XCTest
import SwiftData
@testable import strength_training

@MainActor
final class CoachFormatTests: XCTestCase {

    func test_codec_roundTrip() throws {
        let doc = sampleDocument()
        let data = try CoachSessionCodec.encode(doc)
        let decoded = try CoachSessionCodec.decode(data)
        XCTAssertEqual(decoded, doc)
        XCTAssertFalse(String(data: data, encoding: .utf8)!.contains("tonnage"))
        XCTAssertFalse(String(data: data, encoding: .utf8)!.contains("volume"))
    }

    func test_codec_rejectsWrongFormat() throws {
        var doc = sampleDocument()
        doc.format = "not.a.coach.file"
        let data = try CoachSessionCodec.encode(doc)
        XCTAssertThrowsError(try CoachSessionCodec.decode(data)) { error in
            guard case CoachSessionDocument.CoachFormatError.wrongFormat = error else {
                return XCTFail("expected wrongFormat, got \(error)")
            }
        }
    }

    func test_codec_rejectsNewerVersion() throws {
        var doc = sampleDocument()
        doc.schemaVersion = 2
        let data = try CoachSessionCodec.encode(doc)
        XCTAssertThrowsError(try CoachSessionCodec.decode(data)) { error in
            guard case CoachSessionDocument.CoachFormatError.unsupportedVersion(2) = error else {
                return XCTFail("expected unsupportedVersion, got \(error)")
            }
        }
    }

    func test_suggestedFilename() {
        let doc = sampleDocument()
        let stamp = doc.session.startedAt.formatted(Date.ISO8601FormatStyle().year().month().day())
        XCTAssertEqual(
            CoachSessionCodec.suggestedFilename(for: doc),
            "Lee-Pull-\(stamp).rocklogcoach"
        )
        XCTAssertTrue(CoachSessionCodec.suggestedFilename(for: doc).hasSuffix(".rocklogcoach"))
    }

    @MainActor
    func test_export_mapsSetsAndSkipsEmptyLifts() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext

        let bench = Exercise(name: "Bench", dayType: .push, muscleGroup: "Chest", sortOrder: 0)
        let empty = Exercise(name: "Skipped Flye", dayType: .push, muscleGroup: "Chest", sortOrder: 1)
        let session = WorkoutSession(dayType: .push, date: Date(timeIntervalSince1970: 1_786_435_200))
        session.notes = "Felt strong"
        session.effortRating = 7
        session.rotationTrack = "A"

        let benchRecord = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
        benchRecord.exercise = bench
        benchRecord.session = session
        benchRecord.notes = "Paused"
        let working = SetRecord(setNumber: 1, weightLbs: 225, reps: 5)
        working.exerciseRecord = benchRecord
        let warmup = SetRecord(setNumber: 2, weightLbs: 135, reps: 8, isWarmup: true)
        warmup.exerciseRecord = benchRecord
        benchRecord.sets = [working, warmup]

        let emptyRecord = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 1)
        emptyRecord.exercise = empty
        emptyRecord.session = session
        emptyRecord.sets = []

        session.exerciseRecords = [benchRecord, emptyRecord]
        context.insert(bench)
        context.insert(empty)
        context.insert(session)
        context.insert(benchRecord)
        context.insert(emptyRecord)
        context.insert(working)
        context.insert(warmup)
        try context.save()

        let athlete = CoachAthlete(id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!, displayName: "Lee")
        let doc = try CoachExportService.document(from: session, athlete: athlete)

        XCTAssertEqual(doc.format, "rocklog.coach.session")
        XCTAssertEqual(doc.schemaVersion, 1)
        XCTAssertEqual(doc.athlete.displayName, "Lee")
        XCTAssertEqual(doc.session.dayType, "Push")
        XCTAssertEqual(doc.session.rotationTrack, "A")
        XCTAssertEqual(doc.session.notes, "Felt strong")
        XCTAssertEqual(doc.session.effortRating, 7)
        XCTAssertEqual(doc.session.exercises.count, 1)
        XCTAssertEqual(doc.session.exercises[0].name, "Bench")
        XCTAssertEqual(doc.session.exercises[0].muscleGroup, "Chest")
        XCTAssertEqual(doc.session.exercises[0].sets.count, 2)
        XCTAssertEqual(doc.session.exercises[0].sets[0].weightLbs, 225)
        XCTAssertEqual(doc.session.exercises[0].sets[1].isWarmup, true)
    }

    @MainActor
    func test_export_throwsWhenNoSets() throws {
        let session = WorkoutSession(dayType: .arms)
        XCTAssertThrowsError(try CoachExportService.document(from: session, athlete: CoachAthletePreferences.athlete)) { error in
            guard case CoachExportError.noWorkingSets = error else {
                return XCTFail("expected noWorkingSets, got \(error)")
            }
        }
    }

    func test_progression_comparesBestWorkingSet() {
        let earlier = sampleDocument(sessionID: UUID(), startedAt: Date(timeIntervalSince1970: 1_786_348_800), weight: 220, reps: 5)
        let current = sampleDocument(sessionID: UUID(), startedAt: Date(timeIntervalSince1970: 1_786_435_200), weight: 225, reps: 5)
        let snaps = CoachProgression.snapshots(current: current, history: [earlier])
        XCTAssertEqual(snaps.count, 1)
        XCTAssertEqual(snaps[0].direction, .up)
        XCTAssertEqual(CoachProgression.setLabel(snaps[0].current!), "225×5")
        XCTAssertEqual(CoachProgression.setLabel(snaps[0].previous!), "220×5")
    }

    func test_compareGrid_oldestLeftNewestRight_marksUp() {
        let older = sampleDocument(sessionID: UUID(), startedAt: Date(timeIntervalSince1970: 100), weight: 220, reps: 5)
        let newer = sampleDocument(sessionID: UUID(), startedAt: Date(timeIntervalSince1970: 200), weight: 225, reps: 5)
        let grid = CoachProgression.compareGrid(from: [newer, older], limit: 4)
        XCTAssertEqual(grid.columns.map(\.id), [older.session.id, newer.session.id])
        XCTAssertEqual(grid.rows.count, 1)
        XCTAssertEqual(grid.rows[0].name, "Row")
        XCTAssertEqual(grid.rows[0].cells[0].direction, .new)
        XCTAssertEqual(grid.rows[0].cells[1].direction, .up)
        XCTAssertEqual(grid.rows[0].cells[1].best?.weightLbs, 225)
    }

    func test_decodeFile_acceptsSessionAndBatch() throws {
        let one = sampleDocument()
        let file = try CoachSessionCodec.decodeFile(try CoachSessionCodec.encode(one))
        guard case .session(let decoded) = file else {
            return XCTFail("expected session")
        }
        XCTAssertEqual(decoded.session.id, one.session.id)

        let two = sampleDocument(sessionID: UUID(), startedAt: Date(timeIntervalSince1970: 1_786_348_800), weight: 220, reps: 5)
        let batch = CoachBatchDocument(
            format: CoachFormat.batchFormatName,
            schemaVersion: 1,
            exportedAt: Date(timeIntervalSince1970: 1_786_435_200),
            athlete: one.athlete,
            sessions: [two.session, one.session]
        )
        let data = try CoachSessionCodec.encode(batch)
        let decodedFile = try CoachSessionCodec.decodeFile(data)
        guard case .batch(let decodedBatch) = decodedFile else {
            return XCTFail("expected batch")
        }
        XCTAssertEqual(decodedBatch.sessions.count, 2)
        XCTAssertEqual(decodedFile.sessionDocuments.count, 2)
        XCTAssertFalse(String(data: data, encoding: .utf8)!.contains("tonnage"))
    }

    func test_decodeFile_rejectsUnknownFormat() throws {
        var doc = sampleDocument()
        doc.format = "rocklog.coach.week"
        XCTAssertThrowsError(try CoachSessionCodec.decodeFile(try CoachSessionCodec.encode(doc))) { error in
            guard case CoachSessionDocument.CoachFormatError.wrongFormat = error else {
                return XCTFail("expected wrongFormat, got \(error)")
            }
        }
    }

    func test_ledger_unsharedFiltersSharedIDs() {
        let sent = WorkoutSession(dayType: .push, date: Date(timeIntervalSince1970: 100))
        sent.isCompleted = true
        let fresh = WorkoutSession(dayType: .pull, date: Date(timeIntervalSince1970: 200))
        fresh.isCompleted = true
        let open = WorkoutSession(dayType: .arms, date: Date(timeIntervalSince1970: 300))
        open.isCompleted = false

        let pending = CoachShareLedger.unshared(
            from: [fresh, sent, open],
            alreadyShared: [sent.id]
        )
        XCTAssertEqual(pending.map(\.id), [fresh.id])
    }

    @MainActor
    func test_export_oneSessionStaysSessionFormat_twoBecomeBatch() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        let athlete = CoachAthlete(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            displayName: "Lee"
        )

        let first = try insertLoggedSession(day: .push, date: Date(timeIntervalSince1970: 100), weight: 185, in: context)
        let second = try insertLoggedSession(day: .pull, date: Date(timeIntervalSince1970: 200), weight: 200, in: context)

        let one = try CoachExportService.writePackage(for: [first], athlete: athlete)
        guard case .session = try CoachSessionCodec.decodeFile(Data(contentsOf: one.url)) else {
            return XCTFail("single workout must stay rocklog.coach.session")
        }

        let two = try CoachExportService.writePackage(for: [first, second], athlete: athlete)
        guard case .batch(let batch) = try CoachSessionCodec.decodeFile(Data(contentsOf: two.url)) else {
            return XCTFail("two workouts must be rocklog.coach.batch")
        }
        XCTAssertEqual(batch.sessions.count, 2)
        XCTAssertEqual(Set(two.sessionIDs), Set([first.id, second.id]))
    }

    func test_progression_ignoresWarmupForBestSet() {
        let exercise = CoachExercisePayload(
            id: UUID(),
            name: "Row",
            muscleGroup: "Back",
            trainingMode: "Strength",
            notes: nil,
            sets: [
                CoachSetPayload(setNumber: 1, weightLbs: 185, reps: 8, isWarmup: true, isEachSide: false, isAssisted: false, completedAt: nil),
                CoachSetPayload(setNumber: 2, weightLbs: 155, reps: 10, isWarmup: false, isEachSide: false, isAssisted: false, completedAt: nil),
            ]
        )
        let best = CoachProgression.bestWorkingSet(in: exercise)
        XCTAssertEqual(best?.weightLbs, 155)
        XCTAssertEqual(best?.reps, 10)
    }

    private func sampleDocument(
        sessionID: UUID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
        startedAt: Date = Date(timeIntervalSince1970: 1_786_435_200),
        weight: Double = 225,
        reps: Int = 5
    ) -> CoachSessionDocument {
        CoachSessionDocument(
            format: CoachFormat.formatName,
            schemaVersion: CoachFormat.schemaVersion,
            exportedAt: Date(timeIntervalSince1970: 1_786_435_200),
            athlete: CoachAthlete(
                id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
                displayName: "Lee"
            ),
            session: CoachSessionPayload(
                id: sessionID,
                startedAt: startedAt,
                dayType: "Pull",
                rotationTrack: "A",
                notes: nil,
                effortRating: 8,
                exercises: [
                    CoachExercisePayload(
                        id: UUID(uuidString: "99999999-8888-7777-6666-555555555555")!,
                        name: "Row",
                        muscleGroup: "Back",
                        trainingMode: "Strength",
                        notes: nil,
                        sets: [
                            CoachSetPayload(
                                setNumber: 1,
                                weightLbs: weight,
                                reps: reps,
                                isWarmup: false,
                                isEachSide: false,
                                isAssisted: false,
                                completedAt: startedAt
                            )
                        ]
                    )
                ]
            )
        )
    }

    @MainActor
    private func insertLoggedSession(
        day: DayType,
        date: Date,
        weight: Double,
        in context: ModelContext
    ) throws -> WorkoutSession {
        let exercise = Exercise(name: "Lift", dayType: day, muscleGroup: "Chest", sortOrder: 0)
        let session = WorkoutSession(dayType: day, date: date)
        session.isCompleted = true
        let record = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
        record.exercise = exercise
        record.session = session
        let set = SetRecord(setNumber: 1, weightLbs: weight, reps: 5)
        set.exerciseRecord = record
        record.sets = [set]
        session.exerciseRecords = [record]
        context.insert(exercise)
        context.insert(session)
        context.insert(record)
        context.insert(set)
        try context.save()
        return session
    }

    @MainActor
    private func inMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Exercise.self,
            WorkoutSession.self,
            ExerciseRecord.self,
            SetRecord.self,
            SplitDay.self,
            BodyMetricEntry.self,
            configurations: config
        )
    }
}
