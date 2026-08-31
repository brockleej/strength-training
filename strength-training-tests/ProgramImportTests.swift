//
//  ProgramImportTests.swift
//  strength-training-tests
//
//  Merge import, warmup round-trip, unused-queue start, no fake History.
//

import XCTest
import SwiftData
@testable import strength_training

@MainActor
final class ProgramImportTests: XCTestCase {

    func test_confirmationCopy_isPlainLanguage() {
        XCTAssertEqual(
            ProgramImportService.confirmationMessage(weekCount: 8),
            "Add 8 weeks of planned workouts? This does not replace your history. The next unused workout waits until you start it."
        )
        XCTAssertEqual(
            ProgramImportService.confirmationMessage(weekCount: 1),
            "Add 1 week of planned workouts? This does not replace your history. The next unused workout waits until you start it."
        )
        XCTAssertEqual(PlannedBlockQueue.nextUpLabel(dayName: "Lower"), "Next up: Lower")
        XCTAssertEqual(PlannedBlockQueue.cardSecondary(isNext: true, liftCount: 6), "Next up · 6 lifts")
        XCTAssertEqual(PlannedBlockQueue.cardSecondary(isNext: false, liftCount: 1), "Then · 1 lift")
        XCTAssertFalse(PlannedBlockQueue.nextUpLabel(dayName: "Lower").localizedCaseInsensitiveContains("missed"))
        XCTAssertEqual(ProgramImportService.startThisBlockTodayTitle, "Start this block today")
        XCTAssertEqual(ProgramImportService.useThisSplitTitle, "Use this as your training split?")
        XCTAssertEqual(ProgramImportService.useThisSplitConfirmTitle, "Use this split")
        XCTAssertEqual(ProgramImportService.keepCurrentSplitTitle, "Keep my current split")
        XCTAssertEqual(ListMutationCopy.keepLastDayTitle, "Keep at least one day")
        XCTAssertTrue(ListMutationCopy.keepLastDayMessage.contains("one day"))
        XCTAssertTrue(ListMutationCopy.keepLastDayWithBlockMessage.contains("use it as your split"))
        XCTAssertFalse(ListMutationCopy.keepLastDayMessage.localizedCaseInsensitiveContains("JSON"))
        XCTAssertFalse(ListMutationCopy.keepLastDayWithBlockMessage.localizedCaseInsensitiveContains("DayType"))
        XCTAssertEqual(
            ProgramImportService.replaceSplitMessage(),
            "This replaces your current days and the lifts on each day with this block. Your old workouts stay in History."
        )
        XCTAssertFalse(ProgramImportService.replaceSplitMessage().localizedCaseInsensitiveContains("backup"))
        XCTAssertFalse(ProgramImportService.replaceSplitMessage().localizedCaseInsensitiveContains("JSON"))
        XCTAssertFalse(ProgramImportService.confirmationMessage(weekCount: 8).localizedCaseInsensitiveContains("schema"))
        XCTAssertFalse(ProgramImportService.confirmationMessage(weekCount: 8).localizedCaseInsensitiveContains("JSON"))
        XCTAssertFalse(ProgramImportService.confirmationMessage(weekCount: 8).localizedCaseInsensitiveContains("dates in the file"))
        let added = ProgramImportSummary(
            blockName: "Demo",
            sessionCount: 8,
            weekCount: 8,
            createdExerciseCount: 0,
            skippedDuplicateSessionCount: 0
        )
        XCTAssertEqual(
            ProgramImportService.resultMessage(summary: added, replacedSplit: false),
            "Added 8 weeks of planned workouts. Your history is unchanged."
        )
        XCTAssertTrue(
            ProgramImportService.resultMessage(summary: added, replacedSplit: true)
                .contains("Your training split now matches this block")
        )
    }

    func test_splitSchedule_uniqueDaysInFileOrder_unionsLifts() {
        let start = Date(timeIntervalSince1970: 1_767_571_200)
        let document = runningThreeDayDocument(start: start)
        let schedule = ProgramImportService.splitSchedule(from: document)
        XCTAssertEqual(schedule.map(\.name), ["Lower", "Push", "Pull"])
        XCTAssertEqual(schedule[0].exercises.map(\.name), ["Conventional Deadlift", "Romanian Deadlift"])
        XCTAssertEqual(schedule[1].exercises.map(\.name), ["Barbell Bench Press"])
        XCTAssertEqual(schedule[2].exercises.map(\.name), ["Barbell Bent-Over Row"])
    }

