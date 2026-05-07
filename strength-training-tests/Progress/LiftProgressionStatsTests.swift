// strength-training-tests/Progress/LiftProgressionStatsTests.swift
import XCTest
import SwiftData
@testable import strength_training

final class LiftProgressionStatsTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: WorkoutSession.self, ExerciseRecord.self, SetRecord.self, Exercise.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @discardableResult
    private func session(_ ctx: ModelContext, exercise: Exercise, date: Date,
                          sets: [(weight: Double, reps: Int, warmup: Bool)]) -> WorkoutSession {
        let s = WorkoutSession(dayType: exercise.dayType)
        s.isCompleted = true
        s.date = date
        let r = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
        r.exercise = exercise; r.session = s
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

    func testEmpty_returnsNoRows() throws {
        let ctx = try makeContext()
        let rows = LiftProgressionStats.rows(in: .threeMonths, exercises: [])
        XCTAssertEqual(rows, [])
    }

    func testExerciseWithNoInPeriodSets_excluded() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        // Only set is from a year ago — outside .threeMonths
        _ = session(ctx, exercise: ex, date: Date(timeIntervalSinceNow: -365 * 24 * 3600),
                     sets: [(100, 5, false)])
        try ctx.save()

        let rows = LiftProgressionStats.rows(in: .threeMonths, exercises: [ex])
        XCTAssertEqual(rows.count, 0)
    }

    func testTopWeight_takesMaxNonWarmupInPeriod() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        _ = session(ctx, exercise: ex, date: .now, sets: [
            (45, 10, true),  // warmup ignored
            (100, 5, false),
            (110, 5, false)
        ])
        try ctx.save()

        let rows = LiftProgressionStats.rows(in: .threeMonths, exercises: [ex])
        XCTAssertEqual(rows.first!.topWeightLb, 110)
    }

    func testProgressPct_isClampedToZeroOne() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        // Period top = 110, all-time best = 200 → 0.55
        let earlier = Date(timeIntervalSinceNow: -90 * 24 * 3600)
        _ = session(ctx, exercise: ex, date: earlier, sets: [(200, 5, false)])  // outside .month
        _ = session(ctx, exercise: ex, date: .now, sets: [(110, 5, false)])
        try ctx.save()

        let rows = LiftProgressionStats.rows(in: .month, exercises: [ex])
        let row = rows.first!
        XCTAssertEqual(row.allTimeBestLb, 200)
        XCTAssertEqual(row.topWeightLb, 110)
        XCTAssertEqual(row.progressPct, 0.55, accuracy: 0.01)
    }

    func testDelta_increase_isPositive() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        let earlier = Date(timeIntervalSinceNow: -7 * 24 * 3600)
        _ = session(ctx, exercise: ex, date: earlier, sets: [(100, 5, false)])
        _ = session(ctx, exercise: ex, date: .now, sets: [(105, 5, false)])
        try ctx.save()

        let rows = LiftProgressionStats.rows(in: .threeMonths, exercises: [ex])
        XCTAssertEqual(rows.first!.deltaVsLastSessionLb!, 5, accuracy: 0.01)
    }

    func testIsPR_strictGreaterThan() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        let earlier = Date(timeIntervalSinceNow: -7 * 24 * 3600)
        _ = session(ctx, exercise: ex, date: earlier, sets: [(100, 5, false)])
        // Tie: same e1RM
        _ = session(ctx, exercise: ex, date: .now, sets: [(100, 5, false)])
        try ctx.save()

        let rows = LiftProgressionStats.rows(in: .threeMonths, exercises: [ex])
        XCTAssertFalse(rows.first!.isPR)
    }

    func testSorting_descByTopWeight() throws {
        let ctx = try makeContext()
        let bench = Exercise(name: "Bench", dayType: .arms); ctx.insert(bench)
        let row = Exercise(name: "Row", dayType: .arms); ctx.insert(row)
        _ = session(ctx, exercise: bench, date: .now, sets: [(110, 5, false)])
        _ = session(ctx, exercise: row, date: .now, sets: [(150, 5, false)])
        try ctx.save()

        let rows = LiftProgressionStats.rows(in: .threeMonths, exercises: [bench, row])
        XCTAssertEqual(rows.map(\.exerciseName), ["Row", "Bench"])
    }
}
