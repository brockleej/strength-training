//
//  WorkoutSessionLogicTests.swift
//  strength-training-tests
//

import XCTest
import SwiftData
@testable import strength_training

final class WorkoutSessionLogicTests: XCTestCase {

    // MARK: - Finish prompt

    func test_offerFinish_whenEveryLiftDoneAndHasSets() {
        XCTAssertTrue(
            WorkoutCompletionLogic.shouldOfferFinish(liftCount: 4, doneCount: 4, hasAnySets: true)
        )
    }

    func test_offerFinish_falseWhenALiftRemains() {
        XCTAssertFalse(
            WorkoutCompletionLogic.shouldOfferFinish(liftCount: 4, doneCount: 3, hasAnySets: true)
        )
    }

    func test_offerFinish_falseWhenNoSetsLogged() {
        XCTAssertFalse(
            WorkoutCompletionLogic.shouldOfferFinish(liftCount: 3, doneCount: 3, hasAnySets: false)
        )
    }

    func test_offerFinish_falseWhenEmptyWorkout() {
        XCTAssertFalse(
            WorkoutCompletionLogic.shouldOfferFinish(liftCount: 0, doneCount: 0, hasAnySets: false)
        )
    }

    // MARK: - Delete set + renumber

    @MainActor
    func test_deleteSet_removesAndRenumbers() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext

        let exercise = Exercise(name: "Bench", dayType: .push, muscleGroup: "Chest", sortOrder: 0)
        let session = WorkoutSession(dayType: .push)
        let record = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
        record.exercise = exercise
        record.session = session
        session.exerciseRecords = [record]
        exercise.records = [record]

        let sets = (1...3).map { SetRecord(setNumber: $0, weightLbs: Double(135 + $0 * 10), reps: 5) }
        for set in sets {
            set.exerciseRecord = record
        }
        record.sets = sets

        context.insert(exercise)
        context.insert(session)
        context.insert(record)
        sets.forEach { context.insert($0) }
        try context.save()

        SetMutation.delete(sets[1], from: record, in: context)
        try context.save()

        let remaining = record.setsArray.sorted { $0.setNumber < $1.setNumber }
        XCTAssertEqual(remaining.count, 2)
        XCTAssertEqual(remaining.map(\.setNumber), [1, 2])
        XCTAssertEqual(remaining.map(\.weightLbs), [145, 165])
    }

    @MainActor
    func test_deleteOnlySet_leavesEmptyRecord() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext

        let exercise = Exercise(name: "Curl", dayType: .arms, muscleGroup: "Biceps", sortOrder: 0)
        let session = WorkoutSession(dayType: .arms)
        let record = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
        record.exercise = exercise
        record.session = session
        let set = SetRecord(setNumber: 1, weightLbs: 30, reps: 12)
        set.exerciseRecord = record
        record.sets = [set]

        context.insert(exercise)
        context.insert(session)
        context.insert(record)
        context.insert(set)
        try context.save()

        SetMutation.delete(set, from: record, in: context)
        try context.save()

        XCTAssertTrue(record.setsArray.isEmpty)
    }

    @MainActor
    private func inMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Exercise.self,
            WorkoutSession.self,
            ExerciseRecord.self,
            SetRecord.self,
            SplitDay.self,
            BodyMetricEntry.self,
            configurations: config
        )
    }
}
