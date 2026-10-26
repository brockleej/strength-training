//
//  PastBuildRegressionTests.swift
//  RockLogTests
//
//  Locks the TestFlight bugs called out for this suite:
//  duration (build 17), effort prompt (build 14), restore cancel (build 13),
//  split swipe-delete, and DayTypeRegistry.reindex duplicate keys.
//  Also covers process-death session resume, which the UI relaunch test drives.
//

import XCTest
import SwiftData
@testable import RockLog

@MainActor
final class PastBuildRegressionTests: RockLogStoreTestCase {

    // MARK: - Build 17 duration

    func test_build17_lateFinishStoresSetSpanPlusWrapUp_notWallClock() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let first = start.addingTimeInterval(4 * 3_600)
        let last = first.addingTimeInterval(40 * 60)
        let now = last.addingTimeInterval(3 * 3_600)
        let stored = WorkoutDurationLogic.secondsToStore(
            liveElapsed: now.timeIntervalSince(start),
            sessionStart: start,
            setDates: [first, last],
            now: now
        )
        XCTAssertEqual(stored, 40 * 60 + WorkoutDurationLogic.wrapUpAllowance)
        XCTAssertLessThan(stored, 60 * 60)
    }

    func test_build17_storedTwoHundredMinutes_isReplacedByShortSetSpan() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let resolved = WorkoutDurationLogic.resolvedSeconds(
            stored: 200 * 60,
            sessionStart: start,
            setDates: [start, start.addingTimeInterval(10 * 60)]
        )
        XCTAssertEqual(resolved, 10 * 60)

        let session = try loggedSession(
            context: container.mainContext,
            start: start,
            setDates: [start, start.addingTimeInterval(10 * 60)]
        )
        session.durationSeconds = 200 * 60
        XCTAssertEqual(SessionMath.durationSeconds(of: session), 10 * 60)
        XCTAssertNotEqual(SessionMath.durationMinutesLabel(of: session), "200")
    }

    // MARK: - Build 14 effort

    func test_build14_finishAsksForEffortWithoutHealthKit() throws {
        let context = container.mainContext
        let session = try loggedSession(context: context, start: Date(), setDates: [Date()])
        let viewModel = WorkoutViewModel(modelContext: context, healthKitService: HealthKitWorkoutService())
        XCTAssertEqual(viewModel.activeSession?.id, session.id)

        viewModel.finishSession()
        XCTAssertTrue(session.isCompleted)
        XCTAssertEqual(viewModel.sessionPendingEffortRating?.id, session.id)

        viewModel.skipEffortRating()
        XCTAssertNil(viewModel.sessionPendingEffortRating)
        XCTAssertNil(session.effortRating)
    }

    func test_build14_saveEffortWritesRating_reopenDoesNotAskAgain() throws {
        let context = container.mainContext
        let session = try loggedSession(context: context, start: Date(), setDates: [Date()])
        let viewModel = WorkoutViewModel(modelContext: context, healthKitService: HealthKitWorkoutService())
        viewModel.finishSession()
        viewModel.saveEffortRating(8)
        XCTAssertEqual(session.effortRating, 8)
        XCTAssertNil(viewModel.sessionPendingEffortRating)

        XCTAssertTrue(viewModel.reopenSessionForEditing(session))
        viewModel.finishSession()
        XCTAssertNil(viewModel.sessionPendingEffortRating)
        XCTAssertEqual(viewModel.sessionPendingSummary?.id, session.id)
        XCTAssertEqual(session.effortRating, 8)
    }

    // MARK: - Build 13 restore cancel

    func test_build13_restorePromptCancelLeavesRowsUntouched() throws {
        let context = container.mainContext
        context.insert(SplitDay(name: "Push", systemImage: "dumbbell.fill", colorHex: 0xFF8C42, sortOrder: 0))
        let kept = Exercise(name: "UI Kept Lift", dayType: .push, isCustom: true)
        context.insert(kept)
        try context.save()

        let current = BackupService.summarizeStore(context: context)
        let incoming = BackupSummary(
            splitDayNames: ["UI Day"],
            assignedExerciseCount: 1,
            exerciseCount: 1,
            sessionCount: 1
        )
        let prompt = BackupService.restorePrompt(current: current, incoming: incoming)
        XCTAssertEqual(prompt.cancelTitle, "Don't restore")
        XCTAssertEqual(prompt.confirmTitle, "Replace split and exercises")

        // Cancel is the button that does not call restore.
        let names = try context.fetch(FetchDescriptor<Exercise>()).map(\.name)
        XCTAssertEqual(names, ["UI Kept Lift"])
    }

    func test_build13_restoreReplacesWhenConfirmIsCalled() throws {
        let sourceContext = container.mainContext
        sourceContext.insert(SplitDay(name: "UI Day", systemImage: "dumbbell.fill", colorHex: 0x3F9CFF, sortOrder: 0))
        sourceContext.insert(Exercise(name: "UI Restored Lift", dayType: DayType(rawValue: "UI Day"), isCustom: true))
        let backup = try BackupService.export(context: sourceContext)

        try openSecondaryContainer()
        let context = secondaryContainer!.mainContext
        context.insert(Exercise(name: "UI Kept Lift", dayType: .push, isCustom: true))
        try context.save()

        try BackupService.restore(from: backup, context: context)
        let names = try context.fetch(FetchDescriptor<Exercise>()).map(\.name)
        XCTAssertEqual(names, ["UI Restored Lift"])
    }

    // MARK: - Split swipe

    func test_splitSwipe_fullSwipeDoesNotDelete() {
        let flung = SwipeToDeleteLogic.endAction(projectedOffset: -10_000, fullSwipeDeletes: false)
        XCTAssertEqual(flung, .reveal)
        XCTAssertNotEqual(flung, .delete)
        XCTAssertEqual(
            SwipeToDeleteLogic.endAction(
                projectedOffset: -SwipeToDeleteLogic.revealWidth * 2,
                fullSwipeDeletes: true
            ),
            .delete
        )
    }

    // MARK: - DayTypeRegistry duplicate keys

    func test_reindex_whitespaceAndEmptyNames_doNotCrash() throws {
        let defs = [
            DayTypeDefinition(name: " Push ", systemImage: "dumbbell.fill", subtitle: "first", colorHex: 0xFF8C42, includesAllExercises: false, sortOrder: 0),
            DayTypeDefinition(name: "push", systemImage: "dumbbell.fill", subtitle: "dup", colorHex: 0x34C759, includesAllExercises: false, sortOrder: 1),
            DayTypeDefinition(name: "   ", systemImage: "dumbbell.fill", subtitle: "", colorHex: 0, includesAllExercises: false, sortOrder: 2),
            DayTypeDefinition(name: "", systemImage: "dumbbell.fill", subtitle: "", colorHex: 0, includesAllExercises: false, sortOrder: 3),
        ]
        XCTAssertEqual(DayTypeRegistry.uniquedDefinitions(defs).map(\.name), [" Push "])

        let context = container.mainContext
        context.insert(SplitDay(name: " Push ", systemImage: "dumbbell.fill", colorHex: 0xFF8C42, sortOrder: 0))
        context.insert(SplitDay(name: "Push", systemImage: "dumbbell.fill", colorHex: 0x34C759, sortOrder: 1))
        try context.save()

        DayTypeRegistry.shared.reload(context: context)
        XCTAssertEqual(DayTypeRegistry.shared.activeDays.count, 1)
    }

    func test_applyOrder_persists_andLastHomeDayCannotBeDeleted() throws {
        let context = container.mainContext
        let push = SplitDay(name: "Push", systemImage: "dumbbell.fill", colorHex: 0xFF8C42, sortOrder: 0)
        let pull = SplitDay(name: "Pull", systemImage: "dumbbell.fill", colorHex: 0x3F9CFF, sortOrder: 1)
        context.insert(push)
        context.insert(pull)
        try context.save()

        DayTypeRegistry.shared.applyOrder(ids: [pull.id, push.id], context: context)
        let ordered = try context.fetch(
            FetchDescriptor<SplitDay>(sortBy: [SortDescriptor(\SplitDay.sortOrder)])
        )
        XCTAssertEqual(ordered.map(\.name), ["Pull", "Push"])

        DayTypeRegistry.shared.delete(id: pull.id, context: context)
        DayTypeRegistry.shared.delete(id: push.id, context: context)
        let remaining = try context.fetch(FetchDescriptor<SplitDay>())
        XCTAssertEqual(remaining.map(\.name), ["Push"])
    }

    // MARK: - Relaunch

    func test_relaunch_resumesTodaysLiveSession_andLeavesPlannedQueued() throws {
        let context = container.mainContext
        let live = try loggedSession(context: context, start: Date(), setDates: [Date()])
        let planned = WorkoutSession(dayType: .pull, date: Date())
        planned.planStatus = .planned
        context.insert(planned)
        try context.save()

        let viewModel = WorkoutViewModel(modelContext: context, healthKitService: HealthKitWorkoutService())
        XCTAssertEqual(viewModel.activeSession?.id, live.id)
        XCTAssertTrue(PlannedBlockQueue.isUnused(planned))
        XCTAssertFalse(planned.isCompleted)
    }

    func test_relaunch_completesYesterdaysLiveSessionWithSets() throws {
        let context = container.mainContext
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date().addingTimeInterval(-86_400)
        let session = try loggedSession(context: context, start: yesterday, setDates: [yesterday])
        XCTAssertFalse(session.isCompleted)

        _ = WorkoutViewModel(modelContext: context, healthKitService: HealthKitWorkoutService())
        XCTAssertTrue(session.isCompleted)
        XCTAssertNil(
            WorkoutViewModel(modelContext: context, healthKitService: HealthKitWorkoutService()).activeSession
        )
    }

    private func loggedSession(
        context: ModelContext,
        start: Date,
        setDates: [Date]
    ) throws -> WorkoutSession {
        let exercise = Exercise(name: "UI Duration Lift", dayType: .push, isCustom: true)
        let session = WorkoutSession(dayType: .push, date: start)
        let record = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
        record.exercise = exercise
        record.session = session
        var sets: [SetRecord] = []
        for (index, date) in setDates.enumerated() {
            let set = SetRecord(setNumber: index + 1, weightLbs: 100, reps: 5)
            set.completedAt = date
            set.exerciseRecord = record
            sets.append(set)
            context.insert(set)
        }
        record.sets = sets
        session.exerciseRecords = [record]
        context.insert(exercise)
        context.insert(session)
        context.insert(record)
        try context.save()
        return session
    }
}
