//
//  WorkoutSessionLogicTests.swift
//  RockLogTests
//

import XCTest
import SwiftData
@testable import RockLog

@MainActor
final class WorkoutSessionLogicTests: RockLogStoreTestCase {

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

    // MARK: - Duration

    func test_duration_storedWinsWhenCloseToSetSpan() {
        let start = Date(timeIntervalSince1970: 1_000)
        let seconds = WorkoutDurationLogic.resolvedSeconds(
            stored: 90 * 60,
            sessionStart: start,
            setDates: [start, start.addingTimeInterval(80 * 60)]
        )
        XCTAssertEqual(seconds, 90 * 60)
    }

    func test_duration_ignoresStoredWhenStartOrLateFinishInflatedIt() {
        let start = Date(timeIntervalSince1970: 1_000)
        let seconds = WorkoutDurationLogic.resolvedSeconds(
            stored: 220 * 60,
            sessionStart: start,
            setDates: [start.addingTimeInterval(60), start.addingTimeInterval(50 * 60)]
        )
        XCTAssertEqual(seconds, 49 * 60)
    }

    func test_duration_infersFromFirstToLastSet() {
        let start = Date(timeIntervalSince1970: 1_000)
        let seconds = WorkoutDurationLogic.resolvedSeconds(
            stored: 0,
            sessionStart: start,
            setDates: [start.addingTimeInterval(60), start.addingTimeInterval(3_600)]
        )
        XCTAssertEqual(seconds, 3_540)
    }

    func test_duration_doesNotCountIdleBeforeFirstSet() {
        let start = Date(timeIntervalSince1970: 1_000)
        let seconds = WorkoutDurationLogic.inferredSeconds(
            sessionStart: start,
            setDates: [start.addingTimeInterval(120), start.addingTimeInterval(720)]
        )
        XCTAssertEqual(seconds, 600)
    }

    func test_duration_zeroWithoutSetsOrStored() {
        XCTAssertEqual(
            WorkoutDurationLogic.resolvedSeconds(
                stored: 0,
                sessionStart: Date(),
                setDates: []
            ),
            0
        )
    }

    func test_duration_minutesLabel() {
        XCTAssertNil(WorkoutDurationLogic.minutesLabel(0))
        XCTAssertEqual(WorkoutDurationLogic.minutesLabel(20), "1")
        XCTAssertEqual(WorkoutDurationLogic.minutesLabel(47 * 60), "47")
    }

    func test_duration_secondsToStoreUsesSetSpanNotStartToFinishWall() {
        let start = Date(timeIntervalSince1970: 1_000)
        let now = start.addingTimeInterval(4 * 3_600)
        let seconds = WorkoutDurationLogic.secondsToStore(
            liveElapsed: 4 * 3_600,
            sessionStart: start,
            setDates: [start.addingTimeInterval(3_600), start.addingTimeInterval(3_600 + 45 * 60)],
            now: now
        )
        XCTAssertEqual(seconds, 45 * 60 + WorkoutDurationLogic.wrapUpAllowance)
    }

    func test_duration_secondsToStoreCapsWrapUpAfterLastSet() {
        let start = Date(timeIntervalSince1970: 1_000)
        let last = start.addingTimeInterval(3_600)
        let now = last.addingTimeInterval(3_600)
        let seconds = WorkoutDurationLogic.secondsToStore(
            liveElapsed: 0,
            sessionStart: start,
            setDates: [start, last],
            now: now
        )
        XCTAssertEqual(seconds, 3_600 + WorkoutDurationLogic.wrapUpAllowance)
    }

    // MARK: - Delete set + renumber

