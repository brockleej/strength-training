//
//  ProgressionServicePureFunctionTests.swift
//  strength-training-tests
//

import XCTest
@testable import strength_training

final class ProgressionServicePureFunctionTests: XCTestCase {

    // MARK: - notEnoughData basis

    func test_singleSession_returnsNotEnoughData() {
        let records = AlgorithmFixtures.steadyHistory(count: 1, weight: 50, reps: 8)
        let suggestion = ProgressionService.suggestion(
            records: records,
            mode: .highWeightLowReps,
            params: .productionModerate
        )
        XCTAssertEqual(suggestion?.basis, .notEnoughData)
        XCTAssertEqual(suggestion?.targetWeight, 50)
        XCTAssertEqual(suggestion?.targetReps, 8)
    }

    func test_zeroSessions_returnsNil() {
        let suggestion = ProgressionService.suggestion(
            records: [],
            mode: .highWeightLowReps,
            params: .productionModerate
        )
        XCTAssertNil(suggestion)
    }

    // MARK: - improving basis (Strength mode)

    func test_strength_improvingReps_suggestsRepBump() {
        // Reps newest-first: [8, 6, 8, 8]. Sum = 30. Avg = 30/4 = 7.5 → rounds to 8.
        // Recent 2 (moderate threshold): {8, 6}. allSatisfy {>= 8} → 6 < 8 → false.
        // → .improving with target reps = 8 + 1 = 9. Target weight = snap5(50) = 50.
        let mixed: [ExerciseRecordSnapshot] = [
            AlgorithmFixtures.record(date: .now,                              sets: [SetSnapshot(weightLbs: 50, reps: 8, isWarmup: false, completedAt: .now)]),
            AlgorithmFixtures.record(date: .now.addingTimeInterval(-86400),   sets: [SetSnapshot(weightLbs: 50, reps: 6, isWarmup: false, completedAt: .now)]),
            AlgorithmFixtures.record(date: .now.addingTimeInterval(-86400*2), sets: [SetSnapshot(weightLbs: 50, reps: 8, isWarmup: false, completedAt: .now)]),
            AlgorithmFixtures.record(date: .now.addingTimeInterval(-86400*3), sets: [SetSnapshot(weightLbs: 50, reps: 8, isWarmup: false, completedAt: .now)]),
        ]
        let suggestion = ProgressionService.suggestion(
            records: mixed,
            mode: .highWeightLowReps,
            params: .productionModerate
        )
        XCTAssertEqual(suggestion?.basis, .improving)
        XCTAssertEqual(suggestion?.targetReps, 9)
        XCTAssertEqual(suggestion?.targetWeight, 50)
    }

    // MARK: - consistent basis (Strength mode)

    func test_strength_consistent_suggestsWeightBump() {
        // 4 sessions all at 50×9. avg.reps = 9. Recent 2 {9, 9} both >= 9 → consistent.
        // → weight = snap5(50 + 5) = 55, reps = 9.
        let records = AlgorithmFixtures.steadyHistory(count: 4, weight: 50, reps: 9)
        let suggestion = ProgressionService.suggestion(
            records: records,
            mode: .highWeightLowReps,
            params: .productionModerate
        )
        XCTAssertEqual(suggestion?.basis, .consistent)
        XCTAssertEqual(suggestion?.targetWeight, 55)
        XCTAssertEqual(suggestion?.targetReps, 9)
    }

    func test_strength_repCapTriggered_alwaysSuggestsWeightBump() {
        // 4 sessions all at 50×20. avg.reps = 20 ≥ 20 → forced consistent → weight = 55, reps = 20.
        let records = AlgorithmFixtures.steadyHistory(count: 4, weight: 50, reps: 20)
        let suggestion = ProgressionService.suggestion(
            records: records,
            mode: .highWeightLowReps,
            params: .productionModerate
        )
        XCTAssertEqual(suggestion?.basis, .consistent)
        XCTAssertEqual(suggestion?.targetWeight, 55)
        XCTAssertEqual(suggestion?.targetReps, 20)
    }

