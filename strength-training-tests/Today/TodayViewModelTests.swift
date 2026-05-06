import XCTest
import SwiftData
@testable import strength_training

final class TodayViewModelTests: XCTestCase {

    // MARK: - Label rule (yesterday section eyebrow)

    private func cal() -> Calendar { Calendar(identifier: .gregorian) }

    private func date(daysAgo: Int, from reference: Date = .now) -> Date {
        cal().date(byAdding: .day, value: -daysAgo, to: cal().startOfDay(for: reference))!
    }

    func testLabel_today() {
        XCTAssertEqual(TodayViewModel.relativeDayLabel(for: date(daysAgo: 0), now: .now), "TODAY")
    }

    func testLabel_yesterday() {
        XCTAssertEqual(TodayViewModel.relativeDayLabel(for: date(daysAgo: 1), now: .now), "YESTERDAY")
    }

    func testLabel_threeDaysAgo_returnsWeekdayName() {
        let now = cal().date(from: DateComponents(year: 2026, month: 5, day: 7))!  // Thursday
        let threeDaysAgo = cal().date(byAdding: .day, value: -3, to: now)!         // Monday
        XCTAssertEqual(TodayViewModel.relativeDayLabel(for: threeDaysAgo, now: now), "MONDAY")
    }

    func testLabel_sixDaysAgo_returnsWeekdayName() {
        let now = cal().date(from: DateComponents(year: 2026, month: 5, day: 7))!  // Thursday
        let sixDaysAgo = cal().date(byAdding: .day, value: -6, to: now)!           // Friday (prior week)
        XCTAssertEqual(TodayViewModel.relativeDayLabel(for: sixDaysAgo, now: now), "FRIDAY")
    }

    func testLabel_sevenDaysAgo_returnsNDaysAgo() {
        XCTAssertEqual(TodayViewModel.relativeDayLabel(for: date(daysAgo: 7), now: .now), "7 DAYS AGO")
    }

    func testLabel_twelveDaysAgo() {
        XCTAssertEqual(TodayViewModel.relativeDayLabel(for: date(daysAgo: 12), now: .now), "12 DAYS AGO")
    }

    // MARK: - Initial day-card selection
    //
    // Selection priority (per spec §6.4):
    //   1. Suspended session's day type (if any)
    //   2. Most recent completed session's day type
    //   3. .arms as fallback

