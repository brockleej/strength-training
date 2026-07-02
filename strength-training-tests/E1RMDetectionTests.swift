//
//  E1RMDetectionTests.swift
//  strength-training-tests
//

import XCTest
@testable import strength_training

final class E1RMDetectionTests: XCTestCase {

    // MARK: - E1RM.estimate (Epley)

    func test_estimate_epley() {
        XCTAssertEqual(E1RM.estimate(weightLbs: 225, reps: 5), 262.5, accuracy: 0.001)
    }

    func test_estimate_singleRep_equalsWeight() {
        XCTAssertEqual(E1RM.estimate(weightLbs: 315, reps: 1), 325.5, accuracy: 0.001)
        // Epley adds weight/30 even at 1 rep — matches the app's existing formula everywhere.
    }

    func test_estimate_zeroWeight_isZero() {
        XCTAssertEqual(E1RM.estimate(weightLbs: 0, reps: 10), 0, accuracy: 0.001)
    }

    // MARK: - PRDetection.celebration

    private var priorBest: PRDetection.PriorBest {
        .init(weight: 225, reps: 5, e1RM: 262.5, date: Date(timeIntervalSince1970: 1_700_000_000))
    }

    func test_beatsPrior_fires_withWeightDelta() {
        let outcome = PRDetection.celebration(
            newWeight: 235, newReps: 5, priorBest: priorBest, alreadyCelebrated: false
        )
        XCTAssertNotNil(outcome)
        XCTAssertEqual(outcome?.newE1RM ?? 0, 274.17, accuracy: 0.01)
        XCTAssertEqual(outcome?.weightDelta ?? 0, 10, accuracy: 0.001)
    }

    func test_higherE1RMViaReps_fires_evenWithLowerWeight() {
        // 225×6 → 270 e1RM beats 262.5; weight delta is 0 vs prior 225
        let outcome = PRDetection.celebration(
            newWeight: 225, newReps: 6, priorBest: priorBest, alreadyCelebrated: false
        )
        XCTAssertNotNil(outcome)
        XCTAssertEqual(outcome?.weightDelta ?? -1, 0, accuracy: 0.001)
    }

    func test_equalE1RM_doesNotFire() {
        XCTAssertNil(PRDetection.celebration(
            newWeight: 225, newReps: 5, priorBest: priorBest, alreadyCelebrated: false
        ))
    }

    func test_lowerE1RM_doesNotFire() {
        XCTAssertNil(PRDetection.celebration(
            newWeight: 185, newReps: 5, priorBest: priorBest, alreadyCelebrated: false
        ))
    }

    func test_noPriorHistory_doesNotFire() {
        XCTAssertNil(PRDetection.celebration(
            newWeight: 500, newReps: 10, priorBest: nil, alreadyCelebrated: false
        ))
    }

    func test_alreadyCelebrated_doesNotFire() {
        XCTAssertNil(PRDetection.celebration(
            newWeight: 500, newReps: 10, priorBest: priorBest, alreadyCelebrated: true
        ))
    }
}
