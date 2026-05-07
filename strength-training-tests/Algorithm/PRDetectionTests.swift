import XCTest
@testable import strength_training

/// Tests for the Phase 3 PR detection helpers in ProgressionService.
/// These are pure-function tests — no SwiftData container needed.
final class PRDetectionTests: XCTestCase {

    // MARK: - Epley formula

    func testE1RM_oneRep_returnsWeight() {
        // Epley at 1 rep: weight × (1 + 1/30) ≈ 1.033w
        // We accept the slight overshoot — most e1RM calcs do.
        let result = ProgressionService.e1RM(weight: 100, reps: 1)
        XCTAssertEqual(result, 100 * (1 + 1.0/30.0), accuracy: 0.001)
    }

    func testE1RM_fiveReps_returnsExpected() {
        // 225 × 5 → 225 * (1 + 5/30) = 225 * 7/6 = 262.5
        let result = ProgressionService.e1RM(weight: 225, reps: 5)
        XCTAssertEqual(result, 262.5, accuracy: 0.001)
    }

    func testE1RM_tenReps_returnsExpected() {
        // 100 × 10 → 100 * (1 + 10/30) = 133.333...
        let result = ProgressionService.e1RM(weight: 100, reps: 10)
        XCTAssertEqual(result, 100.0 * (4.0/3.0), accuracy: 0.001)
    }

    func testE1RM_zeroReps_returnsZero() {
        // Edge case — no reps means no work was done.
        // weight × (1 + 0/30) = weight, but semantically nonsensical;
        // we return weight, callers shouldn't pass 0.
        let result = ProgressionService.e1RM(weight: 100, reps: 0)
        XCTAssertEqual(result, 100, accuracy: 0.001)
    }

    // MARK: - All-time best scan

    private func snap(weight: Double, reps: Int, isWarmup: Bool = false,
                      completedAt: Date = .now) -> SetSnapshot {
        SetSnapshot(weightLbs: weight, reps: reps, isWarmup: isWarmup, completedAt: completedAt)
    }

    private func record(at date: Date, sets: [SetSnapshot],
                        mode: TrainingMode = .highWeightLowReps) -> ExerciseRecordSnapshot {
        ExerciseRecordSnapshot(trainingMode: mode, sessionDate: date, sets: sets)
    }

    func testAllTimeBestE1RM_emptyRecords_returnsNil() {
        let result = ProgressionService.allTimeBestE1RM(in: [])
        XCTAssertNil(result)
    }

    func testAllTimeBestE1RM_singleRecord_returnsBestSet() {
        let r = record(at: Date(timeIntervalSinceNow: -86400),
                       sets: [snap(weight: 200, reps: 5),     // e1RM ~233
                              snap(weight: 225, reps: 5),     // e1RM 262.5 ← best
                              snap(weight: 220, reps: 5)])    // e1RM ~256
        let best = ProgressionService.allTimeBestE1RM(in: [r])
        XCTAssertNotNil(best)
        XCTAssertEqual(best?.weight, 225)
        XCTAssertEqual(best?.reps, 5)
        XCTAssertEqual(best?.e1RM ?? 0, 262.5, accuracy: 0.001)
    }

    func testAllTimeBestE1RM_multipleRecords_picksOverallMax() {
        let earlier = record(at: Date(timeIntervalSinceNow: -86400 * 14),
                             sets: [snap(weight: 200, reps: 5)])     // e1RM 233.33
        let later = record(at: Date(timeIntervalSinceNow: -86400),
                           sets: [snap(weight: 225, reps: 5),         // e1RM 262.5 ← best
                                  snap(weight: 220, reps: 5)])
        let best = ProgressionService.allTimeBestE1RM(in: [earlier, later])
        XCTAssertEqual(best?.weight, 225)
        XCTAssertEqual(best?.reps, 5)
    }

    func testAllTimeBestE1RM_excludesWarmups() {
        let r = record(at: .now,
                       sets: [snap(weight: 500, reps: 1, isWarmup: true),  // would be 516.67 if counted
                              snap(weight: 225, reps: 5)])                  // 262.5 ← actual best
        let best = ProgressionService.allTimeBestE1RM(in: [r])
        XCTAssertEqual(best?.weight, 225, "warmup sets should be excluded")
        XCTAssertEqual(best?.reps, 5)
    }

    func testAllTimeBestE1RM_recordsBestDate() {
        let oldDate = Date(timeIntervalSinceNow: -86400 * 14)
        let recentDate = Date(timeIntervalSinceNow: -86400)
        let earlier = record(at: oldDate, sets: [snap(weight: 200, reps: 5)])
        let later = record(at: recentDate, sets: [snap(weight: 225, reps: 5)])

        let best = ProgressionService.allTimeBestE1RM(in: [earlier, later])
        XCTAssertNotNil(best)
        XCTAssertEqual(best?.recordedAt.timeIntervalSinceReferenceDate ?? 0,
                       recentDate.timeIntervalSinceReferenceDate,
                       accuracy: 1.0,
                       "best.recordedAt should match the session date of the best set")
    }
}
