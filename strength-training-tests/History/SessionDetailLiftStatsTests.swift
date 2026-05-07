import XCTest
import SwiftData
@testable import strength_training

final class SessionDetailLiftStatsTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: WorkoutSession.self, ExerciseRecord.self, SetRecord.self, Exercise.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @discardableResult
    private func session(_ ctx: ModelContext,
                         exercise: Exercise,
                         date: Date,
                         sortOrder: Int = 0,
                         sets: [(weight: Double, reps: Int, warmup: Bool)]) -> WorkoutSession {
        let s = WorkoutSession(dayType: exercise.dayType)
        s.isCompleted = true
        s.date = date
        let r = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: sortOrder)
        r.exercise = exercise
        r.session = s
        for (i, t) in sets.enumerated() {
            let set = SetRecord(setNumber: i + 1, weightLbs: t.weight, reps: t.reps)
            set.exerciseRecord = r
            set.isWarmup = t.warmup
            r.sets = (r.sets ?? []) + [set]
            ctx.insert(set)
        }
        s.exerciseRecords = [r]
        ctx.insert(s); ctx.insert(r)
        return s
    }

    // MARK: - Empty / orphan

    func testEmptySession_returnsNoRows() throws {
        let ctx = try makeContext()
        let s = WorkoutSession(dayType: .arms)
        s.isCompleted = true; s.date = .now
        ctx.insert(s); try ctx.save()

        XCTAssertTrue(SessionDetailLiftStats.rows(for: s).isEmpty)
    }

    func testRecordWithOnlyWarmups_excluded() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        let s = session(ctx, exercise: ex, date: .now, sets: [(45, 10, true)])
        try ctx.save()

        XCTAssertTrue(SessionDetailLiftStats.rows(for: s).isEmpty)
    }

    // MARK: - Top set

    func testTopSet_highestE1RM() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        let s = session(ctx, exercise: ex, date: .now, sets: [
            (100, 8, false),  // e1RM ≈ 126.7
            (110, 5, false),  // e1RM ≈ 128.3 ← top
            (105, 6, false)   // e1RM ≈ 126.0
        ])
        try ctx.save()

        let row = SessionDetailLiftStats.rows(for: s).first!
        XCTAssertEqual(row.topWeightLb, 110)
        XCTAssertEqual(row.topReps, 5)
        XCTAssertEqual(row.setsCount, 3)
    }

    // MARK: - PR detection

    func testIsPR_firstSessionEver_isPR() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        let s = session(ctx, exercise: ex, date: .now, sets: [(100, 5, false)])
        try ctx.save()

        XCTAssertTrue(SessionDetailLiftStats.rows(for: s).first!.isPR)
    }

    func testIsPR_beatsAllPrior_isPR() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        let earlier = Date(timeIntervalSinceNow: -7 * 24 * 3600)
        _ = session(ctx, exercise: ex, date: earlier, sets: [(100, 5, false)])
        let curr = session(ctx, exercise: ex, date: .now, sets: [(110, 5, false)])
        try ctx.save()

        XCTAssertTrue(SessionDetailLiftStats.rows(for: curr).first!.isPR)
    }

    func testIsPR_tiesPrior_isNotPR() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        let earlier = Date(timeIntervalSinceNow: -7 * 24 * 3600)
        _ = session(ctx, exercise: ex, date: earlier, sets: [(100, 5, false)])
        let curr = session(ctx, exercise: ex, date: .now, sets: [(100, 5, false)])
        try ctx.save()

        XCTAssertFalse(SessionDetailLiftStats.rows(for: curr).first!.isPR)
    }

    // MARK: - Delta vs last

    func testDelta_firstSession_isNil() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        let s = session(ctx, exercise: ex, date: .now, sets: [(100, 5, false)])
        try ctx.save()

        XCTAssertNil(SessionDetailLiftStats.rows(for: s).first!.deltaVsLastLb)
    }

    func testDelta_increase_isPositive() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        let earlier = Date(timeIntervalSinceNow: -7 * 24 * 3600)
        _ = session(ctx, exercise: ex, date: earlier, sets: [(100, 5, false)])
        let curr = session(ctx, exercise: ex, date: .now, sets: [(105, 5, false)])
        try ctx.save()

        let delta = try XCTUnwrap(SessionDetailLiftStats.rows(for: curr).first!.deltaVsLastLb)
        XCTAssertEqual(delta, 5, accuracy: 0.01)
    }

    func testDelta_regression_isNegative() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        let earlier = Date(timeIntervalSinceNow: -7 * 24 * 3600)
        _ = session(ctx, exercise: ex, date: earlier, sets: [(110, 5, false)])
        let curr = session(ctx, exercise: ex, date: .now, sets: [(100, 5, false)])
        try ctx.save()

        let delta = try XCTUnwrap(SessionDetailLiftStats.rows(for: curr).first!.deltaVsLastLb)
        XCTAssertEqual(delta, -10, accuracy: 0.01)
    }

    // MARK: - Aggregates

    func testPRCount_matchesPerRow() throws {
        let ctx = try makeContext()
        let bench = Exercise(name: "Bench", dayType: .arms); ctx.insert(bench)
        let row = Exercise(name: "Row", dayType: .arms); ctx.insert(row)
        let earlier = Date(timeIntervalSinceNow: -7 * 24 * 3600)
        _ = session(ctx, exercise: bench, date: earlier, sets: [(100, 5, false)])
        _ = session(ctx, exercise: row, date: earlier, sets: [(80, 5, false)])

        // Now build a session with both exercises — bench beats prior, row ties.
        let curr = WorkoutSession(dayType: .arms)
        curr.isCompleted = true; curr.date = .now
        let benchRec = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
        benchRec.exercise = bench; benchRec.session = curr
        let benchSet = SetRecord(setNumber: 1, weightLbs: 110, reps: 5); benchSet.exerciseRecord = benchRec
        benchRec.sets = [benchSet]
        let rowRec = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 1)
        rowRec.exercise = row; rowRec.session = curr
        let rowSet = SetRecord(setNumber: 1, weightLbs: 80, reps: 5); rowSet.exerciseRecord = rowRec
        rowRec.sets = [rowSet]
        curr.exerciseRecords = [benchRec, rowRec]
        ctx.insert(curr); ctx.insert(benchRec); ctx.insert(rowRec); ctx.insert(benchSet); ctx.insert(rowSet)
        try ctx.save()

        XCTAssertEqual(SessionDetailLiftStats.prCount(for: curr), 1)
        XCTAssertEqual(SessionDetailLiftStats.prExerciseNames(for: curr), ["Bench"])
    }
}
