//
//  PlannedBlockQueueTests.swift
//  RockLogTests
//
//  Queue order, unused vs started, and the Today ownership flag.
//

import XCTest
import SwiftData
@testable import RockLog

@MainActor
final class PlannedBlockQueueTests: RockLogStoreTestCase {

    func test_nextUpLabel_namesTheDayWithoutAMiss() {
        XCTAssertEqual(PlannedBlockQueue.nextUpLabel(dayName: "Push"), "Next up: Push")
        XCTAssertFalse(PlannedBlockQueue.nextUpLabel(dayName: "Push").localizedCaseInsensitiveContains("missed"))
    }

    func test_cardSecondary_distinguishesNextFromLater() {
        XCTAssertEqual(PlannedBlockQueue.cardSecondary(isNext: true, liftCount: 1), "Next up · 1 lift")
        XCTAssertEqual(PlannedBlockQueue.cardSecondary(isNext: false, liftCount: 3), "Then · 3 lifts")
    }

    func test_ownsToday_requiresAnUnusedSession() {
        XCTAssertFalse(PlannedBlockQueue.ownsToday(unusedCount: 0))
        XCTAssertTrue(PlannedBlockQueue.ownsToday(unusedCount: 2))
        XCTAssertFalse(PlannedBlockQueue.ownsToday([]))
    }

    func test_queueOrder_isPlanOrderThenDate() throws {
        let context = container.mainContext
        let laterOrder = makeSession(day: .pull, order: 2, dateOffset: -2, status: .planned, context: context)
        let earlierOrder = makeSession(day: .push, order: 0, dateOffset: 0, status: .planned, context: context)
        let sameOrderOlder = makeSession(day: .legs, order: 1, dateOffset: -5, status: .skipped, context: context)
        let sameOrderNewer = makeSession(day: .legs, order: 1, dateOffset: -1, status: .planned, context: context)
        try context.save()

        let queued = PlannedBlockQueue.unusedSessions(in: [laterOrder, sameOrderNewer, earlierOrder, sameOrderOlder])
        XCTAssertEqual(queued.map(\.id), [earlierOrder.id, sameOrderOlder.id, sameOrderNewer.id, laterOrder.id])
        XCTAssertEqual(PlannedBlockQueue.nextUnused(in: queued)?.id, earlierOrder.id)
        XCTAssertTrue(PlannedBlockQueue.ownsToday([laterOrder, earlierOrder]))
    }

    func test_skippedStaysUnused_completedAndStartedDoNot() throws {
        let context = container.mainContext
        let skipped = makeSession(day: .push, order: 0, dateOffset: -1, status: .skipped, context: context)
        let completed = makeSession(day: .pull, order: 1, dateOffset: -1, status: .planned, context: context)
        completed.isCompleted = true
        let startedEmpty = makeSession(day: .legs, order: 2, dateOffset: 0, status: .none, context: context)
        try context.save()

        XCTAssertTrue(PlannedBlockQueue.isUnused(skipped))
        XCTAssertFalse(PlannedBlockQueue.isUnused(completed))
        XCTAssertFalse(PlannedBlockQueue.isUnused(startedEmpty))
        XCTAssertEqual(PlannedBlockQueue.unusedSessions(in: [skipped, completed, startedEmpty]).map(\.id), [skipped.id])
    }

    func test_hasAthleteLoggedSets_ignoresTargets() throws {
        let context = container.mainContext
        let session = makeSession(day: .push, order: 0, dateOffset: 0, status: .planned, context: context)
        let exercise = Exercise.make(name: "UI Queue Lift", dayType: .push, isCustom: true)
        let record = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
        record.exercise = exercise
        record.session = session
        let target = SetRecord(setNumber: 1, weightLbs: 100, reps: 5, isTarget: true)
        target.exerciseRecord = record
        record.sets = [target]
        session.exerciseRecords = [record]
        context.insert(exercise)
        context.insert(record)
        context.insert(target)
        try context.save()

        XCTAssertFalse(PlannedBlockQueue.hasAthleteLoggedSets(session))

        let logged = SetRecord(setNumber: 1, weightLbs: 95, reps: 5)
        logged.exerciseRecord = record
        record.sets?.append(logged)
        context.insert(logged)
        try context.save()

        XCTAssertTrue(PlannedBlockQueue.hasAthleteLoggedSets(session))
    }

    func test_emptyStore_hasNoNextSession() {
        XCTAssertNil(PlannedBlockQueue.nextUnused(in: []))
        XCTAssertTrue(PlannedBlockQueue.unusedSessions(in: []).isEmpty)
    }

    private func makeSession(
        day: DayType,
        order: Int,
        dateOffset: Int,
        status: SessionPlanState,
        context: ModelContext
    ) -> WorkoutSession {
        let date = Calendar.current.date(byAdding: .day, value: dateOffset, to: Date()) ?? Date()
        let session = WorkoutSession(dayType: day, date: date)
        session.planOrder = order
        session.planStatus = status
        session.followsSessionRoster = true
        context.insert(session)
        return session
    }
}