    // MARK: - Endurance mode

    func test_endurance_underCeiling_suggestsRepBump() {
        // 4 sessions at 30×15. avg.reps = 15. Endurance ceiling = 15+20 = 35.
        // Recent 2 both reps 15, neither >= 35 → improving → target reps 16.
        let records = AlgorithmFixtures.steadyHistory(count: 4, weight: 30, reps: 15, mode: .lowWeightHighReps)
        let suggestion = ProgressionService.suggestion(
            records: records,
            mode: .lowWeightHighReps,
            params: .productionModerate
        )
        XCTAssertEqual(suggestion?.basis, .improving)
        XCTAssertEqual(suggestion?.targetReps, 16)
        XCTAssertEqual(suggestion?.targetWeight, 30)
    }

    func test_endurance_aboveCeiling_suggestsWeightBump() {
        // Reps newest-first: [70, 70, 30, 30]. Sum = 200. Avg = 50.0 → 50.
        // Ceiling = 50 + 20 = 70. Recent 2 (moderate threshold 2): {70, 70}, both >= 70 → consistent.
        // → weight = snap5(30+5) = 35, reps = 50.
        let mixed: [ExerciseRecordSnapshot] = [
            AlgorithmFixtures.record(date: .now,                              mode: .lowWeightHighReps, sets: [SetSnapshot(weightLbs: 30, reps: 70, isWarmup: false, completedAt: .now)]),
            AlgorithmFixtures.record(date: .now.addingTimeInterval(-86400),   mode: .lowWeightHighReps, sets: [SetSnapshot(weightLbs: 30, reps: 70, isWarmup: false, completedAt: .now)]),
            AlgorithmFixtures.record(date: .now.addingTimeInterval(-86400*2), mode: .lowWeightHighReps, sets: [SetSnapshot(weightLbs: 30, reps: 30, isWarmup: false, completedAt: .now)]),
            AlgorithmFixtures.record(date: .now.addingTimeInterval(-86400*3), mode: .lowWeightHighReps, sets: [SetSnapshot(weightLbs: 30, reps: 30, isWarmup: false, completedAt: .now)]),
        ]
        let suggestion = ProgressionService.suggestion(
            records: mixed,
            mode: .lowWeightHighReps,
            params: .productionModerate
        )
        XCTAssertEqual(suggestion?.basis, .consistent)
        XCTAssertEqual(suggestion?.targetWeight, 35)
        XCTAssertEqual(suggestion?.targetReps, 50)
    }

    // MARK: - Mode filter

    func test_modeFilter_ignoresOtherMode() {
        // Endurance records, query for Strength → nil.
        let records = AlgorithmFixtures.steadyHistory(count: 5, weight: 30, reps: 15, mode: .lowWeightHighReps)
        let suggestion = ProgressionService.suggestion(
            records: records,
            mode: .highWeightLowReps,
            params: .productionModerate
        )
        XCTAssertNil(suggestion)
    }

    // MARK: - Parameter sensitivity