    @MainActor
    func test_deleteSet_removesAndRenumbers() throws {
        let context = container.mainContext

        let exercise = Exercise.make(name: "Bench", dayType: .push, muscleGroup: "Chest", sortOrder: 0)
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
    func test_volumeAndSetCount_ignorePlannedTargets() throws {
        let context = container.mainContext
        let exercise = Exercise.make(name: "Squat", dayType: .legs, muscleGroup: "Legs", sortOrder: 0)
        let session = WorkoutSession(dayType: .legs)
        session.isCompleted = true
        let record = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
        record.exercise = exercise
        record.session = session
        let planned = SetRecord(setNumber: 1, weightLbs: 315, reps: 5, isTarget: true)
        let logged = SetRecord(setNumber: 1, weightLbs: 225, reps: 5)
        planned.exerciseRecord = record
        logged.exerciseRecord = record
        record.sets = [planned, logged]
        session.exerciseRecords = [record]
        context.insert(exercise)
        context.insert(session)
        context.insert(record)
        context.insert(planned)
        context.insert(logged)
        try context.save()

        XCTAssertEqual(SessionMath.setCount(of: session), 1)
        XCTAssertEqual(SessionMath.volume(of: session), 225 * 5)
        XCTAssertEqual(record.loggedSetsArray.count, 1)
        XCTAssertEqual(record.plannedSetsArray.count, 1)
    }

    @MainActor
    func test_deleteLoggedSet_doesNotRenumberPlannedTargets() throws {
        let context = container.mainContext
        let exercise = Exercise.make(name: "Bench", dayType: .push, muscleGroup: "Chest", sortOrder: 0)
        let session = WorkoutSession(dayType: .push)
        let record = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
        record.exercise = exercise
        record.session = session
        let plan1 = SetRecord(setNumber: 1, weightLbs: 185, reps: 5, isTarget: true)
        let plan2 = SetRecord(setNumber: 2, weightLbs: 205, reps: 5, isTarget: true)
        let log1 = SetRecord(setNumber: 1, weightLbs: 185, reps: 5)
        let log2 = SetRecord(setNumber: 2, weightLbs: 195, reps: 5)
        for set in [plan1, plan2, log1, log2] { set.exerciseRecord = record }
        record.sets = [plan1, plan2, log1, log2]
        context.insert(exercise)
        context.insert(session)
        context.insert(record)
        [plan1, plan2, log1, log2].forEach { context.insert($0) }
        try context.save()

        SetMutation.delete(log1, from: record, in: context)
        try context.save()

        XCTAssertEqual(record.plannedSetsArray.map(\.setNumber), [1, 2])
        XCTAssertEqual(record.loggedSetsArray.map(\.setNumber), [1])
        XCTAssertEqual(record.loggedSetsArray.first?.weightLbs, 195)
    }

    @MainActor
    func test_deleteOnlySet_leavesEmptyRecord() throws {
        let context = container.mainContext

        let exercise = Exercise.make(name: "Curl", dayType: .arms, muscleGroup: "Biceps", sortOrder: 0)
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
    func test_deleteSet_undoRestoresTheLoggedSet() throws {
        let context = container.mainContext
        let exercise = Exercise.make(name: "Bench", dayType: .push, muscleGroup: "Chest", sortOrder: 0)
        let session = WorkoutSession(dayType: .push)
        let record = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
        record.exercise = exercise
        record.session = session
        session.exerciseRecords = [record]
        let first = SetRecord(setNumber: 1, weightLbs: 135, reps: 8)
        let second = SetRecord(setNumber: 2, weightLbs: 155, reps: 5)
        for set in [first, second] { set.exerciseRecord = record }
        record.sets = [first, second]
        context.insert(exercise)
        context.insert(session)
        context.insert(record)
        context.insert(first)
        context.insert(second)
        try context.save()

        let vm = holdWorkoutViewModel(WorkoutViewModel(
            modelContext: context,
            healthKitService: HealthKitWorkoutService()
        ))
        vm.activeSession = session
        XCTAssertEqual(vm.setUndoSeconds, 5, accuracy: 0.001)
        vm.deleteSet(first, from: exercise)
        XCTAssertEqual(record.loggedSetsArray.map(\.weightLbs), [155])
        XCTAssertNotNil(vm.pendingSetUndo)
        vm.undoDeletedSet()
        let restored = record.loggedSetsArray.sorted { $0.setNumber < $1.setNumber }
        XCTAssertEqual(restored.map(\.setNumber), [1, 2])
        XCTAssertEqual(restored.map(\.weightLbs), [135, 155])
        XCTAssertEqual(restored.map(\.reps), [8, 5])
        XCTAssertNil(vm.pendingSetUndo)
    }

    @MainActor
    func test_deleteSet_undoExpiresWithoutRestoring() async throws {
        let context = container.mainContext
        let exercise = Exercise.make(name: "Curl", dayType: .arms, muscleGroup: "Biceps", sortOrder: 0)
        let session = WorkoutSession(dayType: .arms)
        let record = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
        record.exercise = exercise
        record.session = session
        session.exerciseRecords = [record]
        let set = SetRecord(setNumber: 1, weightLbs: 30, reps: 12)
        set.exerciseRecord = record
        record.sets = [set]
        context.insert(exercise)
        context.insert(session)
        context.insert(record)
        context.insert(set)
        try context.save()

        let vm = holdWorkoutViewModel(WorkoutViewModel(
            modelContext: context,
            healthKitService: HealthKitWorkoutService()
        ))
        vm.activeSession = session
        vm.setUndoSeconds = 0.05
        vm.deleteSet(set, from: exercise)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertNil(vm.pendingSetUndo)
        vm.undoDeletedSet()
        XCTAssertTrue(record.loggedSetsArray.isEmpty)
    }

    @MainActor
    func test_midnightCrossingWorkout_staysOpenUntilSixHoursAfterLastSet() throws {
        let context = container.mainContext
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        let session = WorkoutSession(dayType: .push, date: startOfToday.addingTimeInterval(-60))
        let exercise = Exercise.make(name: "Bench", dayType: .push, muscleGroup: "Chest", sortOrder: 0)
        let record = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
        record.exercise = exercise
        record.session = session
        session.exerciseRecords = [record]
        let set = SetRecord(setNumber: 1, weightLbs: 185, reps: 5)
        set.completedAt = now.addingTimeInterval(-60 * 60)
        set.exerciseRecord = record
        record.sets = [set]
        context.insert(exercise)
        context.insert(session)
        context.insert(record)
        context.insert(set)
        try context.save()

        let vm = holdWorkoutViewModel(WorkoutViewModel(
            modelContext: context,
            healthKitService: HealthKitWorkoutService()
        ))
        XCTAssertFalse(session.isCompleted, "relaunch within 6 hours of the last set must stay open")

        let later = set.completedAt.addingTimeInterval(WorkoutViewModel.staleLoggedWorkoutInterval)
        vm.autoCompleteStaleSession(now: later)
        XCTAssertTrue(session.isCompleted)
    }

    @MainActor
    func test_emptyPreviousDaySession_isRemoved_todayEmptySessionStays() throws {
        let context = container.mainContext
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        let yesterday = WorkoutSession(dayType: .pull, date: startOfToday.addingTimeInterval(-3_600))
        let today = WorkoutSession(dayType: .push, date: now)
        context.insert(yesterday)
        context.insert(today)
        try context.save()
        let todayID = today.id

        _ = holdWorkoutViewModel(WorkoutViewModel(
            modelContext: context,
            healthKitService: HealthKitWorkoutService()
        ))

        let remaining = try context.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(remaining.map(\.id), [todayID])
        XCTAssertFalse(remaining[0].isCompleted)
    }

    /// A second finish must not cancel the first finish's HealthKit save.
    func test_secondFinishKeepsHealthKitUUIDAndEffortRating() async throws {
        #if DEBUG
        let previousCancels = WorkoutViewModel.cancelsDeferredSaves
        WorkoutViewModel.cancelsDeferredSaves = true
        defer { WorkoutViewModel.cancelsDeferredSaves = previousCancels }
        #endif

        let context = container.mainContext
        let exercise = Exercise.make(name: "Bench", dayType: .push, muscleGroup: "Chest", isCustom: true)
        let session = WorkoutSession(dayType: .push)
        let record = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
        record.exercise = exercise
        record.session = session
        session.exerciseRecords = [record]
        let set = SetRecord(setNumber: 1, weightLbs: 135, reps: 5)
        set.completedAt = Date()
        set.exerciseRecord = record
        record.sets = [set]
        context.insert(exercise)
        context.insert(session)
        context.insert(record)
        context.insert(set)
        try context.save()

        let workoutID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let gate = FinishEndGate()
        defer { gate.releaseAll() }
        let service = HealthKitWorkoutService()
        service.endWorkoutOverride = { await gate.end() }
        service.saveEffortRatingOverride = { _, _ in
            await Task.yield()
        }
        let viewModel = holdWorkoutViewModel(
            WorkoutViewModel(modelContext: context, healthKitService: service)
        )
        XCTAssertEqual(viewModel.activeSession?.id, session.id)

        viewModel.finishSession()
        await waitUntil { gate.waiting == 1 }

        viewModel.saveEffortRating(8)
        XCTAssertEqual(session.effortRating, 8)

        viewModel.finishSession()
        await waitUntil { gate.waiting == 2 }

        gate.release(workoutID)
        await waitUntil { session.healthKitWorkoutUUID == workoutID }

        gate.release(nil)
        await waitUntil { gate.waiting == 0 }
        for _ in 0..<20 {
            await Task.yield()
        }

        XCTAssertEqual(session.healthKitWorkoutUUID, workoutID)
        XCTAssertEqual(session.effortRating, 8)
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        _ condition: () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() >= deadline {
                XCTFail("Timed out waiting for the double-finish save")
                return
            }
            await Task.yield()
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    /// Suspends each `endWorkout` until the test releases it, in order.
    private final class FinishEndGate: @unchecked Sendable {
        private let lock = NSLock()
        private var waiters: [CheckedContinuation<UUID?, Never>] = []

        func end() async -> UUID? {
            await withCheckedContinuation { continuation in
                lock.lock()
                waiters.append(continuation)
                lock.unlock()
            }
        }

        func release(_ uuid: UUID?) {
            lock.lock()
            let waiter = waiters.isEmpty ? nil : waiters.removeFirst()
            lock.unlock()
            waiter?.resume(returning: uuid)
        }

        func releaseAll() {
            lock.lock()
            let pending = waiters
            waiters.removeAll()
            lock.unlock()
            pending.forEach { $0.resume(returning: nil) }
        }

        var waiting: Int {
            lock.lock()
            defer { lock.unlock() }
            return waiters.count
        }
    }
}

@MainActor
final class SplitPersistenceTests: RockLogStoreTestCase {

    override func setUp() async throws {
        try await super.setUp()
        let defaults = UserDefaults.standard
        let kvs = NSUbiquitousKeyValueStore.default
        for key in [
            SeedData.hasConfiguredSplitKey,
            SeedData.preferredSplitPresetKey,
            SeedData.splitSnapshotKey,
            SeedData.dayPlanSnapshotKey,
            SeedData.hasSeededExercisesKey,
            SeedData.strippedUnusedStarterExtrasKey,
        ] {
            defaults.removeObject(forKey: key)
            kvs.removeObject(forKey: key)
        }
    }

    func test_inferSplit_usesSessionDays_notExerciseCatalog() {
        let backup = AppBackup(
            version: 1,
            exportedAt: .now,
            exercises: [
                ExerciseBackup(
                    id: UUID(),
                    name: "Curl",
                    dayType: "Arms",
                    muscleGroup: "Biceps",
                    sortOrder: 0,
                    isCustom: false,
                    notes: ""
                ),
            ],
            sessions: [
                WorkoutSessionBackup(
                    id: UUID(),
                    date: Date(timeIntervalSince1970: 100),
                    dayType: "Push",
                    notes: "",
                    isCompleted: true,
                    exerciseRecords: []
                ),
                WorkoutSessionBackup(
                    id: UUID(),
                    date: Date(timeIntervalSince1970: 200),
                    dayType: "Legs",
                    notes: "",
                    isCompleted: true,
                    exerciseRecords: []
                ),
                WorkoutSessionBackup(
                    id: UUID(),
                    date: Date(timeIntervalSince1970: 300),
                    dayType: "Posterior Chain",
                    notes: "",
                    isCompleted: true,
                    exerciseRecords: []
                ),
                WorkoutSessionBackup(
                    id: UUID(),
                    date: Date(timeIntervalSince1970: 400),
                    dayType: "Pull",
                    notes: "",
                    isCompleted: true,
                    exerciseRecords: []
                ),
            ],
            splitDays: nil
        )
        let names = BackupService.inferSplit(from: backup).map(\.name)
        XCTAssertEqual(names, ["Push", "Pull", "Legs", "Posterior Chain"])
        XCTAssertFalse(names.contains("Arms"))
        XCTAssertFalse(names.contains("Full Body"))
    }

    func test_applySnapshot_removesBroExtrasAndKeepsOrder() throws {
        let context = container.mainContext
        for (index, name) in ["Arms", "Push", "Legs", "Full Body", "Pull", "Posterior Chain"].enumerated() {
            let def = DayTypePalette.fallback(for: name)
            context.insert(
                SplitDay(
                    name: def.name,
                    systemImage: def.systemImage,
                    subtitle: def.subtitle,
                    colorHex: def.colorHex,
                    includesAllExercises: def.includesAllExercises,
                    sortOrder: index
                )
            )
        }
        try context.save()

        let snapshot = ["Push", "Legs", "Posterior Chain", "Pull"].enumerated().map { index, name in
            let def = DayTypePalette.fallback(for: name)
            return SplitDayBackup(
                id: UUID(),
                name: def.name,
                systemImage: def.systemImage,
                subtitle: def.subtitle,
                colorHex: Int(def.colorHex),
                includesAllExercises: def.includesAllExercises,
                sortOrder: index
            )
        }
        XCTAssertTrue(SeedData.applySplitSnapshot(snapshot, context: context))
        let names = ((try? context.fetch(
            FetchDescriptor<SplitDay>(sortBy: [SortDescriptor(\SplitDay.sortOrder)])
        )) ?? []).map(\.name)
        XCTAssertEqual(names, ["Push", "Legs", "Posterior Chain", "Pull"])
    }

    func test_backupRoundTrip_includesSplitOrder() throws {
        let context = container.mainContext
        for (index, name) in ["Pull", "Push", "Legs"].enumerated() {
            let def = DayTypePalette.fallback(for: name)
            context.insert(
                SplitDay(
                    name: def.name,
                    systemImage: def.systemImage,
                    subtitle: def.subtitle,
                    colorHex: def.colorHex,
                    includesAllExercises: def.includesAllExercises,
                    sortOrder: index
                )
            )
        }
        try context.save()

        let data = try BackupService.export(context: context)
        let decoded = try BackupService.decode(data)
        XCTAssertEqual(decoded.splitDays?.map(\.name), ["Pull", "Push", "Legs"])
    }

    func test_seedIfNeeded_skipsStartersWhenSplitAlreadyConfigured() throws {
        let context = container.mainContext
        for (index, name) in ["Push", "Pull", "Legs", "Posterior Chain"].enumerated() {
            let def = DayTypePalette.fallback(for: name)
            context.insert(
                SplitDay(
                    name: def.name,
                    systemImage: def.systemImage,
                    subtitle: def.subtitle,
                    colorHex: def.colorHex,
                    includesAllExercises: def.includesAllExercises,
                    sortOrder: index
                )
            )
        }
        try context.save()
        UserDefaults.standard.set(true, forKey: SeedData.hasConfiguredSplitKey)

        SeedData.seedIfNeeded(context: context)

        let onPush = ((try? context.fetch(FetchDescriptor<Exercise>())) ?? [])
            .filter { $0.belongs(to: .push) }
        XCTAssertTrue(onPush.isEmpty, "Reinstall with a saved split must not pin starter lifts onto days")
    }

    func test_seedIfNeeded_doesNotApplyStartersUntilUserChooses() throws {
        let context = container.mainContext

        SeedData.seedIfNeeded(context: context)

        XCTAssertTrue(SeedData.needsFirstUseSplitSetup(context: context))
        let days = (try? context.fetch(FetchDescriptor<SplitDay>())) ?? []
        XCTAssertTrue(days.isEmpty, "First use must not invent a Bro Split before the picker")
        let assigned = ((try? context.fetch(FetchDescriptor<Exercise>())) ?? [])
            .filter { !$0.isUnassigned }
        XCTAssertTrue(assigned.isEmpty, "Starter lifts wait for the first-use question")
    }

    func test_applyPreset_withStartersPinsTemplateLifts() throws {
        let context = container.mainContext
        SeedData.seedIfNeeded(context: context)
        DayTypeRegistry.shared.applyPreset(
            .pushPullLegs,
            context: context,
            includeStarters: true
        )
        let onPush = ((try? context.fetch(FetchDescriptor<Exercise>())) ?? [])
            .filter { $0.belongs(to: .push) }
            .map(\.name)
        XCTAssertTrue(onPush.contains("Dumbbell Bench Press"))
        XCTAssertTrue(onPush.contains("Overhead Press"))
        XCTAssertFalse(SeedData.needsFirstUseSplitSetup(context: context))
    }

    func test_applyPreset_broSplitStartersIncludeFullBody() throws {
        let context = container.mainContext
        SeedData.seedIfNeeded(context: context)
        DayTypeRegistry.shared.applyPreset(
            .broSplit,
            context: context,
            includeStarters: true
        )
        let days = ((try? context.fetch(
            FetchDescriptor<SplitDay>(sortBy: [SortDescriptor(\SplitDay.sortOrder)])
        )) ?? [])
        XCTAssertEqual(days.map(\.name), ["Arms", "Legs", "Full Body"])
        XCTAssertFalse(days.contains { $0.name == "Full Body" && $0.includesAllExercises })
        let onFull = ((try? context.fetch(FetchDescriptor<Exercise>())) ?? [])
            .filter { $0.belongs(to: .fullBody) }
            .map(\.name)
        XCTAssertEqual(Set(onFull), [
            "Goblet Squat",
            "Dumbbell Bench Press",
            "Seated Cable Row",
            "Overhead Press",
        ])
    }

    func test_applyPreset_withoutStartersLeavesDaysEmpty() throws {
        let context = container.mainContext
        SeedData.seedIfNeeded(context: context)
        DayTypeRegistry.shared.applyPreset(
            .pplPosterior,
            context: context,
            includeStarters: false
        )
        let names = ((try? context.fetch(
            FetchDescriptor<SplitDay>(sortBy: [SortDescriptor(\SplitDay.sortOrder)])
        )) ?? []).map(\.name)
        XCTAssertEqual(names, ["Push", "Pull", "Legs", "Posterior Chain"])
        let assigned = ((try? context.fetch(FetchDescriptor<Exercise>())) ?? [])
            .filter { !$0.isUnassigned }
        XCTAssertTrue(assigned.isEmpty)
    }

    func test_stripUnusedStarterExtras_removesSeededDefaultsFromMixedDay() throws {
        let context = container.mainContext
        let starter = Exercise.make(name: "Lateral Raise", dayType: .push, muscleGroup: "Shoulders")
        let custom = Exercise.make(name: "My Bench", dayType: .push, muscleGroup: "Chest", isCustom: true)
        context.insert(starter)
        context.insert(custom)
        try context.save()

        XCTAssertTrue(SeedData.stripUnusedStarterExtras(context: context))
        XCTAssertFalse(starter.belongs(to: .push))
        XCTAssertTrue(custom.belongs(to: .push))
    }

    func test_stripUnusedStarterExtras_keepsStartersWithHistory() throws {
        let context = container.mainContext
        let starter = Exercise.make(name: "Lateral Raise", dayType: .push, muscleGroup: "Shoulders")
        let custom = Exercise.make(name: "My Bench", dayType: .push, muscleGroup: "Chest", isCustom: true)
        let session = WorkoutSession(dayType: .push)
        session.isCompleted = true
        let record = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
        record.exercise = starter
        record.session = session
        let set = SetRecord(setNumber: 1, weightLbs: 20, reps: 12)
        set.exerciseRecord = record
        record.sets = [set]
        starter.records = [record]
        session.exerciseRecords = [record]
        context.insert(starter)
        context.insert(custom)
        context.insert(session)
        context.insert(record)
        context.insert(set)
        try context.save()

        XCTAssertFalse(SeedData.stripUnusedStarterExtras(context: context))
        XCTAssertTrue(starter.belongs(to: .push))
    }

    func test_removeDayType_dropsLiftFromDayPlanAndKeepsLibrary() throws {
        let context = container.mainContext
        let def = DayTypePalette.fallback(for: "Push")
        context.insert(
            SplitDay(
                name: def.name,
                systemImage: def.systemImage,
                subtitle: def.subtitle,
                colorHex: def.colorHex,
                includesAllExercises: def.includesAllExercises,
                sortOrder: 0
            )
        )
        let bench = Exercise.make(name: "Barbell Bench Press", dayType: .push, muscleGroup: "Chest")
        let extra = Exercise.make(name: "Lateral Raise", dayType: .push, muscleGroup: "Shoulders")
        context.insert(bench)
        context.insert(extra)
        try context.save()
        SeedData.persistUserPlan(context: context)

        extra.removeDayType(.push)
        try context.save()
        SeedData.persistUserPlan(context: context)

        XCTAssertTrue(bench.belongs(to: .push))
        XCTAssertFalse(extra.belongs(to: .push))
        XCTAssertTrue(extra.isUnassigned)
        let snapshot = try XCTUnwrap(SeedData.loadDayPlanSnapshot())
        let pushPlan = try XCTUnwrap(snapshot.first { $0.dayName == "Push" })
        XCTAssertEqual(pushPlan.exerciseIDs, [bench.id])
        XCTAssertFalse(pushPlan.exerciseIDs.contains(extra.id))
    }

    /// Crash bisect for `test_applyDayPlanSnapshot_stripsCloudKitStarterExtras`.
    /// Each step is its own test so a host crash names the step.
    func test_starterExtras_stepMakeOnly() {
        _ = starterExtraExercises()
    }

    func test_starterExtras_stepInsertAndSave() throws {
        let context = container.mainContext
        _ = insertStarterExtras(into: context)
        try context.save()
    }

    func test_starterExtras_stepFetch() throws {
        let context = container.mainContext
        let inserted = insertStarterExtras(into: context)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(fetched.count, 2)
        let ids = fetched.map(\.id)
        XCTAssertEqual(Set(ids).count, 2, "Fetch still returned one shared exercise id")
        XCTAssertEqual(Set(ids), Set([inserted.keep.id, inserted.extra.id]))
    }

    func test_starterExtras_stepApplySnapshot() throws {
        let context = container.mainContext
        let inserted = insertStarterExtras(into: context)
        try context.save()
        let snapshot = [DayPlanBackup(dayName: "Push", exerciseIDs: [inserted.keep.id])]
        _ = SeedData.applyDayPlanSnapshot(snapshot, context: context)
    }

    func test_applyDayPlanSnapshot_stripsCloudKitStarterExtras() throws {
        let context = container.mainContext
        let keep = Exercise.make(name: "My Bench", dayType: .push, muscleGroup: "Chest", isCustom: true)
        let extra = Exercise.make(name: "Lateral Raise", dayType: .push, muscleGroup: "Shoulders")
        let keepID = keep.id
        let extraID = extra.id
        keep.insertPinned(into: context)
        extra.insertPinned(into: context)
        try context.save()
        XCTAssertNotEqual(
            keepID,
            extraID,
            "Shared schema-default ids crash applyDayPlanSnapshot in DEBUG"
        )

        let snapshot = [DayPlanBackup(dayName: "Push", exerciseIDs: [keepID])]
        XCTAssertTrue(SeedData.applyDayPlanSnapshot(snapshot, context: context))

        let fetched = try context.fetch(FetchDescriptor<Exercise>())
        let kept = try XCTUnwrap(fetched.first { $0.id == keepID })
        let stripped = try XCTUnwrap(fetched.first { $0.id == extraID })
        XCTAssertTrue(kept.belongs(to: .push))
        XCTAssertFalse(stripped.belongs(to: .push))
    }

    private func starterExtraExercises() -> (keep: Exercise, extra: Exercise) {
        let keep = Exercise.make(name: "My Bench", dayType: .push, muscleGroup: "Chest", isCustom: true)
        let extra = Exercise.make(name: "Lateral Raise", dayType: .push, muscleGroup: "Shoulders")
        return (keep, extra)
    }

    private func insertStarterExtras(into context: ModelContext) -> (keep: Exercise, extra: Exercise) {
        let pair = starterExtraExercises()
        pair.keep.insertPinned(into: context)
        pair.extra.insertPinned(into: context)
        return pair
    }

    func test_newExercises_keepDistinctIDsThroughFetch() throws {
        let context = container.mainContext
        let lifts = [
            Exercise.make(name: "UI Distinct One", isCustom: true),
            Exercise.make(name: "UI Distinct Two", isCustom: true),
            Exercise.make(name: "UI Distinct Three", isCustom: true),
        ]
        let ids = lifts.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        for lift in lifts {
            lift.insertPinned(into: context)
        }
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Exercise>())
        let fetchedIDs = fetched.map(\.id)
        XCTAssertEqual(fetchedIDs.count, 3)
        XCTAssertEqual(Set(fetchedIDs).count, fetchedIDs.count)
        XCTAssertEqual(Set(fetchedIDs), Set(ids))
    }

    func test_seedIfNeeded_doesNotRestoreCatalogAfterUserDeletesEveryExercise() throws {
        let context = container.mainContext
        SeedData.seedIfNeeded(context: context)
        let seeded = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertFalse(seeded.isEmpty)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: SeedData.hasSeededExercisesKey))

        for exercise in seeded {
            context.delete(exercise)
        }
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Exercise>()), 0)

        SeedData.seedIfNeeded(context: context)
        XCTAssertEqual(
            try context.fetchCount(FetchDescriptor<Exercise>()),
            0,
            "Deleting every exercise must not bring the starter catalog back"
        )
    }

    func test_applyOrder_movesPullAheadOfPush() throws {
        let context = container.mainContext
        let names = ["Push", "Pull", "Legs"]
        var days: [SplitDay] = []
        for (index, name) in names.enumerated() {
            let def = DayTypePalette.fallback(for: name)
            let day = SplitDay(
                name: def.name,
                systemImage: def.systemImage,
                subtitle: def.subtitle,
                colorHex: def.colorHex,
                includesAllExercises: def.includesAllExercises,
                sortOrder: index
            )
            context.insert(day)
            days.append(day)
        }
        try context.save()

        let pull = try XCTUnwrap(days.first { $0.name == "Pull" })
        let push = try XCTUnwrap(days.first { $0.name == "Push" })
        let legs = try XCTUnwrap(days.first { $0.name == "Legs" })
        DayTypeRegistry.shared.applyOrder(ids: [pull.id, push.id, legs.id], context: context)

        let ordered = try context.fetch(
            FetchDescriptor<SplitDay>(sortBy: [SortDescriptor(\SplitDay.sortOrder)])
        )
        XCTAssertEqual(ordered.map(\.name), ["Pull", "Push", "Legs"])
        XCTAssertEqual(pull.sortOrder, 0, "Position label becomes \"1. Pull\"")
    }

    func test_resetExerciseCatalogSeed_isIgnoredOutsideTheEmptyUITestPreset() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: SeedData.hasSeededExercisesKey)
        defaults.set(2, forKey: "exerciseCatalogVersion")
        defaults.set(true, forKey: SeedData.strippedUnusedStarterExtrasKey)

        SeedData.resetExerciseCatalogSeed()

        XCTAssertTrue(defaults.bool(forKey: SeedData.hasSeededExercisesKey))
        XCTAssertEqual(defaults.integer(forKey: "exerciseCatalogVersion"), 2)
        XCTAssertTrue(defaults.bool(forKey: SeedData.strippedUnusedStarterExtrasKey))
    }

    func test_deduplicateExercises_collapsesSeedAndUserCopyByName() throws {
        let context = container.mainContext
        let seeded = Exercise.make(name: "Dumbbell Bench Press", dayType: .push, muscleGroup: "Chest")
        let user = Exercise.make(name: "Dumbbell Bench Press", dayType: nil, muscleGroup: "Chest", isCustom: true)
        let session = WorkoutSession(dayType: .push)
        session.isCompleted = true
        let record = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
        record.exercise = user
        record.session = session
        user.records = [record]
        session.exerciseRecords = [record]
        context.insert(seeded)
        context.insert(user)
        context.insert(session)
        context.insert(record)
        try context.save()

        SeedData.deduplicateExercises(context: context)
        let remaining = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.id, user.id)
    }

    func test_restorePrompt_asksToReplaceExistingSplitAndExercises() {
        let current = BackupSummary(
            splitDayNames: ["Push", "Pull", "Legs", "Posterior Chain"],
            assignedExerciseCount: 18,
            exerciseCount: 90,
            sessionCount: 12
        )
        let incoming = BackupSummary(
            splitDayNames: ["Push", "Pull", "Legs", "Posterior Chain"],
            assignedExerciseCount: 16,
            exerciseCount: 90,
            sessionCount: 11
        )
        let prompt = BackupService.restorePrompt(current: current, incoming: incoming)
        XCTAssertEqual(prompt.title, "Replace current split?")
        XCTAssertEqual(prompt.confirmTitle, "Replace split and exercises")
        XCTAssertEqual(prompt.cancelTitle, "Don't restore")
        XCTAssertTrue(prompt.message.contains("There is currently a split with exercises"))
        XCTAssertTrue(prompt.message.contains("Push, Pull, Legs, Posterior Chain"))
        XCTAssertTrue(prompt.message.contains("18 exercises"))
        XCTAssertTrue(prompt.message.contains("16 exercises"))
    }

    func test_restorePrompt_emptyPhoneUsesSimpleRestore() {
        let current = BackupSummary(
            splitDayNames: [],
            assignedExerciseCount: 0,
            exerciseCount: 0,
            sessionCount: 0
        )
        let incoming = BackupSummary(
            splitDayNames: ["Push", "Pull"],
            assignedExerciseCount: 8,
            exerciseCount: 40,
            sessionCount: 3
        )
        let prompt = BackupService.restorePrompt(current: current, incoming: incoming)
        XCTAssertEqual(prompt.title, "Restore backup?")
        XCTAssertEqual(prompt.confirmTitle, "Restore")
        XCTAssertFalse(prompt.message.contains("There is currently a split"))
        XCTAssertTrue(prompt.message.contains("becomes your split"))
    }

    func test_restorePrompt_unassignedCatalogUsesSimpleRestore() {
        let current = BackupSummary(
            splitDayNames: [],
            assignedExerciseCount: 0,
            exerciseCount: 90,
            sessionCount: 0
        )
        let incoming = BackupSummary(
            splitDayNames: ["Push", "Pull", "Legs"],
            assignedExerciseCount: 12,
            exerciseCount: 90,
            sessionCount: 8
        )
        let prompt = BackupService.restorePrompt(current: current, incoming: incoming)
        XCTAssertEqual(prompt.confirmTitle, "Restore")
        XCTAssertFalse(prompt.message.contains("There is currently a split"))
    }

    func test_summarizeBackup_countsAssignedLifts() {
        let backup = AppBackup(
            version: 1,
            exportedAt: .now,
            exercises: [
                ExerciseBackup(
                    id: UUID(),
                    name: "Bench",
                    dayType: "Push",
                    muscleGroup: "Chest",
                    sortOrder: 0,
                    isCustom: true,
                    notes: ""
                ),
                ExerciseBackup(
                    id: UUID(),
                    name: "Curl",
                    dayType: "",
                    muscleGroup: "Biceps",
                    sortOrder: 1,
                    isCustom: true,
                    notes: "",
                    extraDayTypes: ""
                ),
            ],
            sessions: [],
            splitDays: [
                SplitDayBackup(
                    id: UUID(),
                    name: "Push",
                    systemImage: "dumbbell.fill",
                    subtitle: "",
                    colorHex: 0,
                    includesAllExercises: false,
                    sortOrder: 0
                ),
            ]
        )
        let summary = BackupService.summarize(backup: backup)
        XCTAssertEqual(summary.splitDayNames, ["Push"])
        XCTAssertEqual(summary.assignedExerciseCount, 1)
        XCTAssertEqual(summary.exerciseCount, 2)
    }

    func test_backupRoundTrip_preservesDayMembershipAndOrder() throws {
        let context = container.mainContext
        let push = DayTypePalette.fallback(for: "Push")
        context.insert(
            SplitDay(
                name: push.name,
                systemImage: push.systemImage,
                subtitle: push.subtitle,
                colorHex: push.colorHex,
                includesAllExercises: push.includesAllExercises,
                sortOrder: 0
            )
        )
        let first = Exercise.make(name: "My Bench", dayType: .push, muscleGroup: "Chest", sortOrder: 0, isCustom: true)
        let second = Exercise.make(name: "My Fly", dayType: .push, muscleGroup: "Chest", sortOrder: 1, isCustom: true)
        first.setSortIndex(0, for: .push)
        second.setSortIndex(1, for: .push)
        context.insert(first)
        context.insert(second)
        try context.save()

        let data = try BackupService.export(context: context)
        let decoded = try BackupService.decode(data)
        XCTAssertEqual(decoded.dayPlans?.first?.dayName, "Push")
        XCTAssertEqual(decoded.dayPlans?.first?.exerciseIDs, [first.id, second.id])
        XCTAssertEqual(decoded.exercises.first { $0.id == first.id }?.daySortOrdersRaw, "Push:0")

        try BackupService.restore(from: data, context: context)
        let restored = ((try? context.fetch(FetchDescriptor<Exercise>())) ?? [])
            .filter { $0.belongs(to: .push) }
            .sorted { $0.sortIndex(for: .push) < $1.sortIndex(for: .push) }
        XCTAssertEqual(restored.map(\.name), ["My Bench", "My Fly"])
        XCTAssertEqual(restored.map { $0.sortIndex(for: .push) }, [0, 1])
    }

    func test_explicitExerciseID_survivesInsertSaveFetchAndRestore() throws {
        let context = container.mainContext
        let explicit = UUID(uuidString: "E1000000-0000-4000-8000-0000000000AA")!
        let exercise = Exercise.make(name: "UI Explicit Id", dayType: .push, muscleGroup: "Chest", isCustom: true)
        ExplicitPersistentID.pin(explicit, assign: { exercise.id = $0 }) {
            context.insert(exercise)
        }
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(fetched.map(\.id), [explicit])

        let data = try BackupService.export(context: context)
        try BackupService.restore(from: data, context: context)
        let restored = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(restored.map(\.id), [explicit])
        XCTAssertEqual(restored.map(\.name), ["UI Explicit Id"])
    }

    func test_explicitExerciseID_survivesFetchInANewContext() throws {
        let context = container.mainContext
        let explicit = UUID(uuidString: "E1000000-0000-4000-8000-0000000000CC")!
        let exercise = Exercise.make(name: "UI New Context Id", dayType: .push, muscleGroup: "Chest", isCustom: true)
        ExplicitPersistentID.pin(explicit, assign: { exercise.id = $0 }) {
            context.insert(exercise)
        }
        try context.save()

        let other = ModelContext(container)
        other.autosaveEnabled = false
        let fetched = try other.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(fetched.map(\.id), [explicit])
        XCTAssertEqual(fetched.map(\.name), ["UI New Context Id"])
    }

    func test_applySplitSnapshot_keepsExplicitDayID() throws {
        let context = container.mainContext
        let explicit = UUID(uuidString: "E1000000-0000-4000-8000-0000000000BB")!
        let snap = SplitDayBackup(
            id: explicit,
            name: "Push",
            systemImage: "dumbbell.fill",
            subtitle: "",
            colorHex: 0,
            includesAllExercises: false,
            sortOrder: 0
        )
        XCTAssertTrue(SeedData.applySplitSnapshot([snap], context: context))
        let days = try context.fetch(FetchDescriptor<SplitDay>())
        XCTAssertEqual(days.map(\.id), [explicit])
    }

    func test_duplicateExerciseIDs_areReassignedAndReferencesFollow() throws {
        let context = container.mainContext
        let shared = UUID(uuidString: "E2000000-0000-4000-8000-000000000002")!
        let gym = UUID(uuidString: "E2000000-0000-4000-8000-000000000003")!
        defer {
            UserDefaults.standard.removeObject(forKey: SeedData.dayPlanSnapshotKey)
            RestTimerPreferences.discardExerciseSetting(shared)
            RestSampleStore.discard(exerciseID: shared)
        }

        let first = Exercise.make(name: "UI First Duplicate", dayType: .push, muscleGroup: "Chest", isCustom: true)
        let later = Exercise.make(name: "UI Later Duplicate", dayType: .push, muscleGroup: "Chest", isCustom: true)
        context.insert(first)
        context.insert(later)

        let session = WorkoutSession(dayType: .push)
        let record = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
        record.exercise = later
        record.session = session
        session.exerciseRecords = [record]
        later.records = [record]
        context.insert(session)
        context.insert(record)

        let profile = MachineStackProfile(gymID: gym, exerciseID: shared)
        context.insert(profile)
        profile.exerciseID = shared
        profile.gymID = gym
        profile.stepPounds = 12.5

        // Pin after relationships. An id write inside init is discarded, and
        // assigning `records` can rematerialize the schema default.
        first.id = shared
        later.id = shared
        session.suppressExercise(id: shared)

        RestTimerPreferences.setEnabled(false, forExercise: shared)
        RestSampleStore.record(90, for: shared)
        try context.save()
        defer {
            RestTimerPreferences.discardExerciseSetting(later.id)
            RestSampleStore.discard(exerciseID: later.id)
        }

        let backup = AppBackup(
            version: 1,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            exercises: [],
            sessions: [],
            dayPlans: [DayPlanBackup(dayName: "Push", exerciseIDs: [shared])]
        )
        SeedData.restoreDayPlans(from: backup, context: context)

        let fetched = try context.fetch(FetchDescriptor<Exercise>())
        let fetchedFirst = try XCTUnwrap(fetched.first { $0.name == "UI First Duplicate" })
        let fetchedLater = try XCTUnwrap(fetched.first { $0.name == "UI Later Duplicate" })
        XCTAssertEqual(fetchedFirst.id, shared)
        XCTAssertNotEqual(fetchedLater.id, shared)
        XCTAssertNotEqual(fetchedFirst.id, fetchedLater.id)

        let fetchedRecords = try context.fetch(FetchDescriptor<ExerciseRecord>())
        XCTAssertEqual(fetchedRecords.count, 1)
        XCTAssertEqual(fetchedRecords.first?.exercise?.name, "UI First Duplicate")
        XCTAssertEqual(fetchedRecords.first?.exercise?.id, shared)

        XCTAssertTrue(fetchedFirst.belongs(to: .push))
        XCTAssertTrue(fetchedLater.belongs(to: .push))

        let fetchedSession = try XCTUnwrap(try context.fetch(FetchDescriptor<WorkoutSession>()).first)
        XCTAssertTrue(fetchedSession.suppressedExerciseIDs.contains(shared))
        XCTAssertTrue(fetchedSession.suppressedExerciseIDs.contains(fetchedLater.id))

        let profiles = try context.fetch(FetchDescriptor<MachineStackProfile>())
        XCTAssertEqual(profiles.first { $0.exerciseID == shared }?.stepPounds, 12.5)
        XCTAssertEqual(profiles.first { $0.exerciseID == fetchedLater.id }?.stepPounds, 12.5)

        XCTAssertFalse(RestTimerPreferences.isEnabled(forExercise: shared))
        XCTAssertFalse(RestTimerPreferences.isEnabled(forExercise: fetchedLater.id))
        XCTAssertEqual(RestSampleStore.samples(for: fetchedLater.id), [90])
    }

    func test_reassignDuplicateExerciseIDs_keepsEveryExerciseRecord() throws {
        let context = container.mainContext
        let shared = UUID(uuidString: "E2000000-0000-4000-8000-0000000000C1")!
        let keeper = Exercise.make(
            name: "UI Record Keeper",
            dayType: .push,
            muscleGroup: "Chest",
            sortOrder: 0,
            isCustom: true
        )
        let duplicate = Exercise.make(
            name: "UI Record Duplicate",
            dayType: .push,
            muscleGroup: "Chest",
            sortOrder: 1,
            isCustom: true
        )
        context.insert(keeper)
        context.insert(duplicate)

        let onKeeper = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
        let onDuplicate = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 1)
        onKeeper.exercise = keeper
        onDuplicate.exercise = duplicate
        context.insert(onKeeper)
        context.insert(onDuplicate)
        keeper.id = shared
        duplicate.id = shared
        try context.save()

        let before = try context.fetchCount(FetchDescriptor<ExerciseRecord>())
        XCTAssertEqual(before, 2)
        _ = SeedData.reassignDuplicateExerciseIDs(context: context, persistSnapshot: false)
        try context.save()

        let after = try context.fetch(FetchDescriptor<ExerciseRecord>())
        XCTAssertEqual(after.count, before)
        XCTAssertEqual(
            after.compactMap { $0.exercise?.name }.sorted(),
            ["UI Record Keeper", "UI Record Keeper"]
        )
        XCTAssertEqual(Set(after.compactMap { $0.exercise?.id }), [shared])
    }

    func test_emptyLibraryRestTimer_isOnOnlyWhenLaunchAsks() {
        XCTAssertTrue(
            UITestLaunch.restTimerEnabled(arguments: ["-RockLogRestTimer", "on"])
        )
        XCTAssertFalse(UITestLaunch.restTimerEnabled(arguments: ["-RockLogRestTimer", "off"]))
        XCTAssertFalse(UITestLaunch.restTimerEnabled(arguments: []))
    }
}

