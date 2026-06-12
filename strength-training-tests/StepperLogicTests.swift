//
//  StepperLogicTests.swift
//  strength-training-tests
//

import XCTest
@testable import strength_training

final class StepperLogicTests: XCTestCase {

    // MARK: - increment / decrement

    func test_increment_addsStep() {
        XCTAssertEqual(StepperLogic.increment(225, step: 5, max: 1000), 230)
    }

    func test_increment_clampsAtMax() {
        XCTAssertEqual(StepperLogic.increment(998, step: 5, max: 1000), 1000)
    }

    func test_decrement_subtractsStep() {
        XCTAssertEqual(StepperLogic.decrement(225, step: 5, min: 0), 220)
    }

    func test_decrement_clampsAtMin() {
        XCTAssertEqual(StepperLogic.decrement(3, step: 5, min: 1), 1)
    }

    func test_fractionalStep_fromFractionalValue() {
        XCTAssertEqual(StepperLogic.increment(47.5, step: 2.5, max: 1000), 50)
    }

    func test_halfPoundStep() {
        XCTAssertEqual(StepperLogic.increment(47.5, step: 0.5, max: 1000), 48.0)
    }

    func test_increment_atMax_staysAtMax() {
        XCTAssertEqual(StepperLogic.increment(1000, step: 5, max: 1000), 1000)
    }

    func test_decrement_atMin_staysAtMin() {
        XCTAssertEqual(StepperLogic.decrement(0, step: 5, min: 0), 0)
    }

    // MARK: - format

    func test_format_dropsDecimalForWholeNumbers() {
        XCTAssertEqual(StepperLogic.format(235.0), "235")
    }

    func test_format_keepsOneDecimalForFractions() {
        XCTAssertEqual(StepperLogic.format(47.5), "47.5")
    }

    func test_format_ofFractionalIncrementLandingOnWholeNumber() {
        XCTAssertEqual(StepperLogic.format(StepperLogic.increment(47.5, step: 2.5, max: 1000)), "50")
    }
}
