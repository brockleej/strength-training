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

@MainActor
final class SplitPersistenceTests: XCTestCase {

    override func setUp() {
        super.setUp()
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
        let container = try inMemoryContainer()
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
        let container = try inMemoryContainer()
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
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AppBackup.self, from: data)
        XCTAssertEqual(decoded.splitDays?.map(\.name), ["Pull", "Push", "Legs"])
    }

    func test_seedIfNeeded_skipsStartersWhenSplitAlreadyConfigured() throws {
        let container = try inMemoryContainer()
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
        let container = try inMemoryContainer()
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
        let container = try inMemoryContainer()
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
        let container = try inMemoryContainer()
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
        let container = try inMemoryContainer()
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
        let container = try inMemoryContainer()
        let context = container.mainContext
        let starter = Exercise(name: "Lateral Raise", dayType: .push, muscleGroup: "Shoulders")
        let custom = Exercise(name: "My Bench", dayType: .push, muscleGroup: "Chest", isCustom: true)
        context.insert(starter)
        context.insert(custom)
        try context.save()

        XCTAssertTrue(SeedData.stripUnusedStarterExtras(context: context))
        XCTAssertFalse(starter.belongs(to: .push))
        XCTAssertTrue(custom.belongs(to: .push))
    }

    func test_stripUnusedStarterExtras_keepsStartersWithHistory() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        let starter = Exercise(name: "Lateral Raise", dayType: .push, muscleGroup: "Shoulders")
        let custom = Exercise(name: "My Bench", dayType: .push, muscleGroup: "Chest", isCustom: true)
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
        let container = try inMemoryContainer()
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
        let bench = Exercise(name: "Barbell Bench Press", dayType: .push, muscleGroup: "Chest")
        let extra = Exercise(name: "Lateral Raise", dayType: .push, muscleGroup: "Shoulders")
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

    func test_applyDayPlanSnapshot_stripsCloudKitStarterExtras() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        let keep = Exercise(name: "My Bench", dayType: .push, muscleGroup: "Chest", isCustom: true)
        let extra = Exercise(name: "Lateral Raise", dayType: .push, muscleGroup: "Shoulders")
        context.insert(keep)
        context.insert(extra)
        try context.save()

        let snapshot = [DayPlanBackup(dayName: "Push", exerciseIDs: [keep.id])]
        XCTAssertTrue(SeedData.applyDayPlanSnapshot(snapshot, context: context))
        XCTAssertTrue(keep.belongs(to: .push))
        XCTAssertFalse(extra.belongs(to: .push))
    }

    func test_deduplicateExercises_collapsesSeedAndUserCopyByName() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        let seeded = Exercise(name: "Dumbbell Bench Press", dayType: .push, muscleGroup: "Chest")
        let user = Exercise(name: "Dumbbell Bench Press", dayType: nil, muscleGroup: "Chest", isCustom: true)
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
        let container = try inMemoryContainer()
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
        let first = Exercise(name: "My Bench", dayType: .push, muscleGroup: "Chest", sortOrder: 0, isCustom: true)
        let second = Exercise(name: "My Fly", dayType: .push, muscleGroup: "Chest", sortOrder: 1, isCustom: true)
        first.setSortIndex(0, for: .push)
        second.setSortIndex(1, for: .push)
        context.insert(first)
        context.insert(second)
        try context.save()

        let data = try BackupService.export(context: context)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AppBackup.self, from: data)
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
