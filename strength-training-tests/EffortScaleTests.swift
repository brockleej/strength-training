//
//  EffortScaleTests.swift
//  strength-training-tests
//

import XCTest
@testable import strength_training

final class EffortScaleTests: XCTestCase {

    func test_bands() {
        XCTAssertEqual(EffortScale.label(for: 1), "Easy")
        XCTAssertEqual(EffortScale.label(for: 3), "Easy")
        XCTAssertEqual(EffortScale.label(for: 4), "Moderate")
        XCTAssertEqual(EffortScale.label(for: 6), "Moderate")
        XCTAssertEqual(EffortScale.label(for: 7), "Hard")
        XCTAssertEqual(EffortScale.label(for: 8), "Hard")
        XCTAssertEqual(EffortScale.label(for: 9), "All Out")
        XCTAssertEqual(EffortScale.label(for: 10), "All Out")
    }

    func test_outOfRange_isEmpty() {
        XCTAssertEqual(EffortScale.label(for: 0), "")
        XCTAssertEqual(EffortScale.label(for: 11), "")
    }
}