@MainActor
final class ReorderScrollLockTests: XCTestCase {
    func test_cancelledDragReleasesScrollLock() {
        var lock = ReorderScrollLock()
        let id = UUID()
        lock.arm(id)
        XCTAssertTrue(lock.scrollDisabled)
        XCTAssertEqual(lock.draggingID, id)

        lock.release(id)
        XCTAssertFalse(lock.scrollDisabled)
        XCTAssertNil(lock.draggingID)

        lock.arm(id)
        lock.release(UUID())
        XCTAssertTrue(lock.scrollDisabled, "A different row leaving must not clear this drag")
        lock.release(id)
        XCTAssertFalse(lock.scrollDisabled)
    }

    func test_reorderStepUsesMeasuredRowHeight() {
        // 30pt of travel on a 68pt Dynamic Type row stays put.
        // Dividing by a hard-coded 48pt would round that drag to the next slot.
        XCTAssertEqual(ReorderDragStep.delta(translation: 30, rowHeight: 68), 0)
        XCTAssertEqual(ReorderDragStep.delta(translation: 30, rowHeight: 48), 1)
        XCTAssertEqual(ReorderDragStep.delta(translation: 40, rowHeight: 0), 0)
        XCTAssertEqual(
            ReorderDragStep.targetIndex(start: 1, translation: -68, rowHeight: 68, count: 4),
            0
        )
        XCTAssertEqual(
            ReorderDragStep.targetIndex(start: 1, translation: 140, rowHeight: 68, count: 4),
            3
        )
    }
}

