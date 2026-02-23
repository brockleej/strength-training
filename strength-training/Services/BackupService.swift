//
//  BackupService.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftData
import Foundation

enum BackupError: LocalizedError {
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let v):
            return "Backup version \(v) is not supported by this version of the app."
        }
    }
}

struct BackupService {
    static let currentVersion = 1

    // MARK: - Export

    static func export(context: ModelContext) throws -> Data {
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\Exercise.sortOrder)]))) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\WorkoutSession.date)]))) ?? []

        let exerciseBackups = exercises.map { e in
            ExerciseBackup(
                id: e.id,
                name: e.name,
                dayType: e.dayType.rawValue,
                muscleGroup: e.muscleGroup,
                sortOrder: e.sortOrder,
                isCustom: e.isCustom,
                notes: e.notes
            )
        }

        let sessionBackups = sessions.map { s in
            WorkoutSessionBackup(
                id: s.id,
                date: s.date,
                dayType: s.dayType.rawValue,
                notes: s.notes,
                isCompleted: s.isCompleted,
                exerciseRecords: s.exerciseRecords
                    .sorted { $0.sortOrder < $1.sortOrder }
                    .map { r in
                        ExerciseRecordBackup(
                            id: r.id,
                            exerciseID: r.exercise?.id,
                            trainingMode: r.trainingMode.rawValue,
                            sortOrder: r.sortOrder,
                            isCompleted: r.isCompleted,
                            notes: r.notes,
                            sets: r.sets
                                .sorted { $0.setNumber < $1.setNumber }
                                .map { s in
                                    SetRecordBackup(
                                        id: s.id,
                                        setNumber: s.setNumber,
                                        weightLbs: s.weightLbs,
                                        reps: s.reps,
                                        isWarmup: s.isWarmup,
                                        completedAt: s.completedAt
                                    )
                                }
                        )
                    }
            )
        }

        let backup = AppBackup(
            version: currentVersion,
            exportedAt: .now,
            exercises: exerciseBackups,
            sessions: sessionBackups
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    // MARK: - Restore

    static func restore(from data: Data, context: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(AppBackup.self, from: data)

        guard backup.version <= currentVersion else {
            throw BackupError.unsupportedVersion(backup.version)
        }

        // context.delete(model:) is a SQL-level batch delete that bypasses the
        // object graph — cascade rules and inverse nullification never fire.
        // Fetching and deleting each instance individually lets SwiftData
        // process relationships correctly before saving.
        let sets = (try? context.fetch(FetchDescriptor<SetRecord>())) ?? []
        sets.forEach { context.delete($0) }
        let records = (try? context.fetch(FetchDescriptor<ExerciseRecord>())) ?? []
        records.forEach { context.delete($0) }
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        sessions.forEach { context.delete($0) }
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        exercises.forEach { context.delete($0) }

        // Re-insert exercises, building an ID → Exercise map for linking records
        var exerciseMap: [UUID: Exercise] = [:]
        for eb in backup.exercises {
            guard let dayType = DayType(rawValue: eb.dayType) else { continue }
            let exercise = Exercise(
                name: eb.name,
                dayType: dayType,
                muscleGroup: eb.muscleGroup,
                sortOrder: eb.sortOrder,
                isCustom: eb.isCustom
            )
            exercise.id = eb.id
            exercise.notes = eb.notes
            context.insert(exercise)
            exerciseMap[eb.id] = exercise
        }

        // Re-insert sessions → exercise records → sets
        for sb in backup.sessions {
            guard let dayType = DayType(rawValue: sb.dayType) else { continue }
            let session = WorkoutSession(dayType: dayType, date: sb.date)
            session.id = sb.id
            session.notes = sb.notes
            session.isCompleted = sb.isCompleted
            context.insert(session)

            for rb in sb.exerciseRecords {
                guard let trainingMode = TrainingMode(rawValue: rb.trainingMode) else { continue }
                let record = ExerciseRecord(trainingMode: trainingMode, sortOrder: rb.sortOrder)
                record.id = rb.id
                record.isCompleted = rb.isCompleted
                record.notes = rb.notes
                record.session = session
                if let exerciseID = rb.exerciseID {
                    record.exercise = exerciseMap[exerciseID]
                }
                session.exerciseRecords.append(record)
                context.insert(record)

                for setb in rb.sets {
                    let set = SetRecord(
                        setNumber: setb.setNumber,
                        weightLbs: setb.weightLbs,
                        reps: setb.reps,
                        isWarmup: setb.isWarmup
                    )
                    set.id = setb.id
                    set.completedAt = setb.completedAt
                    set.exerciseRecord = record
                    record.sets.append(set)
                    context.insert(set)
                }
            }
        }

        try context.save()
    }
}
