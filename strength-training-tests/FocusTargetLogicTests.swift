//
//  FocusTargetLogicTests.swift
//  strength-training-tests
//

import XCTest
@testable import strength_training

final class FocusTargetLogicTests: XCTestCase {

    private func suggestion(_ w: Double, _ r: Int, _ b: ProgressionSuggestion.Basis) -> ProgressionSuggestion {
        ProgressionSuggestion(targetWeight: w, targetReps: r, basis: b)
    }

    func test_consistent_targetAboveLastSession_dressesWeight() {
        let p = FocusTargetLogic.prefill(
            suggestion: suggestion(230, 5, .consistent),
            recent: RecentAverage(weight: 225, reps: 5, sessionCount: 4),
            lastBest: (weight: 225, reps: 5)
        )
        XCTAssertEqual(p.weight, 230)
        XCTAssertEqual(p.weightDelta, "+5 lb")   // vs LAST SESSION, not the average
        XCTAssertNil(p.repsDelta)
    }

    /// The reported bug: sessions 10/10/15 → avg 11.67 → snap5(16.67) = 15 = last
    /// session's weight. No real increase → NO dress (previously "+3.3 lb").
    func test_consistent_targetEqualsLastSession_staysNeutral() {
        let p = FocusTargetLogic.prefill(
            suggestion: suggestion(15, 15, .consistent),
            recent: RecentAverage(weight: 11.67, reps: 15, sessionCount: 3),
            lastBest: (weight: 15, reps: 15)
        )
        XCTAssertEqual(p.weight, 15)
        XCTAssertNil(p.weightDelta)
        XCTAssertNil(p.repsDelta)
    }

    func test_consistent_deltaComputedFromLastSession_notAverage() {
        // avg 11.67 but last session was 10 → target 15 shows +5, not +3.3
        let p = FocusTargetLogic.prefill(
            suggestion: suggestion(15, 12, .consistent),
            recent: RecentAverage(weight: 11.67, reps: 12, sessionCount: 3),
            lastBest: (weight: 10, reps: 12)
        )
        XCTAssertEqual(p.weightDelta, "+5 lb")
    }

    func test_improving_repBumpAboveLastSession_dressesReps() {
        let p = FocusTargetLogic.prefill(
            suggestion: suggestion(40, 11, .improving),
            recent: RecentAverage(weight: 40, reps: 10, sessionCount: 3),
            lastBest: (weight: 40, reps: 10)
        )
        XCTAssertEqual(p.reps, 11)
        XCTAssertEqual(p.repsDelta, "+1")
        XCTAssertNil(p.weightDelta)
    }

    func test_improving_targetRepsNotAboveLastSession_staysNeutral() {
        // avg reps 10 → target 11, but last session already hit 12
        let p = FocusTargetLogic.prefill(
            suggestion: suggestion(40, 11, .improving),
            recent: RecentAverage(weight: 40, reps: 10, sessionCount: 3),
            lastBest: (weight: 40, reps: 12)
        )
        XCTAssertNil(p.repsDelta)
        XCTAssertNil(p.weightDelta)
    }

    func test_notEnoughData_prefillsWithoutDress() {
        let p = FocusTargetLogic.prefill(
            suggestion: suggestion(50, 8, .notEnoughData),
            recent: RecentAverage(weight: 50, reps: 8, sessionCount: 1),
            lastBest: (weight: 50, reps: 8)
        )
        XCTAssertEqual(p.weight, 50)
        XCTAssertNil(p.weightDelta)
        XCTAssertNil(p.repsDelta)
    }

    func test_noHistory_defaults() {
        let p = FocusTargetLogic.prefill(suggestion: nil, recent: nil, lastBest: nil)
        XCTAssertEqual(p.weight, 0)
        XCTAssertEqual(p.reps, 10)
        XCTAssertNil(p.weightDelta)
        XCTAssertNil(p.repsDelta)
    }

    func test_sessionLast_overridesSuggestion_forSupersets() {
        let p = FocusTargetLogic.prefill(
            suggestion: suggestion(230, 5, .consistent),
            recent: RecentAverage(weight: 225, reps: 5, sessionCount: 4),
            lastBest: (weight: 225, reps: 5),
            sessionLast: FocusTargetLogic.SessionLastSet(
                weight: 40,
                reps: 12,
                isWarmup: false,
                isEachSide: true,
                isAssisted: false
            )
        )
        XCTAssertEqual(p.weight, 40)
        XCTAssertEqual(p.reps, 12)
        XCTAssertTrue(p.isEachSide)
        XCTAssertNil(p.weightDelta)
        XCTAssertNil(p.repsDelta)
    }

    func test_suggestionWithoutLastBest_staysNeutral() {
        let p = FocusTargetLogic.prefill(
            suggestion: suggestion(230, 5, .consistent),
            recent: nil,
            lastBest: nil
        )
        XCTAssertEqual(p.weight, 230)
        XCTAssertNil(p.weightDelta)
    }

    func test_fractionalWeightDelta_formats() {
        let p = FocusTargetLogic.prefill(
            suggestion: suggestion(50, 12, .consistent),
            recent: RecentAverage(weight: 47.5, reps: 12, sessionCount: 2),
            lastBest: (weight: 47.5, reps: 12)
        )
        XCTAssertEqual(p.weightDelta, "+2.5 lb")
    }

    // MARK: - lastBest (dress baseline, mirrors algorithm bestSet convention)

    func test_lastBest_picksHeaviestSet() {
        let best = FocusTargetLogic.lastBest(from: [
            (weight: 135, reps: 10, isWarmup: false),
            (weight: 185, reps: 6, isWarmup: false),
            (weight: 155, reps: 8, isWarmup: false),
        ])
        XCTAssertEqual(best?.weight, 185)
        XCTAssertEqual(best?.reps, 6)
    }

    func test_lastBest_tieBrokenByFirstOccurrence() {
        // Same convention as ProgressionService.bestSet: max(by: <) keeps the
        // FIRST occurrence of the max weight on ties.
        let best = FocusTargetLogic.lastBest(from: [
            (weight: 225, reps: 5, isWarmup: false),
            (weight: 225, reps: 3, isWarmup: false),
        ])
        XCTAssertEqual(best?.reps, 5)
    }

    func test_lastBest_emptySets_returnsNil() {
        let empty: [(weight: Double, reps: Int, isWarmup: Bool)] = []
        XCTAssertNil(FocusTargetLogic.lastBest(from: empty))
    }

    func test_lastBest_excludesWarmups() {
        let sets: [(weight: Double, reps: Int, isWarmup: Bool)] = [
            (weight: 225, reps: 1, isWarmup: true),
            (weight: 185, reps: 5, isWarmup: false),
            (weight: 135, reps: 8, isWarmup: false),
        ]
        let best = FocusTargetLogic.lastBest(from: sets)
        XCTAssertEqual(best?.weight, 185)
        XCTAssertEqual(best?.reps, 5)
    }
}
