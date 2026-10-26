//
//  ProgressionServiceParityTests.swift
//  RockLogTests
//

import XCTest
import SwiftData
@testable import RockLog

@MainActor
final class ProgressionServiceParityTests: RockLogStoreTestCase {

    /// Insert a small synthetic dataset: one Exercise with 6 completed sessions in
    /// Strength mode and 4 completed sessions in Endurance mode, plus one incomplete.
    private func seed(_ context: ModelContext) {
        let exercise = Exercise.make(name: "TestEx", dayType: .arms, muscleGroup: "Test")
        context.insert(exercise)

        let baseDate = Date()
        // Strength: 6 sessions with varying reps to exercise multiple branches
        for (i, reps) in [9, 8, 9, 7, 8, 9].enumerated() {
            let session = WorkoutSession(dayType: .arms, date: baseDate.addingTimeInterval(TimeInterval(-i * 86400)))
            session.isCompleted = true
            context.insert(session)
            let rec = ExerciseRecord(trainingMode: .highWeightLowReps)
            rec.exercise = exercise
            rec.session = session
            context.insert(rec)
            let set = SetRecord(setNumber: 1, weightLbs: 50, reps: reps, isWarmup: false)
            set.exerciseRecord = rec
            context.insert(set)
        }

        // Endurance: 4 sessions, varying reps near the ceiling boundary
        for (i, reps) in [25, 28, 22, 24].enumerated() {
            let session = WorkoutSession(dayType: .arms, date: baseDate.addingTimeInterval(TimeInterval(-(i + 10) * 86400)))
            session.isCompleted = true
            context.insert(session)
            let rec = ExerciseRecord(trainingMode: .lowWeightHighReps)
            rec.exercise = exercise
            rec.session = session
            context.insert(rec)
            let set = SetRecord(setNumber: 1, weightLbs: 30, reps: reps, isWarmup: false)
            set.exerciseRecord = rec
            context.insert(set)
        }

        // One incomplete session — should be filtered out by the adapter.
        let incomplete = WorkoutSession(dayType: .arms, date: baseDate)
        incomplete.isCompleted = false
        context.insert(incomplete)
        let incRec = ExerciseRecord(trainingMode: .highWeightLowReps)
        incRec.exercise = exercise
        incRec.session = incomplete
        context.insert(incRec)
        let incSet = SetRecord(setNumber: 1, weightLbs: 999, reps: 99, isWarmup: false)
        incSet.exerciseRecord = incRec
        context.insert(incSet)

        try? context.save()
    }

    func test_wrapperAndPureFunctionAgree_acrossAllModesAndAggressiveness() throws {
        let context = ModelContext(container)
        seed(context)

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(exercises.count, 1)
        let exercise = exercises[0]

        for mode in TrainingMode.allCases {
            for aggressiveness in [ProgressionAggressiveness.moderate, .conservative] {
                // Wrapper API
                let wrapperResult = ProgressionService.suggestion(
                    for: exercise,
                    mode: mode,
                    aggressiveness: aggressiveness
                )

                // Pure API — recreate the same input the wrapper builds internally.
                let snapshots = exercise.recordsArray
                    .filter { $0.session?.isCompleted == true }
                    .sorted { ProgressionService.isNewerForProgression($0, than: $1) }
                    .compactMap { record -> ExerciseRecordSnapshot? in
                        guard let sessionDate = record.session?.date else { return nil }
                        return ExerciseRecordSnapshot(
                            trainingMode: record.trainingMode,
                            sessionDate: sessionDate,
                            sets: record.setsArray.map {
                                SetSnapshot(
                                    weightLbs: $0.weightLbs,
                                    reps: $0.reps,
                                    isWarmup: $0.isWarmup,
                                    completedAt: $0.completedAt
                                )
                            }
                        )
                    }
                let pureResult = ProgressionService.suggestion(
                    records: snapshots,
                    mode: mode,
                    params: aggressiveness.parameters
                )

                XCTAssertEqual(wrapperResult?.targetWeight, pureResult?.targetWeight, "weight mismatch for \(mode) \(aggressiveness)")
                XCTAssertEqual(wrapperResult?.targetReps, pureResult?.targetReps, "reps mismatch for \(mode) \(aggressiveness)")
                XCTAssertEqual(wrapperResult?.basis, pureResult?.basis, "basis mismatch for \(mode) \(aggressiveness)")
            }
        }
    }

    func test_recentAverageWrapperParity() throws {
        let context = ModelContext(container)
        seed(context)

        let exercise = try context.fetch(FetchDescriptor<Exercise>())[0]

        for mode in TrainingMode.allCases {
            let wrapperAvg = ProgressionService.recentAverage(for: exercise, mode: mode)
            let snapshots = exercise.recordsArray
                .filter { $0.session?.isCompleted == true }
                .sorted { ProgressionService.isNewerForProgression($0, than: $1) }
                .compactMap { record -> ExerciseRecordSnapshot? in
                    guard let sessionDate = record.session?.date else { return nil }
                    return ExerciseRecordSnapshot(
                        trainingMode: record.trainingMode,
                        sessionDate: sessionDate,
                        sets: record.setsArray.map {
                            SetSnapshot(weightLbs: $0.weightLbs, reps: $0.reps, isWarmup: $0.isWarmup, completedAt: $0.completedAt)
                        }
                    )
                }
            let pureAvg = ProgressionService.recentAverage(records: snapshots, mode: mode, window: 4)
            XCTAssertEqual(wrapperAvg?.weight, pureAvg?.weight, "weight mismatch for \(mode)")
            XCTAssertEqual(wrapperAvg?.reps, pureAvg?.reps, "reps mismatch for \(mode)")
            XCTAssertEqual(wrapperAvg?.sessionCount, pureAvg?.sessionCount, "session count mismatch for \(mode)")
        }
    }

    /// Same timestamp used to leave order up to the relationship array.
    /// Descending session id is the tie-break: the FFFF session is newest,
    /// so the recent pair is 1 rep and 10 reps and the suggestion stays on reps.
    func test_b9_sameDateSessions_orderBySessionID() throws {
        let context = ModelContext(container)
        let exercise = Exercise.make(name: "Squat", dayType: .legs, muscleGroup: "Quads")
        context.insert(exercise)
        let when = Date(timeIntervalSince1970: 1_700_000_000)

        // Insert low ids first. A date-only sort would keep that order and
        // treat the two 10-rep sessions as the recent pair (weight bump).
        let rows: [(String, Int)] = [
            ("00000000-0000-0000-0000-000000000001", 10),
            ("00000000-0000-0000-0000-000000000002", 10),
            ("FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF", 1),
        ]
        for (id, reps) in rows {
            let session = WorkoutSession(dayType: .legs, date: when)
            session.id = UUID(uuidString: id)!
            session.isCompleted = true
            context.insert(session)
            let record = ExerciseRecord(trainingMode: .highWeightLowReps)
            record.exercise = exercise
            record.session = session
            context.insert(record)
            let set = SetRecord(setNumber: 1, weightLbs: 50, reps: reps, isWarmup: false)
            set.exerciseRecord = record
            context.insert(set)
        }
        try context.save()

        let suggestion = ProgressionService.suggestion(
            for: exercise,
            mode: .highWeightLowReps,
            aggressiveness: .moderate
        )
        XCTAssertEqual(suggestion?.basis, .improving)
        XCTAssertEqual(suggestion?.targetWeight, 50)
        XCTAssertEqual(suggestion?.targetReps, 8)
    }
}
