//
//  StrengthScoreTests.swift
//  strength-training-tests
//

import XCTest
@testable import strength_training

final class StrengthScoreTests: XCTestCase {

    func test_twoChestLifts_countOnce_atTheStrongerE1RM() {
        var best: [String: Double] = [:]
        StrengthScore.absorb(e1rm: 225, muscle: "Chest", into: &best)
        StrengthScore.absorb(e1rm: 80, muscle: "Chest", into: &best)
        XCTAssertEqual(StrengthScore.total(best), 225)
    }

    func test_chestAndBack_bothCount() {
        var best: [String: Double] = [:]
        StrengthScore.absorb(e1rm: 225, muscle: "Chest", into: &best)
        StrengthScore.absorb(e1rm: 315, muscle: "Back", into: &best)
        XCTAssertEqual(StrengthScore.total(best), 540)
    }

    func test_weakerVariant_doesNotRaiseScore() {
        var best: [String: Double] = [:]
        StrengthScore.absorb(e1rm: 225, muscle: "Chest", into: &best)
        StrengthScore.absorb(e1rm: 80, muscle: "Chest", into: &best)
        StrengthScore.absorb(e1rm: 200, muscle: "Chest", into: &best)
        XCTAssertEqual(StrengthScore.total(best), 225)
    }

    func test_strongerSetOnSameMuscle_raisesScore() {
        var best: [String: Double] = [:]
        StrengthScore.absorb(e1rm: 225, muscle: "Chest", into: &best)
        StrengthScore.absorb(e1rm: 245, muscle: "Chest", into: &best)
        XCTAssertEqual(StrengthScore.total(best), 245)
    }

    func test_emptyMuscle_sharesOneOtherSlot() {
        var best: [String: Double] = [:]
        StrengthScore.absorb(e1rm: 100, muscle: "", into: &best)
        StrengthScore.absorb(e1rm: 40, muscle: "  ", into: &best)
        XCTAssertEqual(StrengthScore.slot(for: ""), StrengthScore.ungroupedSlot)
        XCTAssertEqual(StrengthScore.total(best), 100)
    }

    func test_zeroE1RM_ignored() {
        var best: [String: Double] = [:]
        StrengthScore.absorb(e1rm: 0, muscle: "Chest", into: &best)
        XCTAssertEqual(StrengthScore.total(best), 0)
    }

    func test_sideTag_doublesLoad_untaggedDoesNot() {
        let barCurl = StrengthScore.comparableE1RM(weightLbs: 100, reps: 8, isEachSide: false)
        let dbCurl = StrengthScore.comparableE1RM(weightLbs: 50, reps: 8, isEachSide: true)
        XCTAssertEqual(barCurl, dbCurl, accuracy: 0.001)
        XCTAssertEqual(barCurl, E1RM.estimate(weightLbs: 100, reps: 8), accuracy: 0.001)
    }

    func test_sideTag_coversUnilateralFamily() {
        let pulldown = StrengthScore.comparableE1RM(weightLbs: 80, reps: 10, isEachSide: true)
        let calf = StrengthScore.comparableE1RM(weightLbs: 80, reps: 10, isEachSide: true)
        let twoLimb = StrengthScore.comparableE1RM(weightLbs: 160, reps: 10, isEachSide: false)
        XCTAssertEqual(pulldown, twoLimb, accuracy: 0.001)
        XCTAssertEqual(calf, twoLimb, accuracy: 0.001)
    }

    func test_untaggedDumbbell_doesNotGuessFromName() {
        let raw = StrengthScore.comparableE1RM(weightLbs: 100, reps: 5, isEachSide: false)
        XCTAssertEqual(raw, E1RM.estimate(weightLbs: 100, reps: 5), accuracy: 0.001)
    }
}
