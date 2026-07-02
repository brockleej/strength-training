//
//  WorkoutFormatTests.swift
//  strength-training-tests
//

import XCTest
@testable import strength_training

final class WorkoutFormatTests: XCTestCase {

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

    func test_elapsed_negative_clampsToZero() {
        XCTAssertEqual(WorkoutFormat.elapsed(-5), "0:00")
    }
}
