//
//  EffortRatingLayoutTests.swift
//  RockLogTests
//

import XCTest
@testable import RockLog

final class EffortRatingLayoutTests: XCTestCase {
    func test_barWidth_zeroWidth_isNonNegative() {
        XCTAssertEqual(EffortRatingView.barWidth(available: 0, spacing: 60, count: 10), 0)
    }

    func test_barWidth_nonFiniteInputs_returnZero() {
        XCTAssertEqual(EffortRatingView.barWidth(available: .infinity, spacing: 10, count: 10), 0)
        XCTAssertEqual(EffortRatingView.barWidth(available: .nan, spacing: 10, count: 10), 0)
        XCTAssertEqual(EffortRatingView.barWidth(available: 300, spacing: 10, count: 0), 0)
    }

    func test_barWidth_normalWidth_matchesFormula() {
        XCTAssertEqual(EffortRatingView.barWidth(available: 340, spacing: 40, count: 10), 30, accuracy: 0.0001)
    }
}
