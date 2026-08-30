//
//  BackupService.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftData
import Foundation

extension Notification.Name {
    /// Posted on the main actor *before* restore deletes SwiftData rows.
    /// Drop session refs and tear down ExerciseListView first or the next
    /// frame reads zombie records (TF 13 SIGTRAP).
    static let rockLogStoreWillReplace = Notification.Name("rockLogStoreWillReplace")
    /// Posted on the main actor after restore wipes and reloads the SwiftData store.
    static let rockLogStoreReplaced = Notification.Name("rockLogStoreReplaced")
}

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
        let splitDays = (try? context.fetch(
            FetchDescriptor<SplitDay>(sortBy: [
                SortDescriptor(\SplitDay.sortOrder),
                SortDescriptor(\SplitDay.name),
            ])
        )) ?? []

        let exerciseBackups = exercises.map { e in
            ExerciseBackup(
                id: e.id,
                name: e.name,
                dayType: e.dayType,
                muscleGroup: e.muscleGroup,
                sortOrder: e.sortOrder,
                isCustom: e.isCustom,
                notes: e.notes,
                rotationTrack: e.rotationTrack,
                extraDayTypes: e.extraDayTypes,
                daySortOrdersRaw: e.daySortOrdersRaw
            )
        }

        let sessionBackups = sessions.map { s in
            WorkoutSessionBackup(
                id: s.id,
                date: s.date,
                dayType: s.dayType,
                notes: s.notes,
                isCompleted: s.isCompleted,
                exerciseRecords: s.exerciseRecordsArray
                    .sorted { $0.sortOrder < $1.sortOrder }
                    .map { r in
                        ExerciseRecordBackup(
                            id: r.id,
                            exerciseID: r.exercise?.id,
                            trainingMode: r.trainingMode.rawValue,
                            sortOrder: r.sortOrder,
                            isCompleted: r.isCompleted,
                            notes: r.notes,
                            sets: r.setsArray
                                .sorted { $0.setNumber < $1.setNumber }
                                .map { s in
                                    SetRecordBackup(
                                        id: s.id,
                                        setNumber: s.setNumber,
                                        weightLbs: s.weightLbs,
                                        reps: s.reps,
                                        isWarmup: s.isWarmup,
                                        isEachSide: s.isEachSide,
                                        isAssisted: s.isAssisted,
                                        completedAt: s.completedAt,
                                        isTarget: s.isTarget
                                    )
                                }
                        )
                    },
                rotationTrack: s.rotationTrack,
                durationSeconds: s.durationSeconds > 0 ? s.durationSeconds : nil,
                planState: s.planState.isEmpty ? nil : s.planState,
                followsSessionRoster: s.followsSessionRoster ? true : nil,
                planOrder: s.planOrder
            )
        }

        let splitBackups = splitDays.enumerated().map { index, day in
            SplitDayBackup(
                id: day.id,
                name: day.name,
                systemImage: day.systemImage,
                subtitle: day.subtitle,
                colorHex: day.colorHex,
                includesAllExercises: day.includesAllExercises,
                sortOrder: index
            )
        }

        let backup = AppBackup(
            version: currentVersion,
            exportedAt: .now,
            exercises: exerciseBackups,
            sessions: sessionBackups,
            splitDays: splitBackups,
            dayPlans: SeedData.captureDayPlans(from: exercises, splitDays: splitDays)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    // MARK: - Preview / confirm

    static func decode(_ data: Data) throws -> AppBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(AppBackup.self, from: data)
        guard backup.version <= currentVersion else {
            throw BackupError.unsupportedVersion(backup.version)
        }
        return backup
    }

    static func summarize(backup: AppBackup) -> BackupSummary {
        let splitNames: [String]
        if let stored = backup.splitDays, !stored.isEmpty {
            splitNames = stored.sorted { $0.sortOrder < $1.sortOrder }.map(\.name)
        } else {
            splitNames = inferSplit(from: backup).map(\.name)
        }
        let assigned = backup.exercises.filter { exercise in
            let primary = exercise.dayType.trimmingCharacters(in: .whitespacesAndNewlines)
            let extras = (exercise.extraDayTypes ?? "")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return !primary.isEmpty || !extras.isEmpty
        }.count
        return BackupSummary(
            splitDayNames: splitNames,
            assignedExerciseCount: assigned,
            exerciseCount: backup.exercises.count,
            sessionCount: backup.sessions.count
        )
    }

    static func summarizeStore(context: ModelContext) -> BackupSummary {
        let splitDays = (try? context.fetch(
            FetchDescriptor<SplitDay>(sortBy: [
                SortDescriptor(\SplitDay.sortOrder),
                SortDescriptor(\SplitDay.name),
            ])
        )) ?? []
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        let assigned = exercises.filter { !$0.isUnassigned }.count
        return BackupSummary(
            splitDayNames: splitDays.map(\.name),
            assignedExerciseCount: assigned,
            exerciseCount: exercises.count,
            sessionCount: sessions.count
        )
    }

    static func restorePrompt(current: BackupSummary, incoming: BackupSummary) -> RestorePrompt {
        if current.hasSplitWithExercises {
            return RestorePrompt(
                title: "Replace current split?",
                message: """
                There is currently a split with exercises in this app (\(current.splitPhrase)). \
                Restore will replace that split, the lifts on those days, and your workout history \
                with this backup (\(incoming.splitPhrase)). This cannot be undone.
                """,
                confirmTitle: "Replace split and exercises",
                cancelTitle: "Don't restore"
            )
        }
        if current.sessionCount > 0 || current.assignedExerciseCount > 0 {
            return RestorePrompt(
                title: "Restore backup?",
                message: """
                This will replace the workout data on this phone with this backup \
                (\(incoming.splitPhrase)). This cannot be undone.
                """,
                confirmTitle: "Replace all data",
                cancelTitle: "Don't restore"
            )
        }
        return RestorePrompt(
            title: "Restore backup?",
            message: "Load this backup onto this phone (\(incoming.splitPhrase))? It becomes your split, exercises, and workout history.",
            confirmTitle: "Restore",
            cancelTitle: "Don't restore"
        )
    }

    // MARK: - Restore

    /// Tear down live workout UI, then replace the store.
    @MainActor
    static func restoreAfterTearingDownUI(from data: Data, context: ModelContext) async throws {
        NotificationCenter.default.post(name: .rockLogStoreWillReplace, object: nil)
        // Two turns so SwiftUI can unmount TabView / FocusView before deletes.
        await Task.yield()
        try await Task.sleep(for: .milliseconds(200))
        try restore(from: data, context: context)
    }

    @MainActor
    static func restore(from data: Data, context: ModelContext) throws {
        let backup = try decode(data)

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
        let splitDays = (try? context.fetch(FetchDescriptor<SplitDay>())) ?? []
        splitDays.forEach { context.delete($0) }
        let blocks = (try? context.fetch(FetchDescriptor<TrainingBlock>())) ?? []
        blocks.forEach { context.delete($0) }

        // Re-insert exercises, building an ID → Exercise map for linking records
        var exerciseMap: [UUID: Exercise] = [:]
        for eb in backup.exercises {
            let dayType = DayType(rawValue: eb.dayType)
            let exercise = Exercise(
                name: eb.name,
                dayType: dayType,
                muscleGroup: eb.muscleGroup,
                sortOrder: eb.sortOrder,
                isCustom: eb.isCustom,
                rotationTrack: RotationTrack(storage: eb.rotationTrack)
            )
            exercise.id = eb.id
            exercise.notes = eb.notes
            exercise.extraDayTypes = eb.extraDayTypes ?? ""
            exercise.daySortOrdersRaw = eb.daySortOrdersRaw ?? ""
            context.insert(exercise)
            exerciseMap[eb.id] = exercise
        }

        // Re-insert sessions → exercise records → sets
        for sb in backup.sessions {
            let dayType = DayType(rawValue: sb.dayType)
            let session = WorkoutSession(
                dayType: dayType,
                date: sb.date,
                rotationTrack: RotationTrack(storage: sb.rotationTrack ?? RotationTrack.a.rawValue)
            )
            session.id = sb.id
            session.notes = sb.notes
            session.isCompleted = sb.isCompleted
            session.planState = sb.planState ?? ""
            session.followsSessionRoster = sb.followsSessionRoster ?? false
            session.planOrder = sb.planOrder ?? 0
            if let duration = sb.durationSeconds, duration > 0 {
                session.durationSeconds = duration
            }
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
                if session.exerciseRecords == nil { session.exerciseRecords = [] }
                session.exerciseRecords?.append(record)
                context.insert(record)

                for setb in rb.sets {
                    let set = SetRecord(
                        setNumber: setb.setNumber,
                        weightLbs: setb.weightLbs,
                        reps: setb.reps,
                        isWarmup: setb.isWarmup,
                        isEachSide: setb.resolvedEachSide,
                        isAssisted: setb.resolvedAssisted,
                        isTarget: setb.resolvedTarget
                    )
                    set.id = setb.id
                    set.completedAt = setb.completedAt
                    set.exerciseRecord = record
                    if record.sets == nil { record.sets = [] }
                    record.sets?.append(set)
                    context.insert(set)
                }
            }
        }

        try context.save()

        // Old backups may still contain pre-rename exercise names —
        // re-apply the idempotent migration so restored data is corrected immediately.
        SeedData.migrateExerciseNames(context: context)

        restoreSplitDays(from: backup, context: context)
        SeedData.restoreDayPlans(from: backup, context: context)
        SeedData.markCatalogSeeded()
        SeedData.markDayPlansTrusted()
        SeedData.markSplitConfigured(context: context)
        // Reload on this call — a detached Task outlives test containers
        // and the CloudKit store tear-down, then fetchCount traps (SIGTRAP).
        DayTypeRegistry.shared.reload(context: context)
        NotificationCenter.default.post(name: .rockLogStoreReplaced, object: nil)
    }

    /// Prefer the stored split. Older backups only have session/exercise names —
    /// rebuild from session days (not catalog home days, which add unused Arms / Full Body).
    private static func restoreSplitDays(from backup: AppBackup, context: ModelContext) {
        if let stored = backup.splitDays, !stored.isEmpty {
            _ = SeedData.applySplitSnapshot(stored, context: context)
            return
        }
        let inferred = inferSplit(from: backup)
        guard !inferred.isEmpty else {
            SeedData.seedSplitDaysIfNeeded(context: context)
            return
        }
        _ = SeedData.applySplitSnapshot(inferred, context: context)
    }

    static func inferSplit(from backup: AppBackup) -> [SplitDayBackup] {
        var seen = Set<String>()
        var names: [String] = []
        for session in backup.sessions.sorted(by: { $0.date < $1.date }) {
            let name = session.dayType.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, seen.insert(name.lowercased()).inserted else { continue }
            names.append(name)
        }
        guard !names.isEmpty else { return [] }

        let used = Set(names.map { $0.lowercased() })
        let preset = matchingPreset(for: used)
            ?? SplitPreset(rawValue: UserDefaults.standard.string(forKey: SeedData.preferredSplitPresetKey) ?? "")
        if let preset {
            let ordered = preset.definitions.map(\.name).filter { used.contains($0.lowercased()) }
            let extras = names.filter { name in
                !preset.definitions.contains { $0.name.lowercased() == name.lowercased() }
            }
            names = ordered + extras
        }

        return names.enumerated().map { index, name in
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
    }

    private static func matchingPreset(for used: Set<String>) -> SplitPreset? {
        SplitPreset.allCases.first { preset in
            Set(preset.definitions.map { $0.name.lowercased() }) == used
        }
    }
}
