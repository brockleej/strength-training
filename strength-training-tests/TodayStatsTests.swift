//
//  TodayStatsTests.swift
//  strength-training-tests
//

import XCTest
@testable import strength_training

final class TodayStatsTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Denver")!
        return cal
    }

    /// Wednesday 2026-06-10 12:00 local
    private var wednesdayNoon: Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 12))!
    }

    private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 18) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    // MARK: - relativeDayLabel

    func test_label_sameDay_isToday() {
        XCTAssertEqual(TodayStats.relativeDayLabel(for: day(2026, 6, 10, hour: 8), now: wednesdayNoon, calendar: calendar), "Today")
    }

    func test_label_oneDayAgo_isYesterday() {
        XCTAssertEqual(TodayStats.relativeDayLabel(for: day(2026, 6, 9), now: wednesdayNoon, calendar: calendar), "Yesterday")
    }

    func test_label_threeDaysAgo_isWeekdayName() {
        // 2026-06-07 is a Sunday
        XCTAssertEqual(TodayStats.relativeDayLabel(for: day(2026, 6, 7), now: wednesdayNoon, calendar: calendar), "Sunday")
    }

    func test_label_sevenDaysAgo_isNDaysAgo() {
        XCTAssertEqual(TodayStats.relativeDayLabel(for: day(2026, 6, 3), now: wednesdayNoon, calendar: calendar), "7 days ago")
    }

    // MARK: - weekCells (Monday-start week)

    func test_weekCells_marksTrainedDaysAndToday() {
        // Week of Mon 2026-06-08 … Sun 2026-06-14; now = Wed 6/10
        let sessions: [(date: Date, dayType: DayType)] = [
            (day(2026, 6, 8), .arms),    // Monday
            (day(2026, 6, 10, hour: 7), .legs),  // Wednesday (today)
        ]
        let cells = TodayStats.weekCells(sessions: sessions, now: wednesdayNoon, calendar: calendar)

        XCTAssertEqual(cells.count, 7)
        XCTAssertEqual(cells.map(\.letter), ["M", "T", "W", "T", "F", "S", "S"])
        XCTAssertEqual(cells[0].trained, .arms)        // Monday trained
        XCTAssertFalse(cells[0].isToday)
        XCTAssertNil(cells[1].trained)                 // Tuesday rest
        XCTAssertEqual(cells[2].trained, .legs)        // Wednesday trained
        XCTAssertTrue(cells[2].isToday)
        XCTAssertNil(cells[6].trained)                 // Sunday rest
    }

    func test_weekCells_ignoresSessionsOutsideCurrentWeek() {
        let sessions: [(date: Date, dayType: DayType)] = [
            (day(2026, 6, 7), .arms),    // Sunday of PREVIOUS week
        ]
        let cells = TodayStats.weekCells(sessions: sessions, now: wednesdayNoon, calendar: calendar)
        XCTAssertTrue(cells.allSatisfy { $0.trained == nil })
    }

    // MARK: - formatVolume

    func test_formatVolume_thousandsSeparator() {
        XCTAssertEqual(TodayStats.formatVolume(12840), "12,840")
    }

    func test_formatVolume_zero() {
        XCTAssertEqual(TodayStats.formatVolume(0), "0")
    }

    func test_formatVolume_roundsFraction() {
        XCTAssertEqual(TodayStats.formatVolume(12840.7), "12,841")
    }

    func test_weekCells_sundayIsLastDayOfWeek() {
        // Sun 2026-06-14 — last slot of a Monday-start week, not the first of the next
        let sunday = day(2026, 6, 14)
        let cells = TodayStats.weekCells(sessions: [], now: sunday, calendar: calendar)
        XCTAssertEqual(cells.count, 7)
        XCTAssertTrue(cells[6].isToday)
        XCTAssertTrue(cells[0..<6].allSatisfy { !$0.isToday })
    }

    // MARK: - formatCompactVolume

    func test_compactVolume_underTenThousand_isExact() {
        XCTAssertEqual(TodayStats.formatCompactVolume(9840), "9,840")
    }

    func test_compactVolume_tenThousandAndUp_usesK() {
        XCTAssertEqual(TodayStats.formatCompactVolume(12840), "13k")
        XCTAssertEqual(TodayStats.formatCompactVolume(187_400), "187k")
    }

    func test_compactVolume_zero() {
        XCTAssertEqual(TodayStats.formatCompactVolume(0), "0")
    }

    func test_compactVolume_roundsK() {
        XCTAssertEqual(TodayStats.formatCompactVolume(186_501), "187k")
    }
}
