// strength-training-tests/Progress/ExerciseDrillDownStatsTests.swift
import XCTest
import SwiftData
@testable import strength_training

final class ExerciseDrillDownStatsTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: WorkoutSession.self, ExerciseRecord.self, SetRecord.self, Exercise.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @discardableResult
    private func session(_ ctx: ModelContext, exercise: Exercise, date: Date,
                          completed: Bool = true,
                          sets: [(weight: Double, reps: Int, warmup: Bool)]) -> WorkoutSession {
        let s = WorkoutSession(dayType: exercise.dayType)
        s.isCompleted = completed
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

    private var fixedCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var dc = DateComponents(); dc.year = y; dc.month = m; dc.day = d
        return fixedCalendar.date(from: dc)!
    }

    // MARK: - personalBest

    func testPersonalBest_returnsNil_whenNoCompletedSets() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        // Only an in-progress session — should be excluded.
        _ = session(ctx, exercise: ex, date: .now, completed: false,
                     sets: [(100, 5, false)])
        try ctx.save()

        XCTAssertNil(ExerciseDrillDownStats.personalBest(for: ex))
    }

    func testPersonalBest_returnsNil_whenOnlyWarmups() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        _ = session(ctx, exercise: ex, date: .now, sets: [(45, 10, true), (45, 10, true)])
        try ctx.save()

        XCTAssertNil(ExerciseDrillDownStats.personalBest(for: ex))
    }

    func testPersonalBest_singleSession_returnsThatSet() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        let now = date(2026, 5, 6)
        _ = session(ctx, exercise: ex, date: now, sets: [(100, 5, false), (110, 3, false)])
        try ctx.save()

        let best = ExerciseDrillDownStats.personalBest(for: ex, now: now, calendar: fixedCalendar)
        XCTAssertNotNil(best)
        // 110@3 has higher e1RM than 100@5, so best should be (110, 3).
        XCTAssertEqual(best?.weight, 110)
        XCTAssertEqual(best?.reps, 3)
        XCTAssertTrue(best?.isToday ?? false)
    }

    func testPersonalBest_isTodayFalse_whenBestIsOlderSession() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        let older = date(2026, 4, 1)
        let now = date(2026, 5, 6)
        // Older session has the best e1RM.
        _ = session(ctx, exercise: ex, date: older, sets: [(200, 5, false)])
        _ = session(ctx, exercise: ex, date: now, sets: [(100, 5, false)])
        try ctx.save()

        let best = ExerciseDrillDownStats.personalBest(for: ex, now: now, calendar: fixedCalendar)
        XCTAssertEqual(best?.weight, 200)
        XCTAssertFalse(best?.isToday ?? true)
    }

    // MARK: - lastTenTopSetBars

    func testLastTenTopSetBars_empty_whenNoSessions() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        try ctx.save()

        XCTAssertEqual(ExerciseDrillDownStats.lastTenTopSetBars(for: ex), [])
    }

    func testLastTenTopSetBars_limitsTo10_andOldestFirst() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        // Create 12 sessions on consecutive days. Weight increases each session.
        for i in 0..<12 {
            let d = date(2026, 1, 1).addingTimeInterval(TimeInterval(i) * 86_400)
            _ = session(ctx, exercise: ex, date: d, sets: [(Double(100 + i), 5, false)])
        }
        try ctx.save()

        let bars = ExerciseDrillDownStats.lastTenTopSetBars(for: ex)
        XCTAssertEqual(bars.count, 10)
        // Oldest-first ordering means weights ascend: first bar = 102 (i=2), last = 111 (i=11).
        XCTAssertEqual(bars.first?.weight, 102)
        XCTAssertEqual(bars.last?.weight, 111)
    }

    func testLastTenTopSetBars_isLatest_onlyOnRightmost() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        for i in 0..<3 {
            let d = date(2026, 1, 1).addingTimeInterval(TimeInterval(i) * 86_400)
            _ = session(ctx, exercise: ex, date: d, sets: [(Double(100 + i), 5, false)])
        }
        try ctx.save()

        let bars = ExerciseDrillDownStats.lastTenTopSetBars(for: ex)
        XCTAssertEqual(bars.count, 3)
        XCTAssertFalse(bars[0].isLatest)
        XCTAssertFalse(bars[1].isLatest)
        XCTAssertTrue(bars[2].isLatest)
    }

    func testLastTenTopSetBars_PRFlag_setsForStrictlyImprovingSessions() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        // Session 1: 100@5, Session 2: 100@5 (tie — not PR), Session 3: 110@5 (PR).
        let d1 = date(2026, 1, 1)
        let d2 = date(2026, 1, 2)
        let d3 = date(2026, 1, 3)
        _ = session(ctx, exercise: ex, date: d1, sets: [(100, 5, false)])
        _ = session(ctx, exercise: ex, date: d2, sets: [(100, 5, false)])
        _ = session(ctx, exercise: ex, date: d3, sets: [(110, 5, false)])
        try ctx.save()

        let bars = ExerciseDrillDownStats.lastTenTopSetBars(for: ex)
        XCTAssertEqual(bars.count, 3)
        XCTAssertTrue(bars[0].isPR, "first session is always a PR")
        XCTAssertFalse(bars[1].isPR, "tie should not be a PR")
        XCTAssertTrue(bars[2].isPR, "strictly higher e1RM should be a PR")
    }

    func testLastTenTopSetBars_topSet_choosesHighestE1RM() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        // 100@5 and 110@3 — 110@3 has higher e1RM.
        _ = session(ctx, exercise: ex, date: date(2026, 1, 1),
                     sets: [(45, 10, true), (100, 5, false), (110, 3, false)])
        try ctx.save()

        let bars = ExerciseDrillDownStats.lastTenTopSetBars(for: ex)
        XCTAssertEqual(bars.count, 1)
        XCTAssertEqual(bars[0].weight, 110)
        XCTAssertEqual(bars[0].reps, 3)
    }

    // MARK: - recentSessionRows

    func testRecentSessionRows_limit_takesNewestN() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        for i in 0..<6 {
            let d = date(2026, 1, 1).addingTimeInterval(TimeInterval(i) * 86_400)
            _ = session(ctx, exercise: ex, date: d, sets: [(Double(100 + i), 5, false)])
        }
        try ctx.save()

        let rows = ExerciseDrillDownStats.recentSessionRows(for: ex, limit: 4)
        XCTAssertEqual(rows.count, 4)
        // Newest first: weights descend 105 → 102.
        XCTAssertEqual(rows.map(\.topWeightLb), [105, 104, 103, 102])
    }

    func testRecentSessionRows_PR_flagsLatestPRSession() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        let d1 = date(2026, 1, 1)
        let d2 = date(2026, 1, 2)
        _ = session(ctx, exercise: ex, date: d1, sets: [(100, 5, false)])
        _ = session(ctx, exercise: ex, date: d2, sets: [(110, 5, false)])
        try ctx.save()

        let rows = ExerciseDrillDownStats.recentSessionRows(for: ex, limit: 10)
        XCTAssertEqual(rows.count, 2)
        // Newest first.
        XCTAssertEqual(rows[0].topWeightLb, 110)
        XCTAssertTrue(rows[0].isPR)
        XCTAssertTrue(rows[1].isPR, "first-ever session is always a PR")
    }

    func testRecentSessionRows_setsCount_excludesWarmups() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        _ = session(ctx, exercise: ex, date: date(2026, 1, 1),
                     sets: [(45, 10, true), (45, 10, true), (100, 5, false), (100, 5, false)])
        try ctx.save()

        let rows = ExerciseDrillDownStats.recentSessionRows(for: ex)
        XCTAssertEqual(rows.first?.setsCount, 2)
    }

    func testRecentSessionRows_dateLabel_today() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        let now = date(2026, 5, 6)
        _ = session(ctx, exercise: ex, date: now, sets: [(100, 5, false)])
        try ctx.save()

        let rows = ExerciseDrillDownStats.recentSessionRows(
            for: ex, now: now, calendar: fixedCalendar
        )
        XCTAssertEqual(rows.first?.dateLabel, "Today")
    }

    // MARK: - relativeLabel

    func testRelativeLabel_today() {
        let now = date(2026, 5, 6)
        XCTAssertEqual(
            ExerciseDrillDownStats.relativeLabel(for: now, now: now, calendar: fixedCalendar),
            "Today"
        )
    }

    func testRelativeLabel_yesterday() {
        let now = date(2026, 5, 6)
        let yesterday = date(2026, 5, 5)
        XCTAssertEqual(
            ExerciseDrillDownStats.relativeLabel(for: yesterday, now: now, calendar: fixedCalendar),
            "Yesterday"
        )
    }

    func testRelativeLabel_threeDaysAgo() {
        let now = date(2026, 5, 6)
        let three = date(2026, 5, 3)
        XCTAssertEqual(
            ExerciseDrillDownStats.relativeLabel(for: three, now: now, calendar: fixedCalendar),
            "3 days ago"
        )
    }

    func testRelativeLabel_threeWeeksAgo() {
        let now = date(2026, 5, 22)
        let twentyOneDaysAgo = date(2026, 5, 1)  // 21 days = 3 weeks
        XCTAssertEqual(
            ExerciseDrillDownStats.relativeLabel(
                for: twentyOneDaysAgo, now: now, calendar: fixedCalendar
            ),
            "3 wks ago"
        )
    }

    func testRelativeLabel_formattedForFarPast() {
        // 8+ weeks → "MMM d" formatted.
        let now = date(2026, 5, 6)
        let farPast = date(2026, 1, 15)  // ~16 weeks
        let label = ExerciseDrillDownStats.relativeLabel(
            for: farPast, now: now, calendar: fixedCalendar
        )
        // Don't assert exact locale-dependent string, but confirm it's not the "wks" form.
        XCTAssertFalse(label.contains("wks"))
        XCTAssertFalse(label.contains("days"))
        XCTAssertNotEqual(label, "Today")
        XCTAssertNotEqual(label, "Yesterday")
    }
}
