//
//  MonthlyOverloadTests.swift
//  strength-training-tests
//
//  Documents the monthly-overload rules:
//  - Window is the user's local calendar month vs the previous calendar month.
//  - Best working set = heaviest non-warmup; weight ties break to higher reps;
//    remaining ties keep the first occurrence.
//  - Modes are combined. Warm-ups are excluded. A missing month is not a zero.
//

import XCTest
@testable import strength_training

final class MonthlyOverloadTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Denver")!
        cal.locale = Locale(identifier: "en_US")
        return cal
    }

    /// Wednesday 2026-08-12 12:00 America/Denver
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: 12, hour: 12))!
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 18) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func set(_ weight: Double, _ reps: Int, warmup: Bool = false) -> MonthlyOverload.SetInput {
        MonthlyOverload.SetInput(weightLbs: weight, reps: reps, isWarmup: warmup)
    }

    private func lift(
        id: UUID = UUID(),
        name: String,
        day: String = "Push",
        sort: Int = 0,
        _ sets: MonthlyOverload.SetInput...
    ) -> MonthlyOverload.LiftInput {
        MonthlyOverload.LiftInput(
            exerciseID: id,
            exerciseName: name,
            dayTypeName: day,
            sortOrder: sort,
            sets: sets
        )
    }

    private func session(_ date: Date, _ lifts: MonthlyOverload.LiftInput...) -> MonthlyOverload.SessionInput {
        MonthlyOverload.SessionInput(date: date, lifts: lifts)
    }

    private func review(
        _ sessions: [MonthlyOverload.SessionInput],
        now: Date? = nil,
        dayOrder: [String] = ["Push", "Pull", "Legs"]
    ) -> MonthlyOverload.Review {
        MonthlyOverload.review(
            sessions: sessions,
            now: now ?? self.now,
            calendar: calendar,
            dayOrder: dayOrder
        )
    }

    // MARK: - Month windows

    func test_monthInterval_isLocalCalendarMonth() {
        let interval = MonthlyOverload.monthInterval(containing: now, calendar: calendar)!
        XCTAssertEqual(calendar.component(.year, from: interval.start), 2026)
        XCTAssertEqual(calendar.component(.month, from: interval.start), 8)
        XCTAssertEqual(calendar.component(.day, from: interval.start), 1)
        // End is exclusive first instant of September (DateInterval of .month).
        let endComps = calendar.dateComponents([.year, .month, .day], from: interval.end)
        XCTAssertEqual(endComps.year, 2026)
        XCTAssertEqual(endComps.month, 9)
        XCTAssertEqual(endComps.day, 1)
    }

    func test_previousMonth_isJulyWhenNowIsAugust() {
        let thisMonth = MonthlyOverload.monthInterval(containing: now, calendar: calendar)!
        let last = MonthlyOverload.previousMonthInterval(before: thisMonth, calendar: calendar)!
        XCTAssertEqual(calendar.component(.month, from: last.start), 7)
        XCTAssertEqual(calendar.component(.year, from: last.start), 2026)
        XCTAssertEqual(calendar.component(.day, from: last.start), 1)
    }

    func test_previousMonth_wrapsYearBoundary() {
        let january = date(2026, 1, 15)
        let thisMonth = MonthlyOverload.monthInterval(containing: january, calendar: calendar)!
        let last = MonthlyOverload.previousMonthInterval(before: thisMonth, calendar: calendar)!
        XCTAssertEqual(calendar.component(.year, from: last.start), 2025)
        XCTAssertEqual(calendar.component(.month, from: last.start), 12)
        XCTAssertTrue(last.contains(date(2025, 12, 31, hour: 23)))
        XCTAssertFalse(last.contains(date(2026, 1, 1, hour: 0)))
    }

    func test_windows_includeLastInstantOfMonth_excludeNextMonthStart() {
        let windows = MonthlyOverload.monthWindows(now: now, calendar: calendar)!
        XCTAssertTrue(windows.this.contains(date(2026, 8, 31, hour: 23)))
        XCTAssertFalse(windows.this.contains(date(2026, 9, 1, hour: 0)))
        XCTAssertTrue(windows.last.contains(date(2026, 7, 31, hour: 23)))
        XCTAssertFalse(windows.last.contains(date(2026, 8, 1, hour: 0)))
    }

    func test_february_nonLeapLength() {
        let march = date(2026, 3, 10)
        let thisMonth = MonthlyOverload.monthInterval(containing: march, calendar: calendar)!
        let feb = MonthlyOverload.previousMonthInterval(before: thisMonth, calendar: calendar)!
        XCTAssertTrue(feb.contains(date(2026, 2, 28, hour: 23)))
        XCTAssertFalse(feb.contains(date(2026, 3, 1, hour: 0)))
        XCTAssertEqual(calendar.dateComponents([.day], from: feb.start, to: feb.end).day, 28)
    }

    // MARK: - Best working set
    //
    // Rule (documented for the recap, not in-workout progression):
    // 1. Ignore warm-ups.
    // 2. Highest weightLbs wins.
    // 3. If weights tie, higher reps wins.
    // 4. If weight and reps tie, the first occurrence is kept.

    func test_bestSet_heavierWeightWinsRegardlessOfReps() {
        let best = MonthlyOverload.bestWorkingSet(in: [
            set(225, 8),
            set(230, 3),
            set(220, 12),
        ])
        XCTAssertEqual(best, MonthlyOverload.WorkingSet(weightLbs: 230, reps: 3))
    }

    func test_bestSet_sameWeight_higherRepsWins() {
        let best = MonthlyOverload.bestWorkingSet(in: [
            set(225, 4),
            set(225, 6),
            set(225, 5),
        ])
        XCTAssertEqual(best, MonthlyOverload.WorkingSet(weightLbs: 225, reps: 6))
    }

    func test_bestSet_warmupExcludedEvenWhenHeavier() {
        let best = MonthlyOverload.bestWorkingSet(in: [
            set(315, 1, warmup: true),
            set(225, 5),
        ])
        XCTAssertEqual(best, MonthlyOverload.WorkingSet(weightLbs: 225, reps: 5))
    }

    func test_bestSet_warmupOnly_isNil() {
        XCTAssertNil(MonthlyOverload.bestWorkingSet(in: [set(135, 8, warmup: true)]))
    }

    func test_bestSet_fullTie_keepsFirstOccurrence() {
        let first = set(225, 5)
        let best = MonthlyOverload.bestWorkingSet(in: [first, set(225, 5)])
        XCTAssertEqual(best, MonthlyOverload.WorkingSet(weightLbs: 225, reps: 5))
    }

    func test_bestSet_empty_isNil() {
        XCTAssertNil(MonthlyOverload.bestWorkingSet(in: []))
    }

    // MARK: - Comparison / delta

    func test_compare_weightUp_isUp() {
        XCTAssertEqual(
            MonthlyOverload.compare(
                thisMonth: .init(weightLbs: 230, reps: 5),
                lastMonth: .init(weightLbs: 225, reps: 8)
            ),
            .up
        )
        XCTAssertEqual(
            MonthlyOverload.deltaLabel(
                thisMonth: .init(weightLbs: 230, reps: 5),
                lastMonth: .init(weightLbs: 225, reps: 8)
            ),
            "+5 lb"
        )
    }

    func test_compare_sameWeightMoreReps_isUp() {
        XCTAssertEqual(
            MonthlyOverload.compare(
                thisMonth: .init(weightLbs: 225, reps: 6),
                lastMonth: .init(weightLbs: 225, reps: 5)
            ),
            .up
        )
        XCTAssertEqual(
            MonthlyOverload.deltaLabel(
                thisMonth: .init(weightLbs: 225, reps: 6),
                lastMonth: .init(weightLbs: 225, reps: 5)
            ),
            "+1"
        )
    }

    func test_compare_identical_isFlat() {
        let set = MonthlyOverload.WorkingSet(weightLbs: 225, reps: 5)
        XCTAssertEqual(MonthlyOverload.compare(thisMonth: set, lastMonth: set), .flat)
        XCTAssertEqual(MonthlyOverload.deltaLabel(thisMonth: set, lastMonth: set), "=")
    }

    func test_compare_weightDown_isDown_notShoutedAsZero() {
        XCTAssertEqual(
            MonthlyOverload.compare(
                thisMonth: .init(weightLbs: 220, reps: 5),
                lastMonth: .init(weightLbs: 225, reps: 5)
            ),
            .down
        )
        XCTAssertEqual(
            MonthlyOverload.deltaLabel(
                thisMonth: .init(weightLbs: 220, reps: 5),
                lastMonth: .init(weightLbs: 225, reps: 5)
            ),
            "−5 lb"
        )
    }

    func test_compare_sameWeightFewerReps_isDown() {
        XCTAssertEqual(
            MonthlyOverload.compare(
                thisMonth: .init(weightLbs: 225, reps: 4),
                lastMonth: .init(weightLbs: 225, reps: 5)
            ),
            .down
        )
        XCTAssertEqual(
            MonthlyOverload.deltaLabel(
                thisMonth: .init(weightLbs: 225, reps: 4),
                lastMonth: .init(weightLbs: 225, reps: 5)
            ),
            "−1"
        )
    }

    func test_compare_thisMonthOnly_isNew_notZero() {
        XCTAssertEqual(
            MonthlyOverload.compare(thisMonth: .init(weightLbs: 135, reps: 8), lastMonth: nil),
            .new
        )
        XCTAssertEqual(
            MonthlyOverload.deltaLabel(thisMonth: .init(weightLbs: 135, reps: 8), lastMonth: nil),
            "New"
        )
    }

    func test_compare_lastMonthOnly_isMissing_notZero() {
        XCTAssertEqual(
            MonthlyOverload.compare(thisMonth: nil, lastMonth: .init(weightLbs: 225, reps: 5)),
            .missing
        )
        XCTAssertEqual(
            MonthlyOverload.deltaLabel(thisMonth: nil, lastMonth: .init(weightLbs: 225, reps: 5)),
            "—"
        )
    }

    func test_workingSet_formatsHalfPounds() {
        XCTAssertEqual(MonthlyOverload.WorkingSet(weightLbs: 47.5, reps: 8).formatted, "47.5×8")
        XCTAssertEqual(MonthlyOverload.WorkingSet(weightLbs: 225, reps: 5).formatted, "225×5")
    }

    // MARK: - Review assembly

    func test_review_picksBestAcrossMultipleSessionsInMonth() {
        let bench = UUID()
        let result = review([
            session(date(2026, 7, 8), lift(id: bench, name: "Bench", set(220, 5))),
            session(date(2026, 7, 22), lift(id: bench, name: "Bench", set(225, 4))),
            session(date(2026, 8, 4), lift(id: bench, name: "Bench", set(225, 5))),
            session(date(2026, 8, 11), lift(id: bench, name: "Bench", set(230, 3), set(225, 6))),
        ])
        let row = result.rows.first { $0.exerciseID == bench }
        XCTAssertEqual(row?.lastMonth, MonthlyOverload.WorkingSet(weightLbs: 225, reps: 4))
        XCTAssertEqual(row?.thisMonth, MonthlyOverload.WorkingSet(weightLbs: 230, reps: 3))
        XCTAssertEqual(row?.comparison, .up)
        XCTAssertEqual(row?.deltaLabel, "+5 lb")
    }

    func test_review_includesLiftsTrainedInEitherMonth() {
        let bench = UUID()
        let squat = UUID()
        let rowIDs = Set(review([
            session(date(2026, 7, 10), lift(id: bench, name: "Bench", set(225, 5))),
            session(date(2026, 8, 10), lift(id: squat, name: "Squat", day: "Legs", set(315, 5))),
        ]).rows.map(\.exerciseID))
        XCTAssertEqual(rowIDs, [bench, squat])
    }

    func test_review_newAndMissing_doNotInventZero() {
        let bench = UUID()
        let squat = UUID()
        let result = review([
            session(date(2026, 7, 10), lift(id: bench, name: "Bench", set(225, 5))),
            session(date(2026, 8, 10), lift(id: squat, name: "Squat", day: "Legs", set(315, 5))),
        ])
        let benchRow = result.rows.first { $0.exerciseID == bench }
        let squatRow = result.rows.first { $0.exerciseID == squat }
        XCTAssertNil(benchRow?.thisMonth)
        XCTAssertEqual(benchRow?.comparison, .missing)
        XCTAssertNil(squatRow?.lastMonth)
        XCTAssertEqual(squatRow?.comparison, .new)
    }

    func test_review_warmupOnlyLift_omittedFromRows() {
        let bench = UUID()
        let result = review([
            session(date(2026, 8, 10), lift(id: bench, name: "Bench", set(315, 1, warmup: true))),
        ])
        XCTAssertTrue(result.isEmpty)
        XCTAssertEqual(result.thisMonthWorkoutCount, 1)
    }

    func test_review_combinesModes_heavierStrengthBeatsEndurance() {
        let bench = UUID()
        let result = review([
            session(
                date(2026, 7, 10),
                lift(id: bench, name: "Bench", set(135, 15), set(225, 5))
            ),
            session(
                date(2026, 8, 10),
                lift(id: bench, name: "Bench", set(140, 12), set(230, 5))
            ),
        ])
        let row = result.rows.first { $0.exerciseID == bench }
        XCTAssertEqual(row?.lastMonth, MonthlyOverload.WorkingSet(weightLbs: 225, reps: 5))
        XCTAssertEqual(row?.thisMonth, MonthlyOverload.WorkingSet(weightLbs: 230, reps: 5))
    }

    func test_review_ignoresSessionsOutsideEitherMonth() {
        let bench = UUID()
        let result = review([
            session(date(2026, 6, 20), lift(id: bench, name: "Bench", set(250, 5))),
            session(date(2026, 8, 10), lift(id: bench, name: "Bench", set(225, 5))),
        ])
        let row = result.rows.first { $0.exerciseID == bench }
        XCTAssertNil(row?.lastMonth)
        XCTAssertEqual(row?.thisMonth?.weightLbs, 225)
        XCTAssertEqual(row?.comparison, .new)
        XCTAssertEqual(result.lastMonthWorkoutCount, 0)
        XCTAssertEqual(result.thisMonthWorkoutCount, 1)
    }

    func test_review_workoutCounts_countSessionsNotLifts() {
        let result = review([
            session(date(2026, 7, 4), lift(name: "Bench", set(225, 5)), lift(name: "OHP", set(135, 8))),
            session(date(2026, 7, 18), lift(name: "Squat", day: "Legs", set(315, 5))),
            session(date(2026, 8, 5), lift(name: "Bench", set(230, 5))),
        ])
        XCTAssertEqual(result.lastMonthWorkoutCount, 2)
        XCTAssertEqual(result.thisMonthWorkoutCount, 1)
    }

    func test_review_groupsByDayType_inRequestedOrder() {
        let bench = UUID()
        let row = UUID()
        let squat = UUID()
        let groups = review([
            session(date(2026, 8, 10),
                    lift(id: squat, name: "Squat", day: "Legs", sort: 0, set(315, 5)),
                    lift(id: row, name: "Row", day: "Pull", sort: 0, set(185, 8)),
                    lift(id: bench, name: "Bench", day: "Push", sort: 0, set(225, 5))),
        ], dayOrder: ["Push", "Pull", "Legs"]).groups.map(\.dayTypeName)
        XCTAssertEqual(groups, ["Push", "Pull", "Legs"])
    }

    func test_review_sortsLiftsWithinGroupBySortOrderThenName() {
        let names = review([
            session(date(2026, 8, 10),
                    lift(name: "OHP", sort: 1, set(135, 8)),
                    lift(name: "Bench", sort: 0, set(225, 5)),
                    lift(name: "Flye", sort: 1, set(30, 12))),
        ]).groups.first?.rows.map(\.exerciseName)
        XCTAssertEqual(names, ["Bench", "Flye", "OHP"])
    }

    func test_review_emptyWhenNoHistory() {
        let result = review([])
        XCTAssertTrue(result.isEmpty)
        XCTAssertEqual(result.thisMonthWorkoutCount, 0)
        XCTAssertEqual(result.lastMonthWorkoutCount, 0)
        XCTAssertEqual(result.thisMonthLabel, "Aug")
        XCTAssertEqual(result.lastMonthLabel, "Jul")
    }

    func test_deltaLabel_halfPoundWeightBump() {
        XCTAssertEqual(
            MonthlyOverload.deltaLabel(
                thisMonth: .init(weightLbs: 50, reps: 8),
                lastMonth: .init(weightLbs: 47.5, reps: 8)
            ),
            "+2.5 lb"
        )
    }

    func test_review_januaryUsesDecemberAsLastMonth() {
        let bench = UUID()
        let januaryNow = date(2026, 1, 20)
        let result = review([
            session(date(2025, 12, 12), lift(id: bench, name: "Bench", set(225, 5))),
            session(date(2026, 1, 8), lift(id: bench, name: "Bench", set(225, 6))),
        ], now: januaryNow)
        let row = result.rows.first { $0.exerciseID == bench }
        XCTAssertEqual(result.lastMonthLabel, "Dec")
        XCTAssertEqual(result.thisMonthLabel, "Jan")
        XCTAssertEqual(row?.lastMonth, MonthlyOverload.WorkingSet(weightLbs: 225, reps: 5))
        XCTAssertEqual(row?.thisMonth, MonthlyOverload.WorkingSet(weightLbs: 225, reps: 6))
        XCTAssertEqual(row?.comparison, .up)
    }

    func test_review_sessionOnMonthBoundary_assignedToCorrectMonth() {
        let julyLift = UUID()
        let augustLift = UUID()
        let result = review([
            session(date(2026, 7, 31, hour: 23), lift(id: julyLift, name: "July", set(100, 5))),
            session(date(2026, 8, 1, hour: 0), lift(id: augustLift, name: "August", set(100, 5))),
        ])
        XCTAssertEqual(result.rows.first { $0.exerciseID == julyLift }?.comparison, .missing)
        XCTAssertEqual(result.rows.first { $0.exerciseID == augustLift }?.comparison, .new)
    }
}
