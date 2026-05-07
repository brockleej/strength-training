import XCTest
import SwiftData
@testable import strength_training

final class HistorySummaryStatsTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: WorkoutSession.self, ExerciseRecord.self, SetRecord.self, Exercise.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    /// Build & insert a session with one exercise record + sets.
    /// `date` is the session's date; sets' completedAt isn't relevant here.
    @discardableResult
    private func session(_ ctx: ModelContext,
                         exercise: Exercise,
                         date: Date,
                         dayType: DayType = .arms,
                         sets: [(weight: Double, reps: Int, warmup: Bool)]) -> WorkoutSession {
        let s = WorkoutSession(dayType: dayType)
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
        return cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var dc = DateComponents(); dc.year = y; dc.month = m; dc.day = d
        return utcCalendar.date(from: dc)!
    }

    // MARK: - Empty / boundary

    func testEmpty_returnsZeros() throws {
        let stats = HistorySummaryStats.thisMonth(
            allCompletedSessions: [],
            now: date(2026, 5, 6),
            calendar: utcCalendar
        )
        XCTAssertEqual(stats, .init(sessionCount: 0, totalVolumeLb: 0, prCount: 0))
    }

    func testSessionsOutsideCurrentMonth_excluded() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        _ = session(ctx, exercise: ex, date: date(2026, 4, 28), sets: [(100, 5, false)])  // April
        _ = session(ctx, exercise: ex, date: date(2026, 5, 2), sets: [(110, 5, false)])   // May
        try ctx.save()

        let stats = HistorySummaryStats.thisMonth(
            allCompletedSessions: ctx.fetchAllSessions(),
            now: date(2026, 5, 6),
            calendar: utcCalendar
        )
        XCTAssertEqual(stats.sessionCount, 1)
        XCTAssertEqual(stats.totalVolumeLb, 550)  // 110*5
    }

    // MARK: - Volume

    func testVolume_excludesWarmupSets() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        _ = session(ctx, exercise: ex, date: date(2026, 5, 1), sets: [
            (45, 10, true),    // warmup — excluded
            (100, 5, false),   // 500
            (105, 5, false)    // 525
        ])
        try ctx.save()

        let stats = HistorySummaryStats.thisMonth(
            allCompletedSessions: ctx.fetchAllSessions(),
            now: date(2026, 5, 6),
            calendar: utcCalendar
        )
        XCTAssertEqual(stats.totalVolumeLb, 1025)
    }

    // MARK: - PR detection

    func testPR_firstSessionOfExercise_countsAsPR() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        _ = session(ctx, exercise: ex, date: date(2026, 5, 1), sets: [(100, 5, false)])
        try ctx.save()

        let stats = HistorySummaryStats.thisMonth(
            allCompletedSessions: ctx.fetchAllSessions(),
            now: date(2026, 5, 6),
            calendar: utcCalendar
        )
        XCTAssertEqual(stats.prCount, 1)
    }

    func testPR_secondSessionBeatingFirst_countsAsPR() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        _ = session(ctx, exercise: ex, date: date(2026, 4, 28), sets: [(100, 5, false)])
        _ = session(ctx, exercise: ex, date: date(2026, 5, 1), sets: [(110, 5, false)])
        try ctx.save()

        let stats = HistorySummaryStats.thisMonth(
            allCompletedSessions: ctx.fetchAllSessions(),
            now: date(2026, 5, 6),
            calendar: utcCalendar
        )
        // Only the May session contributes (April excluded by month filter).
        XCTAssertEqual(stats.prCount, 1)
    }

    func testPR_equalToPriorBest_doesNotCount() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        _ = session(ctx, exercise: ex, date: date(2026, 4, 28), sets: [(100, 5, false)])
        _ = session(ctx, exercise: ex, date: date(2026, 5, 1), sets: [(100, 5, false)])  // tie
        try ctx.save()

        let stats = HistorySummaryStats.thisMonth(
            allCompletedSessions: ctx.fetchAllSessions(),
            now: date(2026, 5, 6),
            calendar: utcCalendar
        )
        XCTAssertEqual(stats.prCount, 0)
    }

    func testPR_warmupSetsIgnored() throws {
        let ctx = try makeContext()
        let ex = Exercise(name: "Bench", dayType: .arms); ctx.insert(ex)
        _ = session(ctx, exercise: ex, date: date(2026, 5, 1), sets: [
            (45, 10, true),  // warmup; should not establish a PR baseline
            (100, 5, false)
        ])
        try ctx.save()

        let stats = HistorySummaryStats.thisMonth(
            allCompletedSessions: ctx.fetchAllSessions(),
            now: date(2026, 5, 6),
            calendar: utcCalendar
        )
        XCTAssertEqual(stats.prCount, 1)
    }

    // MARK: - Volume formatting

    func testFormatVolume_under100k_useThousandsSeparator() {
        XCTAssertEqual(HistorySummaryStats.formatVolume(12_840), "12,840")
    }

    func testFormatVolume_atOrAbove100k_usesKAbbreviation() {
        XCTAssertEqual(HistorySummaryStats.formatVolume(187_000), "187k")
        XCTAssertEqual(HistorySummaryStats.formatVolume(187_500), "188k")
    }
}

// MARK: - Test helper

private extension ModelContext {
    func fetchAllSessions() -> [WorkoutSession] {
        (try? fetch(FetchDescriptor<WorkoutSession>())) ?? []
    }
}
