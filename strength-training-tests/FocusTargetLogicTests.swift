//
//  FocusTargetLogicTests.swift
//  strength-training-tests
//

import XCTest
@testable import strength_training

final class FocusTargetLogicTests: XCTestCase {

    func test_consistent_weightBump_dressesWeightOnly() {
        let p = FocusTargetLogic.prefill(
            suggestion: ProgressionSuggestion(targetWeight: 230, targetReps: 5, basis: .consistent),
            recent: RecentAverage(weight: 225, reps: 5, sessionCount: 4)
        )
        XCTAssertEqual(p.weight, 230)
        XCTAssertEqual(p.reps, 5)
        XCTAssertEqual(p.weightDelta, "+5 lb")
        XCTAssertNil(p.repsDelta)
    }

    func test_improving_repBump_dressesRepsOnly() {
        let p = FocusTargetLogic.prefill(
            suggestion: ProgressionSuggestion(targetWeight: 40, targetReps: 11, basis: .improving),
            recent: RecentAverage(weight: 40, reps: 10, sessionCount: 3)
        )
        XCTAssertEqual(p.weight, 40)
        XCTAssertEqual(p.reps, 11)
        XCTAssertNil(p.weightDelta)
        XCTAssertEqual(p.repsDelta, "+1")
    }

    func test_notEnoughData_prefillsWithoutDress() {
        let p = FocusTargetLogic.prefill(
            suggestion: ProgressionSuggestion(targetWeight: 50, targetReps: 8, basis: .notEnoughData),
            recent: RecentAverage(weight: 50, reps: 8, sessionCount: 1)
        )
        XCTAssertEqual(p.weight, 50)
        XCTAssertEqual(p.reps, 8)
        XCTAssertNil(p.weightDelta)
        XCTAssertNil(p.repsDelta)
    }

    func test_noHistory_defaults() {
        let p = FocusTargetLogic.prefill(suggestion: nil, recent: nil)
        XCTAssertEqual(p.weight, 0)
        XCTAssertEqual(p.reps, 10)   // preserves the old SetInputView default
        XCTAssertNil(p.weightDelta)
        XCTAssertNil(p.repsDelta)
    }

    func test_consistent_zeroOrNegativeDelta_staysNeutral() {
        let p = FocusTargetLogic.prefill(
            suggestion: ProgressionSuggestion(targetWeight: 225, targetReps: 5, basis: .consistent),
            recent: RecentAverage(weight: 225, reps: 5, sessionCount: 4)
        )
        XCTAssertNil(p.weightDelta)
        XCTAssertNil(p.repsDelta)
    }

    func test_fractionalWeightDelta_formats() {
        let p = FocusTargetLogic.prefill(
            suggestion: ProgressionSuggestion(targetWeight: 50, targetReps: 12, basis: .consistent),
            recent: RecentAverage(weight: 47.5, reps: 12, sessionCount: 2)
        )
        XCTAssertEqual(p.weightDelta, "+2.5 lb")
    }
}