    func test_weekCount_spansEightWeeks() {
        let start = Date(timeIntervalSince1970: 1_767_571_200) // 2026-01-05
        let dates = (0..<8).flatMap { week -> [Date] in
            let monday = start.addingTimeInterval(Double(week) * 7 * 86_400)
            return [monday, monday.addingTimeInterval(2 * 86_400), monday.addingTimeInterval(4 * 86_400)]
        }
        XCTAssertEqual(ProgramImportService.weekCount(from: dates), 8)
    }

    func test_warmupFlags_roundTripThroughCodec() throws {
        let document = sampleDocument(firstSession: Date(timeIntervalSince1970: 1_800_000_000))
        let data = try ProgramCodec.encode(document)
        let decoded = try ProgramCodec.decode(data)

        let sets = decoded.block.sessions[0].exercises[0].sets
        XCTAssertEqual(sets.map(\.resolvedWarmup), [true, true, false])
        XCTAssertEqual(decoded.format, ProgramFormat.formatName)
        XCTAssertEqual(decoded.schemaVersion, 1)
    }

    func test_codec_acceptsDateOnlyStrings() throws {
        let json = """
        {
          "format": "rocklog.program",
          "schemaVersion": 1,
          "exportedAt": "2026-08-30T00:00:00Z",
          "block": {
            "id": "00000000-0000-4000-8000-0000000000aa",
            "name": "Demo",
            "startDate": "2026-01-05",
            "sessions": [
              {
                "id": "00000000-0000-4000-8000-0000000000bb",
                "date": "2026-01-05",
                "dayType": "Push",
                "exercises": [
                  {
                    "id": "00000000-0000-4000-8000-0000000000cc",
                    "name": "Barbell Bench Press",
                    "sets": [
                      { "setNumber": 1, "weightLbs": 95, "reps": 8, "isWarmup": true }
                    ]
                  }
                ]
              }
            ]
          }
        }
        """
        let doc = try ProgramCodec.decode(Data(json.utf8))
        XCTAssertEqual(doc.block.sessions.count, 1)
        XCTAssertTrue(doc.block.sessions[0].exercises[0].sets[0].resolvedWarmup)
    }

    func test_incomingFile_routesProgramVersusBackup() throws {
        let program = try ProgramCodec.encode(sampleDocument(firstSession: .now))
        switch try IncomingRockLogFile.parse(program) {
        case .program: break
        case .backup: XCTFail("program file must not parse as a backup")
        }

        let coach = Data(#"{"format":"rocklog.coach.session","schemaVersion":1}"#.utf8)
        XCTAssertThrowsError(try IncomingRockLogFile.parse(coach))
    }

    func test_merge_doesNotDeleteExistingCompletedSession() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext

        let squat = Exercise(name: "Barbell Back Squat", dayType: .legs, muscleGroup: "Quads")
        let historyID = UUID()
        let history = WorkoutSession(dayType: .legs, date: Date(timeIntervalSince1970: 1_700_000_000))
        history.id = historyID
        history.isCompleted = true
        let record = ExerciseRecord(trainingMode: .highWeightLowReps)
        record.exercise = squat
        record.session = history
        let logged = SetRecord(setNumber: 1, weightLbs: 225, reps: 5, isWarmup: false)
        logged.exerciseRecord = record
        context.insert(squat)
        context.insert(history)
        context.insert(record)
        context.insert(logged)
        try context.save()

        let document = sampleDocument(firstSession: Date(timeIntervalSince1970: 1_800_000_000))
        _ = try ProgramImportService.importDocument(document, context: context)

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertTrue(sessions.contains { $0.id == historyID && $0.isCompleted })
        XCTAssertEqual(sessions.filter { $0.id == historyID }.count, 1)

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(exercises.filter { $0.name == "Barbell Back Squat" }.count, 1)
    }

    func test_import_matchesExistingExerciseByName_withoutDuplicating() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext

        let existingID = UUID()
        let bench = Exercise(name: "Barbell Bench Press", dayType: .push, muscleGroup: "Chest")
        bench.id = existingID
        bench.rotationTrack = RotationTrack.a.rawValue
        context.insert(bench)
        try context.save()

        let document = sampleDocument(firstSession: Date(timeIntervalSince1970: 1_800_000_000))
        let result = try ProgramImportService.importDocument(document, context: context)

