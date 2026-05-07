import XCTest
import SwiftData
@testable import strength_training

final class PrevSessionsStripDataTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: WorkoutSession.self, ExerciseRecord.self, SetRecord.self, Exercise.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    /// Build a completed session at `date` containing one ExerciseRecord for `exercise`
    /// in `mode` with the given (weight, reps) tuples in order.
    @discardableResult
    private func insertRecord(
        _ ctx: ModelContext,
        exercise: Exercise,
        date: Date,
        mode: TrainingMode,
        sets: [(Double, Int)]
    ) -> ExerciseRecord {
        let session = WorkoutSession(dayType: exercise.dayType)
        session.isCompleted = true
        session.date = date
        let record = ExerciseRecord(trainingMode: mode, sortOrder: 0)
        record.exercise = exercise
        record.session = session
        for (i, t) in sets.enumerated() {
            let s = SetRecord(setNumber: i + 1, weightLbs: t.0, reps: t.1)
            s.exerciseRecord = record
            s.completedAt = date.addingTimeInterval(60 * Double(i + 1))
            if record.sets == nil { record.sets = [] }
            record.sets?.append(s)
            ctx.insert(s)
        }
        session.exerciseRecords = [record]
        ctx.insert(session); ctx.insert(record)
        return record
    }

    func testShape_returnsEmptyWhenNoHistory() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Squat", dayType: .legs)
        ctx.insert(ex)
        try ctx.save()

        let entries = PrevSessionsStripData.shape(
            for: ex,
            mode: .highWeightLowReps,
            now: .now
        )
        XCTAssertTrue(entries.isEmpty)
    }

    func testShape_ordersAscendingByDate_oldestFirst() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Squat", dayType: .legs)
        ctx.insert(ex)
        let now = Date()
        // Insert in non-chronological order to verify sort
        insertRecord(ctx, exercise: ex, date: now.addingTimeInterval(-86400 * 21), mode: .highWeightLowReps, sets: [(225, 5), (225, 5), (225, 5)])
        insertRecord(ctx, exercise: ex, date: now.addingTimeInterval(-86400 * 7),  mode: .highWeightLowReps, sets: [(230, 5), (230, 5), (230, 4)])
        insertRecord(ctx, exercise: ex, date: now.addingTimeInterval(-86400 * 14), mode: .highWeightLowReps, sets: [(225, 5), (225, 5), (225, 4)])
        try ctx.save()

        let entries = PrevSessionsStripData.shape(for: ex, mode: .highWeightLowReps, now: now)
        XCTAssertEqual(entries.count, 3)
        // Last (most recent) should be the 7-days-ago entry
        XCTAssertEqual(entries.last?.dateLabel, "7 DAYS AGO")
        // First (oldest) should be the 21-days-ago entry
        XCTAssertEqual(entries.first?.dateLabel, "21 DAYS AGO")
    }

    func testShape_filtersOtherExercise() throws {
        let ctx = try makeContext()
        let squat = Exercise(name: "Squat", dayType: .legs)
        let bench = Exercise(name: "Bench", dayType: .arms)
        ctx.insert(squat); ctx.insert(bench)
        let now = Date()
        insertRecord(ctx, exercise: squat, date: now.addingTimeInterval(-86400 * 7), mode: .highWeightLowReps, sets: [(225, 5)])
        insertRecord(ctx, exercise: bench, date: now.addingTimeInterval(-86400 * 5), mode: .highWeightLowReps, sets: [(135, 5)])
        try ctx.save()

        let squatEntries = PrevSessionsStripData.shape(for: squat, mode: .highWeightLowReps, now: now)
        XCTAssertEqual(squatEntries.count, 1)
        XCTAssertEqual(squatEntries.first?.setsLabel, "225 × 5")
    }

    func testShape_filtersOtherMode() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Squat", dayType: .legs)
        ctx.insert(ex)
        let now = Date()
        insertRecord(ctx, exercise: ex, date: now.addingTimeInterval(-86400 * 7),  mode: .highWeightLowReps, sets: [(225, 5)])
        insertRecord(ctx, exercise: ex, date: now.addingTimeInterval(-86400 * 14), mode: .lowWeightHighReps, sets: [(135, 12)])
        try ctx.save()

        let strength = PrevSessionsStripData.shape(for: ex, mode: .highWeightLowReps, now: now)
        XCTAssertEqual(strength.count, 1)
        let endurance = PrevSessionsStripData.shape(for: ex, mode: .lowWeightHighReps, now: now)
        XCTAssertEqual(endurance.count, 1)
    }

    func testShape_takesLast10() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Squat", dayType: .legs)
        ctx.insert(ex)
        let now = Date()
        for i in 1...15 {
            insertRecord(ctx, exercise: ex, date: now.addingTimeInterval(-86400 * Double(i * 7)), mode: .highWeightLowReps, sets: [(225, 5)])
        }
        try ctx.save()

        let entries = PrevSessionsStripData.shape(for: ex, mode: .highWeightLowReps, now: now)
        XCTAssertEqual(entries.count, 10, "shape should cap at 10 entries")
    }

    func testShape_setsLabelFormat_singleSet() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Squat", dayType: .legs)
        ctx.insert(ex)
        let now = Date()
        insertRecord(ctx, exercise: ex, date: now.addingTimeInterval(-86400 * 7), mode: .highWeightLowReps, sets: [(225, 5)])
        try ctx.save()

        let entries = PrevSessionsStripData.shape(for: ex, mode: .highWeightLowReps, now: now)
        XCTAssertEqual(entries.first?.setsLabel, "225 × 5")
    }

    func testShape_setsLabelFormat_multipleSets() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Squat", dayType: .legs)
        ctx.insert(ex)
        let now = Date()
        insertRecord(ctx, exercise: ex, date: now.addingTimeInterval(-86400 * 7), mode: .highWeightLowReps, sets: [(225, 5), (225, 5), (225, 4)])
        try ctx.save()

        let entries = PrevSessionsStripData.shape(for: ex, mode: .highWeightLowReps, now: now)
        XCTAssertEqual(entries.first?.setsLabel, "225 × 5 · 5 · 4",
                       "Top weight first, then comma-list of reps")
    }
}