final class SplitOrderLogicTests: XCTestCase {
    func test_moveShiftsARowUpAndDown() {
        let first = UUID()
        let middle = UUID()
        let last = UUID()
        let ids = [first, middle, last]
        XCTAssertEqual(SplitOrderLogic.move(ids: ids, id: middle, by: -1), [middle, first, last])
        XCTAssertEqual(SplitOrderLogic.move(ids: ids, id: middle, by: 1), [first, last, middle])
    }

    func test_firstRowUpIsANoOp() {
        let first = UUID()
        let second = UUID()
        let ids = [first, second]
        XCTAssertEqual(SplitOrderLogic.move(ids: ids, id: first, by: -1), ids)
    }

    func test_lastRowDownIsANoOp() {
        let first = UUID()
        let second = UUID()
        let ids = [first, second]
        XCTAssertEqual(SplitOrderLogic.move(ids: ids, id: second, by: 1), ids)
    }

    func test_singleRowDoesNotMove() {
        let only = UUID()
        XCTAssertEqual(SplitOrderLogic.move(ids: [only], id: only, by: -1), [only])
        XCTAssertEqual(SplitOrderLogic.move(ids: [only], id: only, by: 1), [only])
    }

    func test_unknownIDLeavesTheList() {
        let first = UUID()
        let second = UUID()
        let ids = [first, second]
        XCTAssertEqual(SplitOrderLogic.move(ids: ids, id: UUID(), by: -1), ids)
    }
}

