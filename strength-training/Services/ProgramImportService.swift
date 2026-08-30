//
//  ProgramImportService.swift
//  strength-training
//
//  Merge a rocklog.program file into the live store. Never deletes history
//  or the library. Split stays unless the user taps Use this split.
//  Exercise match: UUID, then name.
//

import Foundation
import SwiftData

struct ProgramImportSummary: Equatable {
    var blockName: String
    var sessionCount: Int
    var weekCount: Int
    var createdExerciseCount: Int
    var skippedDuplicateSessionCount: Int

    var confirmationPrompt: RestorePrompt {
        RestorePrompt(
            title: "Add planned workouts?",
            message: ProgramImportService.confirmationMessage(weekCount: weekCount),
            confirmTitle: "Add workouts",
            cancelTitle: "Don't add"
        )
    }
}

struct ProgramImportResult: Equatable {
    var blockID: UUID
    var summary: ProgramImportSummary
}

struct ProgramSplitDayPlan: Equatable {
    var name: String
    var exercises: [ProgramSplitExercise]
}

struct ProgramSplitExercise: Equatable {
    var id: UUID
    var name: String
}

enum ProgramImportService {
    /// Explicit opt-in. Default import keeps file dates as metadata; the
    /// unused queue still rolls to the first unstarted session.
    static let startThisBlockTodayTitle = "Start this block today"
    static let useThisSplitTitle = "Use this as your training split?"
    static let useThisSplitConfirmTitle = "Use this split"
    static let keepCurrentSplitTitle = "Keep my current split"

    /// Human copy for the Files / share-sheet confirm. No jargon.
    static func confirmationMessage(weekCount: Int) -> String {
        let weeks = max(1, weekCount)
        let weekWord = weeks == 1 ? "week" : "weeks"
        return "Add \(weeks) \(weekWord) of planned workouts? This does not replace your history. The next unused workout waits until you start it."
    }

    static func replaceSplitMessage() -> String {
        "This replaces your current days and the lifts on each day with this block. Your old workouts stay in History."
    }

    static func replaceSplitPrompt() -> RestorePrompt {
        RestorePrompt(
            title: useThisSplitTitle,
            message: replaceSplitMessage(),
            confirmTitle: useThisSplitConfirmTitle,
            cancelTitle: keepCurrentSplitTitle
        )
    }

    static func resultMessage(summary: ProgramImportSummary, replacedSplit: Bool) -> String {
        if summary.sessionCount == 0 {
            return replacedSplit
                ? "Those planned workouts are already on this phone. Your training split now matches this block."
                : "Those planned workouts are already on this phone."
        }
        let weeks = max(1, summary.weekCount)
        let weekWord = weeks == 1 ? "week" : "weeks"
        if replacedSplit {
            return "Added \(weeks) \(weekWord) of planned workouts. Your training split now matches this block. History is unchanged."
        }
        return "Added \(weeks) \(weekWord) of planned workouts. Your history is unchanged."
    }

    /// Unique days in file order, each with first-seen lifts (id, then name).
    static func splitSchedule(from document: ProgramDocument) -> [ProgramSplitDayPlan] {
        var days: [ProgramSplitDayPlan] = []
        var indexByKey: [String: Int] = [:]
        for session in document.block.sessions {
            let name = session.dayType.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, name.caseInsensitiveCompare("Unassigned") != .orderedSame else {
                continue
            }
            let key = name.lowercased()
            if indexByKey[key] == nil {
                indexByKey[key] = days.count
                days.append(ProgramSplitDayPlan(name: name, exercises: []))
            }
            guard let dayIndex = indexByKey[key] else { continue }
            var seenIDs = Set(days[dayIndex].exercises.map(\.id))
            var seenNames = Set(days[dayIndex].exercises.map { nameKey($0.name) })
            for exercise in session.exercises {
                let trimmed = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                let keyName = nameKey(trimmed)
                if seenIDs.contains(exercise.id) || seenNames.contains(keyName) { continue }
                seenIDs.insert(exercise.id)
                seenNames.insert(keyName)
                days[dayIndex].exercises.append(
                    ProgramSplitExercise(id: exercise.id, name: trimmed)
                )
            }
        }
        return days
    }

