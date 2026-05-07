import XCTest
import SwiftData
@testable import strength_training

final class WorkoutSummaryStatsTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: WorkoutSession.self, ExerciseRecord.self, SetRecord.self, Exercise.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    /// Build a session containing one exercise record + N sets, returning the session.
    /// Each set's completedAt is start + (i+1)*60s so duration math is predictable.
    @discardableResult
    private func session(_ ctx: ModelContext, dayType: DayType = .arms,
                          start: Date, sets: [(Double, Int, Bool)]) -> WorkoutSession {
        let s = WorkoutSession(dayType: dayType)
        s.isCompleted = true
        s.date = start
        let ex = Exercise(name: "Lift", dayType: dayType == .fullBody ? .arms : dayType)
        let r = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
        r.exercise = ex
        r.session = s
        for (i, t) in sets.enumerated() {
            let set = SetRecord(setNumber: i + 1, weightLbs: t.0, reps: t.1)
            set.exerciseRecord = r
            set.isWarmup = t.2
            set.completedAt = start.addingTimeInterval(Double(i + 1) * 60)
            if r.sets == nil { r.sets = [] }
            r.sets?.append(set)
            ctx.insert(set)
        }
        s.exerciseRecords = [r]
        ctx.insert(ex); ctx.insert(s); ctx.insert(r)
        return s
    }

    // MARK: - Duration

    func testDuration_lastSetMinusStart() throws {
        let ctx = try makeContext()
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let s = session(ctx, start: start, sets: [
            (100, 10, false),  // completedAt = start + 60
            (105, 8, false),   // completedAt = start + 120
            (110, 6, false)    // completedAt = start + 180
        ])
        try ctx.save()

        XCTAssertEqual(WorkoutSummaryStats.durationSeconds(for: s), 180, accuracy: 0.5)
    }

    func testDuration_noSets_returnsZero() throws {
        let ctx = try makeContext()
        let s = WorkoutSession(dayType: .arms)
        s.isCompleted = true
        s.date = Date()
        ctx.insert(s)
        try ctx.save()

        XCTAssertEqual(WorkoutSummaryStats.durationSeconds(for: s), 0, accuracy: 0.5)
    }

    // MARK: - Volume

    func testVolume_sumsAllNonWarmupSets() throws {
        let ctx = try makeContext()
        let s = session(ctx, start: .now, sets: [
            (100, 10, false),  // 1000
            (105, 8, false),   // 840
            (110, 6, false)    // 660
        ])
        try ctx.save()

        XCTAssertEqual(WorkoutSummaryStats.totalVolume(for: s), 2500)
    }

    func testVolume_excludesWarmups() throws {
        let ctx = try makeContext()
        let s = session(ctx, start: .now, sets: [
            (45, 10, true),   // warmup — excluded
            (100, 5, false)   // 500
        ])
        try ctx.save()

        XCTAssertEqual(WorkoutSummaryStats.totalVolume(for: s), 500)
    }

    // MARK: - Sets

    func testSets_countsNonWarmupOnly() throws {
        let ctx = try makeContext()
        let s = session(ctx, start: .now, sets: [
            (45, 10, true),
            (100, 5, false),
            (105, 5, false),
            (110, 5, false)
        ])
        try ctx.save()

        XCTAssertEqual(WorkoutSummaryStats.totalSets(for: s), 3)
    }

    func testSets_emptyReturnsZero() throws {
        let ctx = try makeContext()
        let s = WorkoutSession(dayType: .legs)
        s.isCompleted = true
        s.date = Date()
        ctx.insert(s)
        try ctx.save()

        XCTAssertEqual(WorkoutSummaryStats.totalSets(for: s), 0)
    }

    // MARK: - Duration formatting

    func testFormatDurationMin_under60Sec_roundsToZero() {
        XCTAssertEqual(WorkoutSummaryStats.formatDurationMin(45), 0)
    }

    func testFormatDurationMin_oneMinute() {
        XCTAssertEqual(WorkoutSummaryStats.formatDurationMin(60), 1)
    }

    func testFormatDurationMin_47min() {
        // 47 * 60 = 2820
        XCTAssertEqual(WorkoutSummaryStats.formatDurationMin(2820), 47)
    }

    func testFormatDurationMin_floorsPartialMinute() {
        // 47 min 59 sec = 2879 → 47
        XCTAssertEqual(WorkoutSummaryStats.formatDurationMin(2879), 47)
    }
}
