//
//  PrevSessionsStripDataTests.swift
//  strength-training-tests
//

import XCTest
@testable import strength_training

final class PrevSessionsStripDataTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Denver")!
        return cal
    }

    private var now: Date {   // Wed 2026-07-01 12:00
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 12))!
    }

    private func daysAgo(_ n: Int) -> Date {
        calendar.date(byAdding: .day, value: -n, to: now)!
    }

    // MARK: - runLines (consecutive same-weight grouping)

    func test_runLines_uniformWeight_singleLine() {
        let lines = PrevSessionsStripData.runLines(for: [
            .init(weight: 225, reps: 5), .init(weight: 225, reps: 5), .init(weight: 225, reps: 4),
        ])
        XCTAssertEqual(lines, ["225 × 5 · 5 · 4"])
    }

    func test_runLines_weightChange_breaksLine() {
        let lines = PrevSessionsStripData.runLines(for: [
            .init(weight: 225, reps: 5), .init(weight: 225, reps: 5), .init(weight: 230, reps: 3),
        ])
        XCTAssertEqual(lines, ["225 × 5 · 5", "230 × 3"])
    }

    func test_runLines_nonAdjacentSameWeight_staysSeparate() {
        let lines = PrevSessionsStripData.runLines(for: [
            .init(weight: 225, reps: 5), .init(weight: 230, reps: 3), .init(weight: 225, reps: 8),
        ])
        XCTAssertEqual(lines, ["225 × 5", "230 × 3", "225 × 8"])
    }

    func test_runLines_halfPoundWeights() {
        let lines = PrevSessionsStripData.runLines(for: [.init(weight: 47.5, reps: 12)])
        XCTAssertEqual(lines, ["47.5 × 12"])
    }

    // MARK: - relativeLabel

    func test_relativeLabel_daysAndWeeksAndMonths() {
        XCTAssertEqual(PrevSessionsStripData.relativeLabel(for: daysAgo(0), now: now, calendar: calendar), "Today")
        XCTAssertEqual(PrevSessionsStripData.relativeLabel(for: daysAgo(1), now: now, calendar: calendar), "Yesterday")
        XCTAssertEqual(PrevSessionsStripData.relativeLabel(for: daysAgo(5), now: now, calendar: calendar), "5 days ago")
        XCTAssertEqual(PrevSessionsStripData.relativeLabel(for: daysAgo(7), now: now, calendar: calendar), "1 wk ago")
        XCTAssertEqual(PrevSessionsStripData.relativeLabel(for: daysAgo(21), now: now, calendar: calendar), "3 wk ago")
        XCTAssertEqual(PrevSessionsStripData.relativeLabel(for: daysAgo(70), now: now, calendar: calendar), "2 mo ago")
    }

    // MARK: - entries (ordering, cap, empty-set filtering)

    func test_entries_chronological_capTen_skipsEmptySessions() {
        // 12 sessions, oldest first 12→1 days ago; session at 6 days ago has no sets
        var sessions: [PrevSessionsStripData.SessionSets] = (1...12).reversed().map { n in
            .init(id: UUID(), date: daysAgo(n),
                  sets: n == 6 ? [] : [.init(weight: Double(200 + n), reps: 5)])
        }
        let entries = PrevSessionsStripData.entries(from: sessions, now: now, calendar: calendar)
        // 11 non-empty sessions, capped to the 10 MOST RECENT, oldest-first order preserved
        XCTAssertEqual(entries.count, 10)
        XCTAssertEqual(entries.first?.lines, ["211 × 5"])   // 11 days ago survives the cap
        XCTAssertEqual(entries.last?.lines, ["201 × 5"])    // most recent is LAST (right-most)
        XCTAssertEqual(entries.last?.dateLabel, "Yesterday")
        _ = sessions.removeLast()
    }
}