    /// Replace the live split (days + which lifts sit on each day). History,
    /// the library, and planned sessions stay. Call after a successful import
    /// so exercise IDs/names already match the store.
    @MainActor
    static func replaceSplit(from document: ProgramDocument, context: ModelContext) {
        let schedule = splitSchedule(from: document)
        guard !schedule.isEmpty else { return }

        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        var byID: [UUID: Exercise] = [:]
        var byName: [String: Exercise] = [:]
        for exercise in exercises {
            byID[exercise.id] = exercise
            let key = nameKey(exercise.name)
            if byName[key] == nil {
                byName[key] = exercise
            }
        }

        var plans: [DayPlanBackup] = []
        for day in schedule {
            var ids: [UUID] = []
            var seen = Set<UUID>()
            for item in day.exercises {
                let resolved = byID[item.id] ?? byName[nameKey(item.name)]
                guard let exercise = resolved, seen.insert(exercise.id).inserted else { continue }
                ids.append(exercise.id)
            }
            plans.append(DayPlanBackup(dayName: day.name, exerciseIDs: ids))
        }

        DayTypeRegistry.shared.replaceDays(names: schedule.map(\.name), context: context)
        _ = SeedData.applyDayPlanSnapshot(plans, context: context, replaceAllMembership: true)
        SeedData.storeDayPlanSnapshot(plans)
        SeedData.persistUserPlan(context: context)
        DayTypeRegistry.shared.reload(context: context)
    }

    static func weekCount(from dates: [Date], calendar: Calendar = .current) -> Int {
        guard let first = dates.min(), let last = dates.max() else { return 0 }
        let start = calendar.startOfDay(for: first)
        let end = calendar.startOfDay(for: last)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(1, Int(ceil(Double(days + 1) / 7.0)))
    }

    static func summarize(_ document: ProgramDocument) -> ProgramImportSummary {
        ProgramImportSummary(
            blockName: document.block.name,
            sessionCount: document.block.sessions.count,
            weekCount: weekCount(from: document.block.sessions.map(\.date)),
            createdExerciseCount: 0,
            skippedDuplicateSessionCount: 0
        )
    }

    /// Opt-in only. Shift every session so the block’s first day lands on `anchor`.
    static func anchoredSessions(
        in document: ProgramDocument,
        to anchor: Date,
        calendar: Calendar = .current
    ) -> [ProgramSessionPayload] {
        let sourceDates = document.block.sessions.map(\.date) + [document.block.startDate]
        guard let earliest = sourceDates.min() else { return document.block.sessions }
        let from = calendar.startOfDay(for: earliest)
        let to = calendar.startOfDay(for: anchor)
        let dayShift = calendar.dateComponents([.day], from: from, to: to).day ?? 0
        guard dayShift != 0 else { return document.block.sessions }
        return document.block.sessions.map { session in
            var copy = session
            copy.date = calendar.date(byAdding: .day, value: dayShift, to: session.date) ?? session.date
            return copy
        }
    }

