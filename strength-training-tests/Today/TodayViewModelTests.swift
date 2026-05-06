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
}
