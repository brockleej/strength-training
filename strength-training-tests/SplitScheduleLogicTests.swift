//
//  SplitScheduleLogicTests.swift
//  strength-training-tests
//

import XCTest
@testable import strength_training

final class SplitScheduleLogicTests: XCTestCase {

    private let push = DayType("Push")
    private let pull = DayType("Pull")
    private let legs = DayType("Legs")
    private var ordered: [DayType] { [push, pull, legs] }

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    /// Fixed Monday 2026-07-13 12:00 UTC
    private var monday: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 13, hour: 12))!
    }

    private func stamp(_ day: DayType, daysFromMonday: Int) -> SplitScheduleLogic.SessionStamp {
        let date = calendar.date(byAdding: .day, value: daysFromMonday, to: monday)!
        return .init(dayName: day.rawValue, date: date)
    }

    // MARK: - Rolling

    func test_rolling_noHistory_picksFirst() {
        let day = SplitScheduleLogic.suggestedDay(
            orderedDays: ordered,
            sessions: [],
            mode: .rolling,
            carryoverDayNames: [],
            now: monday,
            calendar: calendar
        )
        XCTAssertEqual(day, push)
    }

    func test_rolling_afterPush_suggestsPull() {
        let day = SplitScheduleLogic.suggestedDay(
            orderedDays: ordered,
            sessions: [stamp(push, daysFromMonday: 0)],
            mode: .rolling,
            carryoverDayNames: [],
            now: monday,
            calendar: calendar
        )
        XCTAssertEqual(day, pull)
    }

    func test_rolling_afterLegs_wrapsToPush() {
        let day = SplitScheduleLogic.suggestedDay(
            orderedDays: ordered,
            sessions: [stamp(legs, daysFromMonday: 2)],
            mode: .rolling,
            carryoverDayNames: [],
            now: monday,
            calendar: calendar
        )
        XCTAssertEqual(day, push)
    }

    func test_rolling_usesMostRecentNotOldest() {
        let day = SplitScheduleLogic.suggestedDay(
            orderedDays: ordered,
            sessions: [
                stamp(push, daysFromMonday: 0),
                stamp(pull, daysFromMonday: 1),
            ],
            mode: .rolling,
            carryoverDayNames: [],
            now: monday,
            calendar: calendar
        )
        XCTAssertEqual(day, legs)
    }

    // MARK: - Weekly

    func test_weekly_skipsDaysDoneThisWeek() {
        // Wednesday of same week; Push Mon + Pull Tue done → Legs
        let wednesday = calendar.date(byAdding: .day, value: 2, to: monday)!
        let day = SplitScheduleLogic.suggestedDay(
            orderedDays: ordered,
            sessions: [
                stamp(push, daysFromMonday: 0),
                stamp(pull, daysFromMonday: 1),
            ],
            mode: .weekly,
            carryoverDayNames: [],
            now: wednesday,
            calendar: calendar
        )
        XCTAssertEqual(day, legs)
    }

    func test_weekly_allDone_staysOnLast() {
        let friday = calendar.date(byAdding: .day, value: 4, to: monday)!
        let day = SplitScheduleLogic.suggestedDay(
            orderedDays: ordered,
            sessions: [
                stamp(push, daysFromMonday: 0),
                stamp(pull, daysFromMonday: 1),
                stamp(legs, daysFromMonday: 2),
            ],
            mode: .weekly,
            carryoverDayNames: [],
            now: friday,
            calendar: calendar
        )
        XCTAssertEqual(day, legs)
    }

    func test_weekly_carryover_prefersRemaining() {
        let nextMonday = calendar.date(byAdding: .day, value: 7, to: monday)!
        let day = SplitScheduleLogic.suggestedDay(
            orderedDays: ordered,
            sessions: [],
            mode: .weekly,
            carryoverDayNames: ["Legs"],
            now: nextMonday,
            calendar: calendar
        )
        XCTAssertEqual(day, legs)
    }

    // MARK: - Incomplete week prompt

    func test_incompleteWeekPrompt_whenPreviousPartialAndThisEmpty() {
        let nextMonday = calendar.date(byAdding: .day, value: 7, to: monday)!
        let prompt = SplitScheduleLogic.incompleteWeekPrompt(
            orderedDays: ordered,
            sessions: [
                stamp(push, daysFromMonday: 0),
                stamp(pull, daysFromMonday: 1),
            ],
            now: nextMonday,
            calendar: calendar
        )
        XCTAssertEqual(prompt?.previousCompleted, ["Push", "Pull"])
        XCTAssertEqual(prompt?.remaining, ["Legs"])
    }

    func test_incompleteWeekPrompt_nilWhenPreviousComplete() {
        let nextMonday = calendar.date(byAdding: .day, value: 7, to: monday)!
        let prompt = SplitScheduleLogic.incompleteWeekPrompt(
            orderedDays: ordered,
            sessions: [
                stamp(push, daysFromMonday: 0),
                stamp(pull, daysFromMonday: 1),
                stamp(legs, daysFromMonday: 2),
            ],
            now: nextMonday,
            calendar: calendar
        )
        XCTAssertNil(prompt)
    }

    func test_incompleteWeekPrompt_nilWhenAlreadyStartedThisWeek() {
        let nextMonday = calendar.date(byAdding: .day, value: 7, to: monday)!
        let prompt = SplitScheduleLogic.incompleteWeekPrompt(
            orderedDays: ordered,
            sessions: [
                stamp(push, daysFromMonday: 0),
                // Started new week
                SplitScheduleLogic.SessionStamp(dayName: "Push", date: nextMonday),
            ],
            now: nextMonday,
            calendar: calendar
        )
        XCTAssertNil(prompt)
    }

    func test_prunedCarryover_removesCompleted() {
        let after = monday
        let pruned = SplitScheduleLogic.prunedCarryover(
            carryoverDayNames: ["Pull", "Legs"],
            sessions: [stamp(pull, daysFromMonday: 8)],
            after: after
        )
        XCTAssertEqual(pruned, ["Legs"])
    }
}
