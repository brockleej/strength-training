//
//  WorkoutFormatTests.swift
//  strength-training-tests
//

import XCTest
@testable import strength_training

final class WorkoutFormatTests: XCTestCase {

    // MARK: - row subtitle

    func test_subtitle_full() {
        XCTAssertEqual(WorkoutFormat.rowSubtitle(lastSets: 3, reps: 12, weight: 40), "3 × 12 · 40 lb")
    }

    func test_subtitle_noWeight() {
        XCTAssertEqual(WorkoutFormat.rowSubtitle(lastSets: 3, reps: 12, weight: nil), "3 × 12")
    }

    func test_subtitle_weightOnly() {
        XCTAssertEqual(WorkoutFormat.rowSubtitle(lastSets: nil, reps: nil, weight: 225), "225 lb")
    }

    func test_subtitle_none() {
        XCTAssertEqual(WorkoutFormat.rowSubtitle(lastSets: nil, reps: nil, weight: nil), "—")
    }

    // MARK: - elapsed

    func test_elapsed_minutesSeconds() {
        XCTAssertEqual(WorkoutFormat.elapsed(1122), "18:42")
    }

    func test_elapsed_zeroPadsSeconds() {
        XCTAssertEqual(WorkoutFormat.elapsed(65), "1:05")
    }

    func test_elapsed_hours() {
        XCTAssertEqual(WorkoutFormat.elapsed(3725), "1:02:05")
    }

    func test_elapsed_zero() {
        XCTAssertEqual(WorkoutFormat.elapsed(0), "0:00")
    }
}