    func testInitialDayType_prefersSuspendedOverHistory() throws {
        let container = try ModelContainer(
            for: WorkoutSession.self, ExerciseRecord.self, SetRecord.self, Exercise.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = ModelContext(container)
        // Add a completed Arms session in history
        let armsSession = WorkoutSession(dayType: .arms)
        armsSession.isCompleted = true
        armsSession.date = .now
        ctx.insert(armsSession)
        try ctx.save()

        let vm = TodayViewModel(modelContext: ctx)
        // Suspended is Legs — should win over arms history
        XCTAssertEqual(vm.initialDayType(suspendedDayType: .legs), .legs)
    }

    func testInitialDayType_usesHistoryWhenNoSuspended() throws {
        let container = try ModelContainer(
            for: WorkoutSession.self, ExerciseRecord.self, SetRecord.self, Exercise.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = ModelContext(container)
        // History: Arms, then Legs more recently
        let arms = WorkoutSession(dayType: .arms)
        arms.isCompleted = true
        arms.date = Date(timeIntervalSinceNow: -86400 * 2)
        let legs = WorkoutSession(dayType: .legs)
        legs.isCompleted = true
        legs.date = Date(timeIntervalSinceNow: -86400)
        ctx.insert(arms)
        ctx.insert(legs)
        try ctx.save()

        let vm = TodayViewModel(modelContext: ctx)
        XCTAssertEqual(vm.initialDayType(suspendedDayType: nil), .legs)
    }

    func testInitialDayType_fallsBackToArmsWhenEmpty() throws {
        let container = try ModelContainer(
            for: WorkoutSession.self, ExerciseRecord.self, SetRecord.self, Exercise.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = ModelContext(container)
        let vm = TodayViewModel(modelContext: ctx)
        XCTAssertEqual(vm.initialDayType(suspendedDayType: nil), .arms)
    }

    // MARK: - Card subtitle

    func testCardSubtitle_noHistory_showsLiftCountOnly() throws {
        let container = try ModelContainer(
            for: WorkoutSession.self, ExerciseRecord.self, SetRecord.self, Exercise.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = ModelContext(container)
        // 5 arms exercises, no sessions
        for i in 0..<5 {
            let ex = Exercise(name: "Arms\(i)", dayType: .arms)
            ctx.insert(ex)
        }
        try ctx.save()

        let vm = TodayViewModel(modelContext: ctx)
        XCTAssertEqual(vm.cardSubtitle(for: .arms), "5 lifts · no history")
    }

    func testCardSubtitle_withHistory_showsDuration() throws {
        let container = try ModelContainer(
            for: WorkoutSession.self, ExerciseRecord.self, SetRecord.self, Exercise.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = ModelContext(container)
        for i in 0..<3 {
            let ex = Exercise(name: "Legs\(i)", dayType: .legs)
            ctx.insert(ex)
        }
        let session = WorkoutSession(dayType: .legs)
        session.isCompleted = true
        let start = Date(timeIntervalSinceNow: -3000)  // 50 min ago
        session.date = start
        let ex = Exercise(name: "Squat", dayType: .legs)
        let record = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
        record.exercise = ex
        record.session = session
        let set = SetRecord(setNumber: 1, weightLbs: 100, reps: 5)
        set.exerciseRecord = record
        set.completedAt = start.addingTimeInterval(2820)  // session lasted 47 min
        record.sets = [set]
        session.exerciseRecords = [record]
        ctx.insert(ex)
        ctx.insert(session)
        ctx.insert(record)
        ctx.insert(set)
        try ctx.save()

        let vm = TodayViewModel(modelContext: ctx)
        // 4 legs lifts (3 from loop + 1 "Squat") + 47min last session
        XCTAssertEqual(vm.cardSubtitle(for: .legs), "4 lifts · last session 47 min")
    }

    func testCardSubtitle_fullBody_sumsArmsAndLegs() throws {
        let container = try ModelContainer(
            for: WorkoutSession.self, ExerciseRecord.self, SetRecord.self, Exercise.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = ModelContext(container)
        for i in 0..<4 { ctx.insert(Exercise(name: "A\(i)", dayType: .arms)) }
        for i in 0..<5 { ctx.insert(Exercise(name: "L\(i)", dayType: .legs)) }
        try ctx.save()

        let vm = TodayViewModel(modelContext: ctx)
        XCTAssertEqual(vm.cardSubtitle(for: .fullBody), "9 lifts · no history")
    }

    func testCardSubtitle_durationOverOneHour_showsHoursAndMinutes() throws {
        let container = try ModelContainer(
            for: WorkoutSession.self, ExerciseRecord.self, SetRecord.self, Exercise.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = ModelContext(container)
        ctx.insert(Exercise(name: "A", dayType: .arms))
        let session = WorkoutSession(dayType: .arms)
        session.isCompleted = true
        let start = Date(timeIntervalSinceNow: -10000)
        session.date = start
        let ex = Exercise(name: "Press", dayType: .arms)
        let record = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
        record.exercise = ex
        record.session = session
        let set = SetRecord(setNumber: 1, weightLbs: 100, reps: 5)
        set.exerciseRecord = record
        set.completedAt = start.addingTimeInterval(4500)  // 75 min
        record.sets = [set]
        session.exerciseRecords = [record]
        ctx.insert(ex); ctx.insert(session); ctx.insert(record); ctx.insert(set)
        try ctx.save()

        let vm = TodayViewModel(modelContext: ctx)
        // 2 arms exercises ("A" + "Press") + 1h 15m session
        XCTAssertEqual(vm.cardSubtitle(for: .arms), "2 lifts · last session 1h 15m")
    }

    // MARK: - Week aggregates

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: WorkoutSession.self, ExerciseRecord.self, SetRecord.self, Exercise.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    /// Insert a completed session at a specific date with one set of given weight × reps.
    private func insertCompletedSession(
        _ ctx: ModelContext,
        dayType: DayType,
        date: Date,
        weight: Double,
        reps: Int
    ) {
        let session = WorkoutSession(dayType: dayType)
        session.isCompleted = true
        session.date = date
        let ex = Exercise(name: "x", dayType: dayType == .fullBody ? .arms : dayType)
        let record = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
        record.exercise = ex
        record.session = session
        let set = SetRecord(setNumber: 1, weightLbs: weight, reps: reps)
        set.exerciseRecord = record
        set.completedAt = date.addingTimeInterval(60)
        record.sets = [set]
        session.exerciseRecords = [record]
        ctx.insert(ex); ctx.insert(session); ctx.insert(record); ctx.insert(set)
    }

    func testWeekStats_aggregatesSessionsInISOWeek() throws {
        let ctx = try makeContext()
        // Pin "now" to Wednesday May 6, 2026 → ISO week is Mon May 4 – Sun May 10
        let cal = Calendar(identifier: .gregorian)
        let now = cal.date(from: DateComponents(year: 2026, month: 5, day: 6, hour: 12))!
        let monThisWeek = cal.date(from: DateComponents(year: 2026, month: 5, day: 4, hour: 8))!
        let wedThisWeek = cal.date(from: DateComponents(year: 2026, month: 5, day: 6, hour: 18))!
        let sunLastWeek = cal.date(from: DateComponents(year: 2026, month: 5, day: 3, hour: 10))!

        insertCompletedSession(ctx, dayType: .arms, date: monThisWeek, weight: 100, reps: 10)
        insertCompletedSession(ctx, dayType: .legs, date: wedThisWeek, weight: 200, reps: 5)
        insertCompletedSession(ctx, dayType: .arms, date: sunLastWeek, weight: 50, reps: 10)  // last week, excluded

        let vm = TodayViewModel(modelContext: ctx)
        let stats = vm.thisWeekStats(now: now)
        XCTAssertEqual(stats.sessionCount, 2)
        XCTAssertEqual(stats.totalVolume, 100 * 10 + 200 * 5)  // 1000 + 1000 = 2000
        XCTAssertEqual(stats.totalSets, 2)
    }

    func testWeekStats_emptyWeek_returnsZeroes() throws {
        let ctx = try makeContext()
        let vm = TodayViewModel(modelContext: ctx)
        let stats = vm.thisWeekStats(now: .now)
        XCTAssertEqual(stats.sessionCount, 0)
        XCTAssertEqual(stats.totalVolume, 0)
        XCTAssertEqual(stats.totalSets, 0)
    }

    func testWeekDayTypes_mapsCompletedDaysToDayType() throws {
        let ctx = try makeContext()
        let cal = Calendar(identifier: .gregorian)
        let now = cal.date(from: DateComponents(year: 2026, month: 5, day: 6, hour: 12))!  // Wed
        let monThisWeek = cal.date(from: DateComponents(year: 2026, month: 5, day: 4, hour: 8))!
        let wedThisWeek = cal.date(from: DateComponents(year: 2026, month: 5, day: 6, hour: 18))!

        insertCompletedSession(ctx, dayType: .arms, date: monThisWeek, weight: 100, reps: 10)
        insertCompletedSession(ctx, dayType: .legs, date: wedThisWeek, weight: 200, reps: 5)

        let vm = TodayViewModel(modelContext: ctx)
        let dayMap = vm.weekDayTypes(now: now)
        XCTAssertEqual(dayMap[0], .arms)   // Mon
        XCTAssertNil(dayMap[1])            // Tue (rest)
        XCTAssertEqual(dayMap[2], .legs)   // Wed
        XCTAssertNil(dayMap[3])            // Thu (future)
        XCTAssertNil(dayMap[6])            // Sun (future)
    }

    func testWeekDelta_returnsNilWhenLastWeekZero() throws {
        let ctx = try makeContext()
        let vm = TodayViewModel(modelContext: ctx)
        // No history at all
        XCTAssertNil(vm.weeklyVolumeDelta(now: .now))
    }

    func testWeekDelta_computesPercentChange() throws {
        let ctx = try makeContext()
        let cal = Calendar(identifier: .gregorian)
        let now = cal.date(from: DateComponents(year: 2026, month: 5, day: 6, hour: 12))!  // Wed
        // This week: 2000 lb total
        insertCompletedSession(ctx, dayType: .arms, date: cal.date(from: DateComponents(year: 2026, month: 5, day: 4, hour: 10))!, weight: 200, reps: 5)
        insertCompletedSession(ctx, dayType: .legs, date: cal.date(from: DateComponents(year: 2026, month: 5, day: 6, hour: 10))!, weight: 200, reps: 5)
        // Last week: 1000 lb
        insertCompletedSession(ctx, dayType: .arms, date: cal.date(from: DateComponents(year: 2026, month: 4, day: 27, hour: 10))!, weight: 100, reps: 10)

        let vm = TodayViewModel(modelContext: ctx)
        // (2000 - 1000) / 1000 = +1.0 = +100%
        XCTAssertEqual(vm.weeklyVolumeDelta(now: now) ?? 0, 1.0, accuracy: 0.001)
    }
}
