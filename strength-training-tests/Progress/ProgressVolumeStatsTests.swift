// strength-training-tests/Progress/ProgressVolumeStatsTests.swift
import XCTest
import SwiftData
@testable import strength_training

final class ProgressVolumeStatsTests: XCTestCase {

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

    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.firstWeekday = 2  // Monday-start to match design's week
        return cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var dc = DateComponents(); dc.year = y; dc.month = m; dc.day = d
        return utcCalendar.date(from: dc)!
    }

    private func fetchAll(_ ctx: ModelContext) -> [WorkoutSession] {
        (try? ctx.fetch(FetchDescriptor<WorkoutSession>())) ?? []
    }

    // MARK: - Total volume

    func testTotalVolume_includesNonWarmupOnly_inRange() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        // In range (last week)
        _ = session(ctx, exercise: ex, date: date(2026, 5, 4), sets: [
            (45, 10, true),    // warmup excluded
            (100, 5, false)    // 500
        ])
        // Out of range
        _ = session(ctx, exercise: ex, date: date(2026, 4, 1), sets: [(200, 5, false)])
        try ctx.save()

        let total = ProgressVolumeStats.totalVolume(
            in: .week,
            sessions: fetchAll(ctx),
            now: date(2026, 5, 6),
            calendar: utcCalendar
        )
        XCTAssertEqual(total, 500, accuracy: 0.01)
    }

    func testTotalVolume_allRange_includesEverything() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        _ = session(ctx, exercise: ex, date: date(2025, 1, 1), sets: [(100, 5, false)])
        _ = session(ctx, exercise: ex, date: date(2026, 5, 1), sets: [(110, 5, false)])
        try ctx.save()

        let total = ProgressVolumeStats.totalVolume(
            in: .all,
            sessions: fetchAll(ctx),
            now: date(2026, 5, 6),
            calendar: utcCalendar
        )
        XCTAssertEqual(total, 100 * 5 + 110 * 5, accuracy: 0.01)
    }

    // MARK: - Delta

    func testDeltaPct_returnsNilWhenNoPriorWindow() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        _ = session(ctx, exercise: ex, date: date(2026, 5, 4), sets: [(100, 5, false)])
        try ctx.save()

        let delta = ProgressVolumeStats.deltaPct(
            in: .week,
            sessions: fetchAll(ctx),
            now: date(2026, 5, 6),
            calendar: utcCalendar
        )
        XCTAssertNil(delta)
    }

    func testDeltaPct_currentVsPriorWindow_positive() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        // Prior week = April 23-30: 100×5 = 500
        _ = session(ctx, exercise: ex, date: date(2026, 4, 28), sets: [(100, 5, false)])
        // Current week = April 30 - May 6: 110×5 = 550 (10% increase)
        _ = session(ctx, exercise: ex, date: date(2026, 5, 4), sets: [(110, 5, false)])
        try ctx.save()

        let delta = ProgressVolumeStats.deltaPct(
            in: .week,
            sessions: fetchAll(ctx),
            now: date(2026, 5, 6),
            calendar: utcCalendar
        )
        XCTAssertNotNil(delta)
        XCTAssertEqual(delta!, 10, accuracy: 0.5)
    }

    // MARK: - Bucketed series

    func testBucketedSeries_week_returns7DailyPoints() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        _ = session(ctx, exercise: ex, date: date(2026, 5, 4), sets: [(100, 5, false)])
        try ctx.save()

        let series = ProgressVolumeStats.bucketedSeries(
            in: .week,
            sessions: fetchAll(ctx),
            now: date(2026, 5, 6),
            calendar: utcCalendar
        )
        XCTAssertEqual(series.count, 7)
        // The 5/4 session (Mon) lands in one of the 7 buckets
        let nonZero = series.filter { $0.volume > 0 }
        XCTAssertEqual(nonZero.count, 1)
        XCTAssertEqual(nonZero.first!.volume, 500, accuracy: 0.01)
    }

    func testBucketedSeries_month_returns5WeeklyPoints() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        try ctx.save()

        let series = ProgressVolumeStats.bucketedSeries(
            in: .month,
            sessions: fetchAll(ctx),
            now: date(2026, 5, 6),
            calendar: utcCalendar
        )
        XCTAssertEqual(series.count, 5)
    }

    func testBucketedSeries_threeMonths_returns12WeeklyPoints() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        try ctx.save()

        let series = ProgressVolumeStats.bucketedSeries(
            in: .threeMonths,
            sessions: fetchAll(ctx),
            now: date(2026, 5, 6),
            calendar: utcCalendar
        )
        XCTAssertEqual(series.count, 12)
        XCTAssertTrue(series.allSatisfy { $0.volume == 0 })
    }

    func testBucketedSeries_year_returns12MonthlyPoints() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        try ctx.save()

        let series = ProgressVolumeStats.bucketedSeries(
            in: .year,
            sessions: fetchAll(ctx),
            now: date(2026, 5, 6),
            calendar: utcCalendar
        )
        XCTAssertEqual(series.count, 12)
    }

    func testBucketedSeries_emptyForAllWithNoSessions() throws {
        let ctx = try makeContext()
        let series = ProgressVolumeStats.bucketedSeries(
            in: .all,
            sessions: fetchAll(ctx),
            now: date(2026, 5, 6),
            calendar: utcCalendar
        )
        XCTAssertEqual(series.count, 0)
    }
}