    /// Merge the file’s sessions. Dates stay as written unless `shiftingStartTo` is set.
    @MainActor
    static func importDocument(
        _ document: ProgramDocument,
        context: ModelContext,
        shiftingStartTo anchor: Date? = nil
    ) throws -> ProgramImportResult {
        let sessions: [ProgramSessionPayload]
        if let anchor {
            sessions = anchoredSessions(in: document, to: anchor)
        } else {
            sessions = document.block.sessions
        }
        guard !sessions.isEmpty else {
            throw ProgramDocument.ProgramFormatError.emptyBlock
        }

        let existingSessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        var existingIDs = Set(existingSessions.map(\.id))

        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        var byID: [UUID: Exercise] = [:]
        var byName: [String: Exercise] = [:]
        for exercise in exercises {
            byID[exercise.id] = exercise
            let key = Self.nameKey(exercise.name)
            if byName[key] == nil {
                byName[key] = exercise
            }
        }

        let startDate = Calendar.current.startOfDay(
            for: sessions.map(\.date).min() ?? document.block.startDate
        )
        let block = TrainingBlock(
            name: document.block.name,
            startDate: startDate,
            notes: document.block.notes ?? ""
        )
        block.id = document.block.id
        context.insert(block)

        var createdExercises = 0
        var imported = 0
        var skipped = 0

        // File order is the queue. Same dayType twice in a week stays two sessions.
        for (index, payload) in sessions.enumerated() {
            if existingIDs.contains(payload.id) {
                skipped += 1
                continue
            }

            let dayType = DayType(rawValue: payload.dayType)
            let session = WorkoutSession(
                dayType: dayType,
                date: payload.date,
                rotationTrack: RotationTrack(storage: payload.rotationTrack)
            )
            session.id = payload.id
            session.notes = payload.notes ?? ""
            session.isCompleted = false
            session.planStatus = .planned
            session.planOrder = index
            session.followsSessionRoster = true
            session.trainingBlock = block
            context.insert(session)
            if block.sessions == nil { block.sessions = [] }
            block.sessions?.append(session)

            for (index, exercisePayload) in payload.exercises.enumerated() {
                let resolved = resolveExercise(
                    payload: exercisePayload,
                    byID: &byID,
                    byName: &byName,
                    context: context
                )
                if resolved.created { createdExercises += 1 }

                let mode = TrainingMode(rawValue: exercisePayload.trainingMode ?? "")
                    ?? .highWeightLowReps
                let record = ExerciseRecord(trainingMode: mode, sortOrder: index)
                record.exercise = resolved.exercise
                record.session = session
                record.notes = exercisePayload.notes ?? ""
                context.insert(record)
                if session.exerciseRecords == nil { session.exerciseRecords = [] }
                session.exerciseRecords?.append(record)

                for setPayload in exercisePayload.sets.sorted(by: { $0.setNumber < $1.setNumber }) {
                    let set = SetRecord(
                        setNumber: setPayload.setNumber,
                        weightLbs: setPayload.weightLbs,
                        reps: max(0, setPayload.reps),
                        isWarmup: setPayload.resolvedWarmup,
                        isEachSide: setPayload.resolvedEachSide,
                        isAssisted: setPayload.resolvedAssisted,
                        isTarget: true
                    )
                    set.completedAt = payload.date
                    set.exerciseRecord = record
                    context.insert(set)
                    if record.sets == nil { record.sets = [] }
                    record.sets?.append(set)
                }
            }

            existingIDs.insert(payload.id)
            imported += 1
        }

        if imported == 0 {
            context.delete(block)
        }
        try context.save()

        let summary = ProgramImportSummary(
            blockName: document.block.name,
            sessionCount: imported,
            weekCount: weekCount(from: sessions.map(\.date)),
            createdExerciseCount: createdExercises,
            skippedDuplicateSessionCount: skipped
        )
        return ProgramImportResult(blockID: block.id, summary: summary)
    }

    private static func nameKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func resolveExercise(
        payload: ProgramExercisePayload,
        byID: inout [UUID: Exercise],
        byName: inout [String: Exercise],
        context: ModelContext
    ) -> (exercise: Exercise, created: Bool) {
        if let existing = byID[payload.id] {
            return (existing, false)
        }
        let key = nameKey(payload.name)
        if let existing = byName[key] {
            byID[payload.id] = existing
            return (existing, false)
        }

        let exercise = Exercise(
            name: payload.name,
            dayType: nil,
            muscleGroup: payload.muscleGroup ?? "",
            isCustom: true
        )
        exercise.id = payload.id
        context.insert(exercise)
        byID[payload.id] = exercise
        byName[key] = exercise
        return (exercise, true)
    }
}