final class LazyTabContentTests: XCTestCase {
    func test_selectedTabIsBuiltThisPassAndPreviousTabsStay() {
        let workout = LazyTabContent.builtIDs(selected: "workout", already: [])
        XCTAssertTrue(LazyTabContent.isBuilt(id: "workout", in: workout))
        XCTAssertFalse(LazyTabContent.isBuilt(id: "settings", in: workout))
        XCTAssertFalse(LazyTabContent.isBuilt(id: "history", in: workout))

        let settings = LazyTabContent.builtIDs(selected: "settings", already: workout)
        XCTAssertTrue(LazyTabContent.isBuilt(id: "settings", in: settings))
        XCTAssertTrue(LazyTabContent.isBuilt(id: "workout", in: settings))
        XCTAssertFalse(LazyTabContent.isBuilt(id: "history", in: settings))

        let back = LazyTabContent.builtIDs(selected: "workout", already: settings)
        XCTAssertEqual(back, settings)
        XCTAssertTrue(LazyTabContent.isBuilt(id: "settings", in: back))
    }

    func test_builtTabMemoryGrowsInPlaceAndResetReplaces() {
        let memory = BuiltTabMemory(["workout"])
        XCTAssertTrue(memory.including("settings").contains("settings"))
        XCTAssertTrue(memory.including("workout").contains("settings"))
        memory.reset(keeping: "workout")
        let afterReset = memory.including("workout")
        XCTAssertEqual(afterReset, ["workout"])
    }
}