        let benches = try context.fetch(FetchDescriptor<Exercise>())
            .filter { $0.name.caseInsensitiveCompare("Barbell Bench Press") == .orderedSame }
        XCTAssertEqual(benches.count, 1)
        XCTAssertEqual(benches.first?.id, existingID)
        XCTAssertEqual(benches.first?.track, .a)
        XCTAssertEqual(result.summary.createdExerciseCount, 1) // Demo Floor Press only
    }

    func test_staleAutoComplete_doesNotMarkPlannedSessionAsTrained() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!

        let document = sampleDocument(firstSession: yesterday)
        _ = try ProgramImportService.importDocument(document, context: context)

        let vm = WorkoutViewModel(
            modelContext: context,
            healthKitService: HealthKitWorkoutService()
        )
        vm.autoCompleteStaleSession()

        let plannedID = document.block.sessions[0].id
        let session = try context.fetch(FetchDescriptor<WorkoutSession>())
            .first { $0.id == plannedID }
        XCTAssertNotNil(session)
        XCTAssertFalse(session?.isCompleted ?? true)
        XCTAssertEqual(session?.planStatus, .planned)
        XCTAssertTrue(PlannedBlockQueue.isUnused(try XCTUnwrap(session)))

        let trained = try context.fetch(
            FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.isCompleted == true }
            )
        )
        XCTAssertFalse(trained.contains { $0.id == plannedID })
    }

    func test_startToday_loadsTodaysPlanTargetsIncludingWarmups() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        let today = Calendar.current.startOfDay(for: .now)

        let document = sampleDocument(firstSession: today)
        _ = try ProgramImportService.importDocument(document, context: context)

        let vm = WorkoutViewModel(
            modelContext: context,
            healthKitService: HealthKitWorkoutService()
        )
        XCTAssertNil(vm.activeSession, "planned days must not auto-start")

        vm.startSession(dayType: .push, rotationTrack: .a)

        let session = try XCTUnwrap(vm.activeSession)
        XCTAssertEqual(session.id, document.block.sessions[0].id)
        XCTAssertEqual(session.planStatus, .none)
        XCTAssertTrue(session.followsSessionRoster)
        XCTAssertFalse(session.isCompleted)
        XCTAssertEqual(SessionRosterLogic.names(in: session), ["Barbell Bench Press", "Demo Floor Press"])

        let bench = try XCTUnwrap(
            session.exerciseRecordsArray.first { $0.exercise?.name == "Barbell Bench Press" }
        )
        let flags = bench.setsArray.sorted { $0.setNumber < $1.setNumber }.map(\.isWarmup)
        XCTAssertEqual(flags, [true, true, false])
        XCTAssertEqual(bench.setsArray.first { $0.setNumber == 1 }?.weightLbs, 95)
        XCTAssertEqual(bench.setsArray.first { $0.setNumber == 3 }?.weightLbs, 155)
        XCTAssertTrue(bench.setsArray.allSatisfy(\.isTarget))
    }

    func test_startDifferentDayType_doesNotStealPlan() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        let today = Calendar.current.startOfDay(for: .now)

        let document = sampleDocument(firstSession: today)
        _ = try ProgramImportService.importDocument(document, context: context)

        let vm = WorkoutViewModel(
            modelContext: context,
            healthKitService: HealthKitWorkoutService()
        )
        vm.startSession(dayType: .legs, rotationTrack: .a)

        let live = try XCTUnwrap(vm.activeSession)
        XCTAssertEqual(live.day, .legs)
        XCTAssertNotEqual(live.id, document.block.sessions[0].id)
        XCTAssertTrue(live.exerciseRecordsArray.isEmpty)

        let planned = try XCTUnwrap(
            context.fetch(FetchDescriptor<WorkoutSession>())
                .first { $0.id == document.block.sessions[0].id }
        )
        XCTAssertTrue(planned.isPlanned)
        XCTAssertFalse(planned.isCompleted)
    }

    func test_import_sameDayTypeTwiceInOneWeek_keepsDifferentRosters() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        let monday = Date(timeIntervalSince1970: 1_767_571_200)
        let thursday = monday.addingTimeInterval(3 * 86_400)
        let document = rotatingLowerDocument(dlDate: monday, rdlDate: thursday)

        _ = try ProgramImportService.importDocument(document, context: context)

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
            .filter { $0.day == .lower }
            .sorted { $0.date < $1.date }
        XCTAssertEqual(sessions.count, 2)
        XCTAssertTrue(sessions.allSatisfy(\.followsSessionRoster))
        XCTAssertEqual(SessionRosterLogic.names(in: sessions[0]), ["Conventional Deadlift"])
        XCTAssertEqual(SessionRosterLogic.names(in: sessions[1]), ["Romanian Deadlift"])
        XCTAssertFalse(SessionRosterLogic.names(in: sessions[0]).contains("Romanian Deadlift"))
        XCTAssertFalse(SessionRosterLogic.names(in: sessions[1]).contains("Conventional Deadlift"))
    }

    func test_import_runningSplit_doesNotResetOrMergeByMonday() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 1_767_571_200)
        let document = runningThreeDayDocument(start: start)

        _ = try ProgramImportService.importDocument(document, context: context)

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
            .sorted { $0.date < $1.date }
        XCTAssertEqual(sessions.map(\.dayType), [
            "Lower", "Push", "Pull", "Lower",
            "Push", "Pull", "Lower", "Push",
        ])
        let lowers = sessions.filter { $0.day == .lower }
        XCTAssertEqual(lowers.count, 3)
        XCTAssertEqual(SessionRosterLogic.names(in: lowers[0]).first, "Conventional Deadlift")
        XCTAssertEqual(SessionRosterLogic.names(in: lowers[1]).first, "Romanian Deadlift")
        XCTAssertEqual(SessionRosterLogic.names(in: lowers[2]).first, "Conventional Deadlift")
    }

    func test_start_usesDatedRoster_notDayPlanUnion() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        let today = Calendar.current.startOfDay(for: .now)

        let conv = Exercise(name: "Conventional Deadlift", dayType: .lower, muscleGroup: "Hamstrings")
        let rdl = Exercise(name: "Romanian Deadlift", dayType: .lower, muscleGroup: "Hamstrings")
        context.insert(conv)
        context.insert(rdl)
        try context.save()

        let document = rotatingLowerDocument(dlDate: today, rdlDate: today.addingTimeInterval(3 * 86_400))
        _ = try ProgramImportService.importDocument(document, context: context)

        let vm = WorkoutViewModel(
            modelContext: context,
            healthKitService: HealthKitWorkoutService()
        )
        vm.startSession(dayType: .lower, rotationTrack: .a)

        let session = try XCTUnwrap(vm.activeSession)
        XCTAssertTrue(SessionRosterLogic.usesSessionRoster(session))
        XCTAssertEqual(SessionRosterLogic.names(in: session), ["Conventional Deadlift"])
        XCTAssertFalse(SessionRosterLogic.names(in: session).contains("Romanian Deadlift"))
        XCTAssertTrue(session.followsSessionRoster)
    }

    func test_startLower_usesFirstUnused_notLaterDatedLower() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        let today = Calendar.current.startOfDay(for: .now)
        let earlier = Calendar.current.date(byAdding: .day, value: -3, to: today)!

        let document = rotatingLowerDocument(dlDate: earlier, rdlDate: today)
        _ = try ProgramImportService.importDocument(document, context: context)

        let vm = WorkoutViewModel(
            modelContext: context,
            healthKitService: HealthKitWorkoutService()
        )
        vm.autoCompleteStaleSession(now: today)
        vm.startSession(dayType: .lower, rotationTrack: .a, now: today)

        let session = try XCTUnwrap(vm.activeSession)
        XCTAssertEqual(session.id, document.block.sessions[0].id)
        XCTAssertEqual(SessionRosterLogic.names(in: session), ["Conventional Deadlift"])
        XCTAssertFalse(SessionRosterLogic.names(in: session).contains("Romanian Deadlift"))
        XCTAssertTrue(Calendar.current.isDate(session.date, inSameDayAs: today))
    }

    func test_wednesdayStart_loadsFirstUnusedThenSecond_noFakeHistory() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 31))!
        let tuesday = calendar.date(byAdding: .day, value: 1, to: monday)!
        let wednesday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 16))!
        let thursday = calendar.date(byAdding: .day, value: 3, to: monday)!
        let document = threeSessionBlock(monday: monday, tuesday: tuesday, thursday: thursday)

        _ = try ProgramImportService.importDocument(document, context: context)

        let vm = WorkoutViewModel(
            modelContext: context,
            healthKitService: HealthKitWorkoutService()
        )
        vm.autoCompleteStaleSession(now: wednesday)

        let unusedBefore = PlannedBlockQueue.unusedSessions(
            in: try context.fetch(FetchDescriptor<WorkoutSession>())
        )
        XCTAssertEqual(unusedBefore.map(\.id), document.block.sessions.map(\.id))
        XCTAssertEqual(unusedBefore.map(\.dayType), ["Lower", "Push", "Pull"])
        XCTAssertTrue(unusedBefore.allSatisfy { $0.planStatus == .planned })

        vm.startSession(dayType: .lower, rotationTrack: .a, now: wednesday)
        let first = try XCTUnwrap(vm.activeSession)
        XCTAssertEqual(first.id, document.block.sessions[0].id)
        XCTAssertEqual(first.day, .lower)
        XCTAssertEqual(SessionRosterLogic.names(in: first), ["Conventional Deadlift"])
        XCTAssertTrue(calendar.isDate(first.date, inSameDayAs: wednesday))
        XCTAssertNotEqual(calendar.startOfDay(for: first.date), calendar.startOfDay(for: monday))

        first.isCompleted = true
        first.planStatus = .none
        try context.save()
        vm.dismissSummaryToToday()

        vm.startSession(dayType: .push, rotationTrack: .a, now: wednesday)
        let second = try XCTUnwrap(vm.activeSession)
        XCTAssertEqual(second.id, document.block.sessions[1].id)
        XCTAssertEqual(second.day, .push)
        XCTAssertEqual(SessionRosterLogic.names(in: second), ["Barbell Bench Press"])
        XCTAssertTrue(calendar.isDate(second.date, inSameDayAs: wednesday))

        let history = HistoryViewModel(modelContext: context)
        let all = try context.fetch(FetchDescriptor<WorkoutSession>())
        let grouped = history.groupedSessions(from: all)
        let historyIDs = grouped.flatMap { $0.1 }.map(\.id)
        XCTAssertEqual(historyIDs, [document.block.sessions[0].id])
        XCTAssertFalse(historyIDs.contains(document.block.sessions[1].id))
        XCTAssertFalse(historyIDs.contains(document.block.sessions[2].id))
        XCTAssertFalse(all.contains { $0.isCompleted && calendar.isDate($0.date, inSameDayAs: monday) })
        XCTAssertFalse(all.contains { $0.isCompleted && calendar.isDate($0.date, inSameDayAs: tuesday) })
        XCTAssertEqual(all.filter(\.isCompleted).count, 1)
    }

    func test_queue_followsFileOrder_notEarlierCalendarDate() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 31))!
        let thursday = calendar.date(byAdding: .day, value: 3, to: monday)!
        // File lists Conventional first even though its date is later.
        let document = rotatingLowerDocument(dlDate: thursday, rdlDate: monday)

        _ = try ProgramImportService.importDocument(document, context: context)

        let unused = PlannedBlockQueue.unusedSessions(
            in: try context.fetch(FetchDescriptor<WorkoutSession>())
        )
        XCTAssertEqual(unused.map(\.planOrder), [0, 1])
        XCTAssertEqual(SessionRosterLogic.names(in: unused[0]), ["Conventional Deadlift"])
        XCTAssertEqual(SessionRosterLogic.names(in: unused[1]), ["Romanian Deadlift"])

        let vm = WorkoutViewModel(
            modelContext: context,
            healthKitService: HealthKitWorkoutService()
        )
        vm.startSession(dayType: .lower, rotationTrack: .a, now: monday)
        XCTAssertEqual(SessionRosterLogic.names(in: try XCTUnwrap(vm.activeSession)), ["Conventional Deadlift"])
    }

    func test_legacySkippedSession_staysInQueue() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let document = sampleDocument(firstSession: yesterday)
        _ = try ProgramImportService.importDocument(document, context: context)

        let session = try XCTUnwrap(
            context.fetch(FetchDescriptor<WorkoutSession>())
                .first { $0.id == document.block.sessions[0].id }
        )
        session.planStatus = .skipped
        try context.save()

        let vm = WorkoutViewModel(
            modelContext: context,
            healthKitService: HealthKitWorkoutService()
        )
        vm.autoCompleteStaleSession()
        vm.startSession(dayType: .push, rotationTrack: .a)

        let live = try XCTUnwrap(vm.activeSession)
        XCTAssertEqual(live.id, document.block.sessions[0].id)
        XCTAssertEqual(live.planStatus, .none)
        XCTAssertFalse(live.isCompleted)
    }

    func test_import_keepsFileCalendarDatesByDefault() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 31))!
        let thursday = calendar.date(byAdding: .day, value: 3, to: monday)!
        let document = rotatingLowerDocument(dlDate: monday, rdlDate: thursday)

        _ = try ProgramImportService.importDocument(document, context: context)

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
            .sorted { $0.date < $1.date }
        XCTAssertEqual(sessions.count, 2)
        XCTAssertTrue(calendar.isDate(sessions[0].date, inSameDayAs: monday))
        XCTAssertTrue(calendar.isDate(sessions[1].date, inSameDayAs: thursday))
        XCTAssertEqual(sessions[0].day, .lower)
        XCTAssertEqual(SessionRosterLogic.names(in: sessions[0]), ["Conventional Deadlift"])
    }

    func test_import_shiftStartToToday_isOptIn() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 31))!
        let thursday = calendar.date(byAdding: .day, value: 3, to: monday)!
        let document = rotatingLowerDocument(dlDate: monday, rdlDate: thursday)
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))

        _ = try ProgramImportService.importDocument(
            document,
            context: context,
            shiftingStartTo: today
        )

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
            .sorted { $0.date < $1.date }
        XCTAssertTrue(calendar.isDate(sessions[0].date, inSameDayAs: today))
        let shiftedThursday = calendar.date(byAdding: .day, value: 3, to: today)!
        XCTAssertTrue(calendar.isDate(sessions[1].date, inSameDayAs: shiftedThursday))
        XCTAssertFalse(calendar.isDate(sessions[0].date, inSameDayAs: monday))
    }

    func test_import_withoutReplace_leavesExistingSplit() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        insertSplit(names: ["Arms", "Legs"], context: context)
        let curl = Exercise(name: "Barbell Curl", dayType: .arms, muscleGroup: "Biceps")
        context.insert(curl)
        try context.save()

        let document = sampleDocument(firstSession: Date(timeIntervalSince1970: 1_800_000_000))
        _ = try ProgramImportService.importDocument(document, context: context)

        let days = try context.fetch(
            FetchDescriptor<SplitDay>(sortBy: [SortDescriptor(\SplitDay.sortOrder)])
        )
        XCTAssertEqual(days.map(\.name), ["Arms", "Legs"])
        XCTAssertTrue(curl.belongs(to: .arms))
        let benches = try context.fetch(FetchDescriptor<Exercise>())
            .filter { $0.name == "Barbell Bench Press" }
        XCTAssertEqual(benches.count, 1)
        XCTAssertTrue(benches[0].isUnassigned)
    }

    func test_replaceSplit_replacesDaysAndLifts_keepsHistory() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        insertSplit(names: ["Arms", "Legs"], context: context)

        let curl = Exercise(name: "Barbell Curl", dayType: .arms, muscleGroup: "Biceps")
        let historyID = UUID()
        let history = WorkoutSession(dayType: .arms, date: Date(timeIntervalSince1970: 1_700_000_000))
        history.id = historyID
        history.isCompleted = true
        let record = ExerciseRecord(trainingMode: .highWeightLowReps)
        record.exercise = curl
        record.session = history
        let logged = SetRecord(setNumber: 1, weightLbs: 45, reps: 10, isWarmup: false)
        logged.exerciseRecord = record
        context.insert(curl)
        context.insert(history)
        context.insert(record)
        context.insert(logged)
        try context.save()

        let start = Date(timeIntervalSince1970: 1_767_571_200)
        let document = runningThreeDayDocument(start: start)
        _ = try ProgramImportService.importDocument(document, context: context)
        ProgramImportService.replaceSplit(from: document, context: context)

        let days = try context.fetch(
            FetchDescriptor<SplitDay>(sortBy: [SortDescriptor(\SplitDay.sortOrder)])
        )
        XCTAssertEqual(days.map(\.name), ["Lower", "Push", "Pull"])
        XCTAssertFalse(days.contains { $0.name == "Arms" || $0.name == "Legs" })

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let byName = Dictionary(uniqueKeysWithValues: exercises.map { ($0.name, $0) })
        XCTAssertTrue(byName["Conventional Deadlift"]?.belongs(to: .lower) == true)
        XCTAssertTrue(byName["Romanian Deadlift"]?.belongs(to: .lower) == true)
        XCTAssertTrue(byName["Barbell Bench Press"]?.belongs(to: .push) == true)
        XCTAssertTrue(byName["Barbell Bent-Over Row"]?.belongs(to: .pull) == true)
        XCTAssertTrue(curl.isUnassigned)
        XCTAssertFalse(curl.belongs(to: .arms))

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertTrue(sessions.contains { $0.id == historyID && $0.isCompleted })
        XCTAssertEqual(sessions.filter { $0.id == historyID }.count, 1)
        XCTAssertGreaterThan(sessions.filter { $0.planStatus == .planned }.count, 0)
    }

    func test_allowsDeletingDay_keepsLastHome_allowsCatchAll() {
        XCTAssertFalse(DayTypeRegistry.allowsDeletingDay(includesAllExercises: false, homeDayCount: 1))
        XCTAssertTrue(DayTypeRegistry.allowsDeletingDay(includesAllExercises: false, homeDayCount: 2))
        XCTAssertTrue(DayTypeRegistry.allowsDeletingDay(includesAllExercises: true, homeDayCount: 1))
        XCTAssertTrue(DayTypeRegistry.allowsDeletingDay(includesAllExercises: true, homeDayCount: 0))
    }

    func test_delete_refusesLastHomeDay() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        insertSplit(names: ["Push"], context: context)
        try context.save()
        DayTypeRegistry.shared.reload(context: context)

        let days = try context.fetch(FetchDescriptor<SplitDay>())
        XCTAssertEqual(days.count, 1)
        let id = days[0].id
        XCTAssertFalse(DayTypeRegistry.shared.canDelete(id: id, from: days))

        DayTypeRegistry.shared.delete(id: id, context: context)
        let remaining = try context.fetch(FetchDescriptor<SplitDay>())
        XCTAssertEqual(remaining.map(\.name), ["Push"])
    }

    func test_replaceSplit_fromImportedSessions_matchesFile() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        insertSplit(names: ["Arms"], context: context)
        let start = Date(timeIntervalSince1970: 1_767_571_200)
        let document = runningThreeDayDocument(start: start)
        _ = try ProgramImportService.importDocument(document, context: context)

        let planned = try context.fetch(FetchDescriptor<WorkoutSession>())
            .filter { $0.planStatus == .planned }
        XCTAssertFalse(planned.isEmpty)
        ProgramImportService.replaceSplit(fromSessions: planned, context: context)

        let days = try context.fetch(
            FetchDescriptor<SplitDay>(sortBy: [SortDescriptor(\SplitDay.sortOrder)])
        )
        XCTAssertEqual(days.map(\.name), ["Lower", "Push", "Pull"])
    }

    // MARK: - Helpers

    private func insertSplit(names: [String], context: ModelContext) {
        for (index, name) in names.enumerated() {
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
    }

    private func sampleDocument(firstSession: Date) -> ProgramDocument {
        let benchID = UUID()
        let floorID = UUID()
        let sessionID = UUID()
        return ProgramDocument(
            format: ProgramFormat.formatName,
            schemaVersion: ProgramFormat.schemaVersion,
            exportedAt: Date(timeIntervalSince1970: 1_775_000_000),
            block: ProgramBlockPayload(
                id: UUID(),
                name: "Demo Strength Block",
                notes: "Synthetic fixture — fake lifts only.",
                startDate: firstSession,
                sessions: [
                    ProgramSessionPayload(
                        id: sessionID,
                        date: firstSession,
                        dayType: "Push",
                        rotationTrack: "A",
                        notes: nil,
                        exercises: [
                            ProgramExercisePayload(
                                id: benchID,
                                name: "Barbell Bench Press",
                                muscleGroup: "Chest, Triceps, Shoulders",
                                trainingMode: "Strength",
                                notes: nil,
                                sets: [
                                    ProgramSetPayload(setNumber: 1, weightLbs: 95, reps: 8, isWarmup: true, isEachSide: false, isAssisted: false),
                                    ProgramSetPayload(setNumber: 2, weightLbs: 135, reps: 5, isWarmup: true, isEachSide: false, isAssisted: false),
                                    ProgramSetPayload(setNumber: 3, weightLbs: 155, reps: 5, isWarmup: false, isEachSide: false, isAssisted: false),
                                ]
                            ),
                            ProgramExercisePayload(
                                id: floorID,
                                name: "Demo Floor Press",
                                muscleGroup: "Chest, Triceps",
                                trainingMode: "Strength",
                                notes: nil,
                                sets: [
                                    ProgramSetPayload(setNumber: 1, weightLbs: 95, reps: 8, isWarmup: true, isEachSide: false, isAssisted: false),
                                    ProgramSetPayload(setNumber: 2, weightLbs: 115, reps: 8, isWarmup: false, isEachSide: false, isAssisted: false),
                                ]
                            ),
                        ]
                    )
                ]
            )
        )
    }

    private func threeSessionBlock(monday: Date, tuesday: Date, thursday: Date) -> ProgramDocument {
        ProgramDocument(
            format: ProgramFormat.formatName,
            schemaVersion: ProgramFormat.schemaVersion,
            exportedAt: Date(timeIntervalSince1970: 1_775_000_000),
            block: ProgramBlockPayload(
                id: UUID(),
                name: "Demo Travel Week",
                notes: "Synthetic fixture — fake lifts only.",
                startDate: monday,
                sessions: [
                    hingeSession(id: UUID(), date: monday, name: "Conventional Deadlift"),
                    ProgramSessionPayload(
                        id: UUID(),
                        date: tuesday,
                        dayType: "Push",
                        rotationTrack: "A",
                        notes: nil,
                        exercises: [
                            ProgramExercisePayload(
                                id: UUID(),
                                name: "Barbell Bench Press",
                                muscleGroup: "Chest",
                                trainingMode: "Strength",
                                notes: nil,
                                sets: [
                                    ProgramSetPayload(setNumber: 1, weightLbs: 135, reps: 5, isWarmup: true, isEachSide: false, isAssisted: false),
                                    ProgramSetPayload(setNumber: 2, weightLbs: 185, reps: 5, isWarmup: false, isEachSide: false, isAssisted: false),
                                ]
                            )
                        ]
                    ),
                    ProgramSessionPayload(
                        id: UUID(),
                        date: thursday,
                        dayType: "Pull",
                        rotationTrack: "A",
                        notes: nil,
                        exercises: [
                            ProgramExercisePayload(
                                id: UUID(),
                                name: "Barbell Bent-Over Row",
                                muscleGroup: "Back",
                                trainingMode: "Strength",
                                notes: nil,
                                sets: [
                                    ProgramSetPayload(setNumber: 1, weightLbs: 135, reps: 8, isWarmup: false, isEachSide: false, isAssisted: false),
                                ]
                            )
                        ]
                    ),
                ]
            )
        )
    }

    private func rotatingLowerDocument(dlDate: Date, rdlDate: Date) -> ProgramDocument {
        ProgramDocument(
            format: ProgramFormat.formatName,
            schemaVersion: ProgramFormat.schemaVersion,
            exportedAt: Date(timeIntervalSince1970: 1_775_000_000),
            block: ProgramBlockPayload(
                id: UUID(),
                name: "Demo Running Split",
                notes: "Two Lower days: Conventional then Romanian.",
                startDate: dlDate,
                sessions: [
                    hingeSession(id: UUID(), date: dlDate, name: "Conventional Deadlift"),
                    hingeSession(id: UUID(), date: rdlDate, name: "Romanian Deadlift"),
                ]
            )
        )
    }

    private func runningThreeDayDocument(start: Date) -> ProgramDocument {
        let cycle = ["Lower", "Push", "Pull"]
        let offsets = [0, 1, 3, 4, 7, 8, 10, 11]
        var lowerCount = 0
        let sessions: [ProgramSessionPayload] = offsets.enumerated().map { index, dayOffset in
            let date = start.addingTimeInterval(TimeInterval(dayOffset) * 86_400)
            let day = cycle[index % 3]
            if day == "Lower" {
                let name = lowerCount.isMultiple(of: 2) ? "Conventional Deadlift" : "Romanian Deadlift"
                lowerCount += 1
                return hingeSession(id: UUID(), date: date, name: name, dayType: "Lower")
            }
            return ProgramSessionPayload(
                id: UUID(),
                date: date,
                dayType: day,
                rotationTrack: nil,
                notes: nil,
                exercises: [
                    ProgramExercisePayload(
                        id: UUID(),
                        name: day == "Push" ? "Barbell Bench Press" : "Barbell Bent-Over Row",
                        muscleGroup: day == "Push" ? "Chest" : "Back",
                        trainingMode: "Strength",
                        notes: nil,
                        sets: [
                            ProgramSetPayload(setNumber: 1, weightLbs: 135, reps: 5, isWarmup: false, isEachSide: false, isAssisted: false),
                        ]
                    )
                ]
            )
        }
        return ProgramDocument(
            format: ProgramFormat.formatName,
            schemaVersion: ProgramFormat.schemaVersion,
            exportedAt: Date(timeIntervalSince1970: 1_775_000_000),
            block: ProgramBlockPayload(
                id: UUID(),
                name: "Demo Running 3-Day",
                notes: nil,
                startDate: start,
                sessions: sessions
            )
        )
    }

    private func hingeSession(
        id: UUID,
        date: Date,
        name: String,
        dayType: String = "Lower"
    ) -> ProgramSessionPayload {
        ProgramSessionPayload(
            id: id,
            date: date,
            dayType: dayType,
            rotationTrack: nil,
            notes: nil,
            exercises: [
                ProgramExercisePayload(
                    id: UUID(),
                    name: name,
                    muscleGroup: "Hamstrings, Glutes, Lower Back",
                    trainingMode: "Strength",
                    notes: nil,
                    sets: [
                        ProgramSetPayload(setNumber: 1, weightLbs: 135, reps: 5, isWarmup: true, isEachSide: false, isAssisted: false),
                        ProgramSetPayload(setNumber: 2, weightLbs: 225, reps: 5, isWarmup: false, isEachSide: false, isAssisted: false),
                    ]
                )
            ]
        )
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
            TrainingBlock.self,
            configurations: config
        )
    }
}