    func test_consistencyThresholdConservative_requiresMoreSessions() {
        // Reps newest-first: [9, 9, 7, 9]. Sum = 34. Avg = 34/4 = 8.5 → rounds to 9.
        // Moderate (threshold 2): recent 2 {9, 9}, allSatisfy {>= 9} → true → consistent.
        //   → weight = snap5(50+5) = 55, reps = 9.
        // Conservative (threshold 3): recent 3 {9, 9, 7}, allSatisfy {>= 9} → 7 < 9 → false.
        //   → improving → weight = snap5(50) = 50, reps = 9 + 1 = 10.
        let mixed: [ExerciseRecordSnapshot] = [
            AlgorithmFixtures.record(date: .now,                              sets: [SetSnapshot(weightLbs: 50, reps: 9, isWarmup: false, completedAt: .now)]),
            AlgorithmFixtures.record(date: .now.addingTimeInterval(-86400),   sets: [SetSnapshot(weightLbs: 50, reps: 9, isWarmup: false, completedAt: .now)]),
            AlgorithmFixtures.record(date: .now.addingTimeInterval(-86400*2), sets: [SetSnapshot(weightLbs: 50, reps: 7, isWarmup: false, completedAt: .now)]),
            AlgorithmFixtures.record(date: .now.addingTimeInterval(-86400*3), sets: [SetSnapshot(weightLbs: 50, reps: 9, isWarmup: false, completedAt: .now)]),
        ]
        let moderate = ProgressionService.suggestion(
            records: mixed, mode: .highWeightLowReps, params: .productionModerate
        )
        XCTAssertEqual(moderate?.basis, .consistent)
        XCTAssertEqual(moderate?.targetWeight, 55)
        XCTAssertEqual(moderate?.targetReps, 9)

        let conservative = ProgressionService.suggestion(
            records: mixed, mode: .highWeightLowReps, params: .productionConservative
        )
        XCTAssertEqual(conservative?.basis, .improving)
        XCTAssertEqual(conservative?.targetReps, 10)
        XCTAssertEqual(conservative?.targetWeight, 50)
    }

    func test_customWeightIncrement() {
        let records = AlgorithmFixtures.steadyHistory(count: 4, weight: 50, reps: 9)
        var custom = ProgressionParameters.productionModerate
        custom.weightIncrement = 10
        let suggestion = ProgressionService.suggestion(
            records: records, mode: .highWeightLowReps, params: custom
        )
        XCTAssertEqual(suggestion?.basis, .consistent)
        XCTAssertEqual(suggestion?.targetWeight, 60)  // snap5(50+10) = 60
    }

    // MARK: - Best-set tie-breaking

    func test_bestSet_firstOccurrenceWinsOnTie() {
        // Two sets at same weight, different reps. bestSet should pick the FIRST.
        let date = Date()
        let record = ExerciseRecordSnapshot(
            trainingMode: .highWeightLowReps,
            sessionDate: date,
            sets: [
                SetSnapshot(weightLbs: 50, reps: 8, isWarmup: false, completedAt: date),
                SetSnapshot(weightLbs: 50, reps: 12, isWarmup: false, completedAt: date),
            ]
        )
        // Single record → notEnoughData → returns the best set unchanged.
        let suggestion = ProgressionService.suggestion(
            records: [record],
            mode: .highWeightLowReps,
            params: .productionModerate
        )
        XCTAssertEqual(suggestion?.targetReps, 8)  // first-occurrence wins
    }

    // MARK: - Warmup handling

    func test_warmupSetsAreExcludedFromBestSet() {
        // Heavy warmup must not drive progression — working set wins.
        let date = Date()
        let record = ExerciseRecordSnapshot(
            trainingMode: .highWeightLowReps,
            sessionDate: date,
            sets: [
                SetSnapshot(weightLbs: 100, reps: 1, isWarmup: true, completedAt: date),
                SetSnapshot(weightLbs: 50, reps: 8, isWarmup: false, completedAt: date),
            ]
        )
        let suggestion = ProgressionService.suggestion(
            records: [record],
            mode: .highWeightLowReps,
            params: .productionModerate
        )
        XCTAssertEqual(suggestion?.targetWeight, 50)
        XCTAssertEqual(suggestion?.targetReps, 8)
    }

    func test_warmupOnlySession_returnsNil() {
        let date = Date()
        let record = ExerciseRecordSnapshot(
            trainingMode: .highWeightLowReps,
            sessionDate: date,
            sets: [
                SetSnapshot(weightLbs: 100, reps: 1, isWarmup: true, completedAt: date),
            ]
        )
        let suggestion = ProgressionService.suggestion(
            records: [record],
            mode: .highWeightLowReps,
            params: .productionModerate
        )
        XCTAssertNil(suggestion)
    }
}
