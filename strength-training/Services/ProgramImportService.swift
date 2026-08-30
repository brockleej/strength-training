//
//  ProgramImportService.swift
//  strength-training
//
//  Merge a rocklog.program file into the live store. Never deletes history,
//  the library, or the split. Exercise match: UUID, then name.
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

enum ProgramImportService {
    /// Explicit opt-in. Default import keeps file dates as metadata; the
    /// unused queue still rolls to the first unstarted session.
    static let startThisBlockTodayTitle = "Start this block today"

    /// Human copy for the Files / share-sheet confirm. No jargon.
    static func confirmationMessage(weekCount: Int) -> String {
        let weeks = max(1, weekCount)
        let weekWord = weeks == 1 ? "week" : "weeks"
        return "Add \(weeks) \(weekWord) of planned workouts? This does not replace your history. The next unused workout waits until you start it."
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
