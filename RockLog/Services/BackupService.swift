//
//  BackupService.swift
//  RockLog
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
    case invalidBackup(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let v):
            return "Backup version \(v) is not supported by this version of the app."
        case .invalidBackup(let message):
            return message
        }
    }
}

/// What restore kept and what it refused to insert.
struct BackupRestoreReport: Equatable {
    var droppedExerciseRecords: Int
    var unknownTrainingModes: [String]
    var unknownKeyCount: Int = 0
    var unknownEnumCount: Int = 0
    var orphanedGroupIDs: [UUID] = []

    var userFacingSummary: String {
        var sentences: [String] = []
        if droppedExerciseRecords > 0 {
            let noun = droppedExerciseRecords == 1 ? "exercise log" : "exercise logs"
            let modes = unknownTrainingModes.joined(separator: ", ")
            let modePhrase = unknownTrainingModes.count == 1
                ? "an unknown training mode (\(modes))"
                : "unknown training modes (\(modes))"
            sentences.append("Skipped \(droppedExerciseRecords) \(noun) with \(modePhrase).")
        }
        if unknownKeyCount > 0 || unknownEnumCount > 0 {
            sentences.append("Left out \(unknownKeyCount) unknown fields and \(unknownEnumCount) unknown values.")
        }
        if !orphanedGroupIDs.isEmpty {
            let noun = orphanedGroupIDs.count == 1 ? "group" : "groups"
            sentences.append("Cleared \(orphanedGroupIDs.count) \(noun) that no longer had two lifts.")
        }
        if sentences.isEmpty { return "Backup restored successfully." }
        return "Backup restored. " + sentences.joined(separator: " ")
    }
}

struct OpenedBackup {
    var backup: AppBackup
    var inspection: BackupInspection
}

struct BackupService {
    static let currentVersion = BackupMigration.currentVersion
    static let minimumVersion = BackupMigration.minimumVersion
    /// Heavier than any bar a person can load. Rejects corrupted or hand-edited values such as 1e9.
    static let maximumWeightLbs = 10_000.0
    /// Pounds or inches. Same ceiling as weight; a real measurement is far below it.
    static let maximumMeasurement = 10_000.0

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

        let exerciseBackups = exercises
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            .map { e in
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
                daySortOrdersRaw: e.daySortOrdersRaw,
                defaultRestSeconds: e.defaultRestSeconds,
                autoRestEnabled: e.autoRestEnabled,
                loadModeRaw: e.loadModeRaw.isEmpty ? nil : e.loadModeRaw,
                suggestWarmupRamp: e.suggestWarmupRamp ? true : nil
            )
        }

        let sessionBackups = sessions
            .sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date < rhs.date }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            .map { s in
            WorkoutSessionBackup(
                id: s.id,
                date: s.date,
                dayType: s.dayType,
                notes: s.notes,
                isCompleted: s.isCompleted,
                exerciseRecords: s.exerciseRecordsArray
                    .sorted { lhs, rhs in
                        if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                        return lhs.id.uuidString < rhs.id.uuidString
                    }
                    .map { r in
                        ExerciseRecordBackup(
                            id: r.id,
                            exerciseID: r.exercise?.id,
                            trainingMode: r.trainingMode.rawValue,
                            sortOrder: r.sortOrder,
                            isCompleted: r.isCompleted,
                            notes: r.notes,
                            sets: r.setsArray
                                .sorted { lhs, rhs in
                                    if lhs.setNumber != rhs.setNumber { return lhs.setNumber < rhs.setNumber }
                                    return lhs.id.uuidString < rhs.id.uuidString
                                }
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
                                        isTarget: s.isTarget,
                                        offeredWeightLbs: s.offeredWeightLbs,
                                        loadModeRaw: s.loadModeRaw.isEmpty ? nil : s.loadModeRaw,
                                        bodyWeightUsedLbs: s.bodyWeightUsedLbs > 0 ? s.bodyWeightUsedLbs : nil,
                                        plannedRestSeconds: s.plannedRestSeconds > 0 ? s.plannedRestSeconds : nil,
                                        actualRestSeconds: s.actualRestSeconds > 0 ? s.actualRestSeconds : nil
                                    )
                                },
                            groupID: r.groupID,
                            groupPosition: r.groupPosition > 0 ? r.groupPosition : nil
                        )
                    },
                rotationTrack: s.rotationTrack,
                durationSeconds: s.durationSeconds > 0 ? s.durationSeconds : nil,
                planState: s.planState.isEmpty ? nil : s.planState,
                followsSessionRoster: s.followsSessionRoster ? true : nil,
                planOrder: s.planOrder,
                gymID: s.gymID,
                gymName: s.gymName.isEmpty ? nil : s.gymName
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

        let blocks = try context.fetch(FetchDescriptor<TrainingBlock>())
        let blockBackups = blocks.map { block in
            let sessionIDs = block.sessionsArray.sorted { lhs, rhs in
                if lhs.planOrder != rhs.planOrder { return lhs.planOrder < rhs.planOrder }
                if lhs.date != rhs.date { return lhs.date < rhs.date }
                return lhs.id.uuidString < rhs.id.uuidString
            }.map(\.id)
            return TrainingBlockBackup(
                id: block.id,
                name: block.name,
                notes: block.notes,
                startDate: block.startDate,
                importedAt: block.importedAt,
                sessionIDs: sessionIDs
            )
        }.sorted { lhs, rhs in
            if lhs.startDate != rhs.startDate { return lhs.startDate < rhs.startDate }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        let metrics = try context.fetch(FetchDescriptor<BodyMetricEntry>())
        let metricBackups = metrics.map { entry in
            BodyMetricBackup(
                id: entry.id,
                date: entry.date,
                kindRaw: entry.kindRaw,
                value: entry.value,
                note: entry.note
            )
        }.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            if lhs.kindRaw != rhs.kindRaw { return lhs.kindRaw < rhs.kindRaw }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        let gymBackups: [GymBackup]? = context.container.schema.entities.contains { $0.name == "Gym" }
            ? ((try? context.fetch(FetchDescriptor<Gym>())) ?? []).map { gym in
            GymBackup(
                id: gym.id,
                name: gym.name,
                isHome: gym.isHome,
                createdAt: gym.createdAt,
                sortOrder: gym.sortOrder,
                latitude: gym.latitude,
                longitude: gym.longitude,
                radiusMeters: gym.radiusMeters
            )
        }.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.id.uuidString < rhs.id.uuidString
        }
            : nil

        let profileBackups: [StackProfileBackup]? = context.container.schema.entities.contains { $0.name == "MachineStackProfile" }
            ? ((try? context.fetch(FetchDescriptor<MachineStackProfile>())) ?? []).map { profile in
            StackProfileBackup(
                id: profile.id,
                gymID: profile.gymID,
                exerciseID: profile.exerciseID,
                stepPounds: profile.stepPounds,
                offsetPounds: profile.offsetPounds == 0 ? nil : profile.offsetPounds,
                pinsRaw: profile.pinsRaw,
                pinUnitRaw: profile.pinUnitRaw,
                addOnsRaw: profile.addOnsRaw,
                policyRaw: profile.policyRaw,
                originRaw: profile.originRaw,
                learnedSessionIDsRaw: profile.learnedSessionIDsRaw,
                clearedAt: profile.clearedAt,
                learningEnabled: profile.learningEnabled,
                rangeMin: profile.rangeMin,
                rangeMax: profile.rangeMax,
                updatedAt: profile.updatedAt
            )
        }.sorted { $0.id.uuidString < $1.id.uuidString }
            : nil

        let backup = AppBackup(
            version: currentVersion,
            exportedAt: .now,
            exercises: exerciseBackups,
            sessions: sessionBackups,
            splitDays: splitBackups,
            dayPlans: SeedData.captureDayPlans(from: exercises, splitDays: splitDays),
            trainingBlocks: blockBackups,
            bodyMetrics: metricBackups,
            gyms: gymBackups,
            stackProfiles: profileBackups
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let payload = try encoder.encode(backup)
        let object = try InterchangeCodec.parseObject(payload)
        let stamp = ISO8601DateFormatter().string(from: backup.exportedAt)
        let envelope = InterchangeCodec.wrap(kind: .backup, payload: object, exportedAt: stamp)
        return try InterchangeCodec.encode(envelope)
    }

    // MARK: - Preview / confirm

    static func decode(_ data: Data) throws -> AppBackup {
        try open(data).backup
    }

    /// Decode, promote v1 to v2, and count keys and enum values this build will not apply.
    static func open(_ data: Data) throws -> OpenedBackup {
        let legacy = try legacyBackupData(data)
        let raw = try InterchangeCodec.parseObject(legacy)
        let promoted: [String: JSONValue]
        do {
            promoted = try BackupMigration.promoteToCurrent(raw)
        } catch let error as BackupMigrationError {
            switch error {
            case .unsupportedVersion(let version):
                throw BackupError.unsupportedVersion(version)
            case .malformed:
                throw BackupError.invalidBackup("This backup could not be read. Nothing was changed.")
            }
        }
        let inspection = BackupInspection.inspect(promoted)
        let payload = try InterchangeCodec.encode(promoted)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(AppBackup.self, from: payload)
        guard backup.version >= minimumVersion, backup.version <= currentVersion else {
            throw BackupError.unsupportedVersion(backup.version)
        }
        try validate(backup)
        return OpenedBackup(backup: backup, inspection: inspection)
    }

    /// Interchange files unwrap to the backup payload. Older backups pass through.
    static func legacyBackupData(_ data: Data) throws -> Data {
        guard InterchangeCodec.isInterchange(data) else { return data }
        guard try InterchangeCodec.kind(of: data) == .backup else {
            throw BackupError.invalidBackup("This interchange file is not a backup.")
        }
        let issues = InterchangeCodec.validate(try InterchangeCodec.toLatest(data))
        if let weight = issues.first(where: { $0.path.contains("weight") || $0.path.contains("Weight") }) {
            throw BackupError.invalidBackup(weight.message + " Restore was cancelled and nothing was changed.")
        }
        return try InterchangeCodec.downgradeToLegacy(data)
    }

    /// Reject values that would corrupt the store. Unknown training modes are
    /// not rejected here; restore skips them and reports the count.
    static func validate(_ backup: AppBackup) throws {
        try rejectDuplicateIDs(backup.exercises.map(\.id), noun: "exercise")
        try rejectDuplicateIDs(backup.sessions.map(\.id), noun: "workout")
        if let blocks = backup.trainingBlocks {
            try rejectDuplicateIDs(blocks.map(\.id), noun: "training block")
        }
        if let days = backup.splitDays {
            try rejectDuplicateIDs(days.map(\.id), noun: "split day")
        }
        if let gyms = backup.gyms {
            try rejectDuplicateIDs(gyms.map(\.id), noun: "gym")
        }
        if let profiles = backup.stackProfiles {
            try rejectDuplicateIDs(profiles.map(\.id), noun: "stack profile")
        }
        if let metrics = backup.bodyMetrics {
            try rejectDuplicateIDs(metrics.map(\.id), noun: "body measurement")
            for metric in metrics {
                // test_b5: rejecting an unknown kind, with "nothing was changed",
                // is intended. Skipping the row would apply the rest of the file
                // and leave the user's data partly restored.
                guard BodyMetricKind(rawValue: metric.kindRaw) != nil else {
                    throw BackupError.invalidBackup(
                        "Body measurement \(metric.id.uuidString) has unknown kind \(metric.kindRaw). Restore was cancelled and nothing was changed."
                    )
                }
                if !metric.value.isFinite || metric.value < 0 || metric.value > maximumMeasurement {
                    throw BackupError.invalidBackup(
                        "Body measurement \(metric.id.uuidString) has value \(metric.value). Value must be a finite number from 0 through \(Int(maximumMeasurement)). Restore was cancelled and nothing was changed."
                    )
                }
            }
        }

        var recordIDs: [UUID] = []
        var setIDs: [UUID] = []
        for session in backup.sessions {
            for record in session.exerciseRecords {
                recordIDs.append(record.id)
                for set in record.sets {
                    setIDs.append(set.id)
                    if set.reps < 0 {
                        throw BackupError.invalidBackup(
                            "Set \(set.id.uuidString) has reps \(set.reps). Reps must be zero or greater. Restore was cancelled and nothing was changed."
                        )
                    }
                    if !set.weightLbs.isFinite || set.weightLbs < 0 || set.weightLbs > maximumWeightLbs {
                        throw BackupError.invalidBackup(
                            "Set \(set.id.uuidString) has weight \(set.weightLbs) lb. Weight must be a finite number from 0 through \(Int(maximumWeightLbs)) lb. Restore was cancelled and nothing was changed."
                        )
                    }
                }
            }
        }
        try rejectDuplicateIDs(recordIDs, noun: "exercise log")
        try rejectDuplicateIDs(setIDs, noun: "set")
    }

    private static func rejectDuplicateIDs(_ ids: [UUID], noun: String) throws {
        var seen = Set<UUID>()
        for id in ids where !seen.insert(id).inserted {
            throw BackupError.invalidBackup(
                "Backup contains more than one \(noun) with id \(id.uuidString). Restore was cancelled and nothing was changed."
            )
        }
    }

    static func summarize(backup: AppBackup, inspection: BackupInspection = .empty) -> BackupSummary {
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
        let dropped = Self.unknownTrainingModes(in: backup)
        return BackupSummary(
            splitDayNames: splitNames,
            assignedExerciseCount: assigned,
            exerciseCount: backup.exercises.count,
            sessionCount: backup.sessions.count,
            droppedExerciseRecordCount: dropped.count,
            unknownTrainingModes: dropped.modes,
            unknownKeyCount: inspection.unknownKeyCount,
            unknownKeyPaths: inspection.unknownKeyPaths,
            unknownEnumCount: inspection.unknownEnumCount,
            unknownEnums: inspection.unknownEnums
        )
    }

    /// Exercise logs this build will skip, in file order. The mode list is distinct.
    static func unknownTrainingModes(in backup: AppBackup) -> (count: Int, modes: [String]) {
        var count = 0
        var modes: [String] = []
        var seen = Set<String>()
        for session in backup.sessions {
            for record in session.exerciseRecords {
                guard TrainingMode(rawValue: record.trainingMode) == nil else { continue }
                count += 1
                if seen.insert(record.trainingMode).inserted {
                    modes.append(record.trainingMode)
                }
            }
        }
        return (count, modes)
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
                message: dropWarning(appendedTo: """
                There is currently a split with exercises in this app (\(current.splitPhrase)). \
                Restore will replace that split, the lifts on those days, and your workout history \
                with this backup (\(incoming.splitPhrase)). This cannot be undone.
                """, incoming: incoming),
                confirmTitle: "Replace split and exercises",
                cancelTitle: "Don't restore"
            )
        }
        if current.sessionCount > 0 || current.assignedExerciseCount > 0 {
            return RestorePrompt(
                title: "Restore backup?",
                message: dropWarning(appendedTo: """
                This will replace the workout data on this phone with this backup \
                (\(incoming.splitPhrase)). This cannot be undone.
                """, incoming: incoming),
                confirmTitle: "Replace all data",
                cancelTitle: "Don't restore"
            )
        }
        return RestorePrompt(
            title: "Restore backup?",
            message: dropWarning(
                appendedTo: "Load this backup onto this phone (\(incoming.splitPhrase))? It becomes your split, exercises, and workout history.",
                incoming: incoming
            ),
            confirmTitle: "Restore",
            cancelTitle: "Don't restore"
        )
    }

    private static func dropWarning(appendedTo message: String, incoming: BackupSummary) -> String {
        var extra = ""
        if incoming.droppedExerciseRecordCount > 0 {
            let count = incoming.droppedExerciseRecordCount
            let noun = count == 1 ? "exercise log" : "exercise logs"
            let verb = count == 1 ? "uses" : "use"
            let modes = incoming.unknownTrainingModes.joined(separator: ", ")
            let modePhrase = incoming.unknownTrainingModes.count == 1
                ? "an unknown training mode (\(modes))"
                : "unknown training modes (\(modes))"
            extra += " \(count) \(noun) \(verb) \(modePhrase) and will be skipped."
        }
        if incoming.unknownKeyCount > 0 || incoming.unknownEnumCount > 0 {
            extra += " \(incoming.unknownKeyCount) unknown fields and \(incoming.unknownEnumCount) unknown values will be reported and not applied."
            if !incoming.unknownKeyPaths.isEmpty {
                extra += " Fields: \(incoming.unknownKeyPaths.joined(separator: ", "))."
            }
            if !incoming.unknownEnums.isEmpty {
                extra += " Values: \(incoming.unknownEnums.joined(separator: ", "))."
            }
        }
        return message + extra
    }

    // MARK: - Restore

    /// Tear down live workout UI, then replace the store.
    @MainActor
    @discardableResult
    static func restoreAfterTearingDownUI(from data: Data, context: ModelContext) async throws -> BackupRestoreReport {
        NotificationCenter.default.post(name: .rockLogStoreWillReplace, object: nil)
        // Two turns so SwiftUI can unmount TabView / FocusView before deletes.
        await Task.yield()
        try await Task.sleep(for: .milliseconds(200))
        return try restore(from: data, context: context)
    }

    /// Replace the store with `data`.
    ///
    /// Deletes, inserts, split days, and day plans are one unsaved transaction.
    /// `context.save()` runs once at the end. A thrown save (or the test
    /// `persisting` hook) rolls the context back, so a failure leaves the
    /// previous rows in place. UserDefaults mirrors are written only after
    /// that save commits.
    ///
    /// - Parameter persisting: Replaces `context.save()` for tests that need
    ///   the write to fail. Production passes nil.
    @MainActor
    @discardableResult
    static func restore(
        from data: Data,
        context: ModelContext,
        persisting: ((ModelContext) throws -> Void)? = nil
    ) throws -> BackupRestoreReport {
        let opened = try open(data)
        let backup = opened.backup
        let previousAutosave = context.autosaveEnabled
        context.autosaveEnabled = false
        defer { context.autosaveEnabled = previousAutosave }

        let report: BackupRestoreReport
        do {
            report = try writeBackup(backup, inspection: opened.inspection, into: context)
            if let persisting {
                try persisting(context)
            } else {
                try context.save()
            }
        } catch {
            context.rollback()
            throw error
        }

        commitRestorePreferences(from: backup, context: context)
        // Reload on this call — a detached Task outlives test containers
        // and the CloudKit store tear-down, then fetchCount traps (SIGTRAP).
        // Do not seed. writeBackup already applied the file's split, including
        // an explicit empty list. Seeding from a leftover preset or snapshot
        // would add days the next export would not have had.
        DayTypeRegistry.shared.reload(context: context, seedIfEmpty: false)
        NotificationCenter.default.post(name: .rockLogStoreReplaced, object: nil)
        return report
    }

    /// Mutate `context` to match `backup` without saving.
    /// Fetch-and-delete each instance so SwiftData runs relationship
    /// nullification. `context.delete(model:)` would skip that and leave
    /// inverses pointing at deleted rows.
    @MainActor
    private static func writeBackup(
        _ backup: AppBackup,
        inspection: BackupInspection,
        into context: ModelContext
    ) throws -> BackupRestoreReport {
        for set in try context.fetch(FetchDescriptor<SetRecord>()) {
            context.delete(set)
        }
        for record in try context.fetch(FetchDescriptor<ExerciseRecord>()) {
            context.delete(record)
        }
        for session in try context.fetch(FetchDescriptor<WorkoutSession>()) {
            context.delete(session)
        }
        for exercise in try context.fetch(FetchDescriptor<Exercise>()) {
            context.delete(exercise)
        }
        for day in try context.fetch(FetchDescriptor<SplitDay>()) {
            context.delete(day)
        }

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
            exercise.defaultRestSeconds = eb.defaultRestSeconds ?? 0
            if let autoRest = eb.autoRestEnabled {
                exercise.autoRestEnabled = autoRest
                exercise.autoRestCopied = true
            } else {
                // Same unsaved transaction as the rest of the restore. A failed
                // save rolls this back. A second call does not copy again.
                RestPreferenceMigration.copyIfNeeded(exercise)
            }
            exercise.loadModeRaw = eb.loadModeRaw ?? ""
            exercise.suggestWarmupRamp = eb.suggestWarmupRamp ?? false
            context.insert(exercise)
            exerciseMap[eb.id] = exercise
        }

        var sessionMap: [UUID: WorkoutSession] = [:]
        var droppedExerciseRecords = 0
        var unknownModes: [String] = []
        var seenModes = Set<String>()
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
            session.gymID = sb.gymID
            session.gymName = sb.gymName ?? ""
            if let duration = sb.durationSeconds, duration > 0 {
                session.durationSeconds = duration
            }
            context.insert(session)
            sessionMap[session.id] = session

            for rb in sb.exerciseRecords {
                guard let trainingMode = TrainingMode(rawValue: rb.trainingMode) else {
                    droppedExerciseRecords += 1
                    if seenModes.insert(rb.trainingMode).inserted {
                        unknownModes.append(rb.trainingMode)
                    }
                    continue
                }
                let record = ExerciseRecord(trainingMode: trainingMode, sortOrder: rb.sortOrder)
                record.id = rb.id
                record.isCompleted = rb.isCompleted
                record.notes = rb.notes
                record.groupID = rb.groupID
                record.groupPosition = rb.groupPosition ?? 0
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
                    set.offeredWeightLbs = setb.offeredWeightLbs
                    set.loadModeRaw = setb.loadModeRaw ?? ""
                    set.bodyWeightUsedLbs = setb.bodyWeightUsedLbs ?? 0
                    set.plannedRestSeconds = setb.plannedRestSeconds ?? 0
                    set.actualRestSeconds = setb.actualRestSeconds ?? 0
                    set.exerciseRecord = record
                    if record.sets == nil { record.sets = [] }
                    record.sets?.append(set)
                    context.insert(set)
                }
            }
        }

        // Nil leaves existing programs in place (the file predates the field).
        // An array, including empty, replaces them.
        if backup.trainingBlocks != nil {
            for block in try context.fetch(FetchDescriptor<TrainingBlock>()) {
                context.delete(block)
            }
        }
        for snapshot in backup.trainingBlocks ?? [] {
            let block = TrainingBlock(
                name: snapshot.name,
                startDate: snapshot.startDate,
                notes: snapshot.notes
            )
            block.id = snapshot.id
            block.importedAt = snapshot.importedAt
            block.sessions = []
            context.insert(block)
            for sessionID in snapshot.sessionIDs {
                sessionMap[sessionID]?.trainingBlock = block
            }
        }

        // Nil preserves measurements the file never contained. An array replaces them.
        if backup.bodyMetrics != nil {
            for entry in try context.fetch(FetchDescriptor<BodyMetricEntry>()) {
                context.delete(entry)
            }
        }
        if backup.gyms != nil, context.container.schema.entities.contains(where: { $0.name == "Gym" }) {
            for gym in try context.fetch(FetchDescriptor<Gym>()) {
                context.delete(gym)
            }
        }
        if context.container.schema.entities.contains(where: { $0.name == "Gym" }) {
            for snapshot in backup.gyms ?? [] {
                let gym = Gym(name: snapshot.name, isHome: snapshot.isHome, sortOrder: snapshot.sortOrder)
                gym.id = snapshot.id
                gym.createdAt = snapshot.createdAt
                gym.latitude = snapshot.latitude
                gym.longitude = snapshot.longitude
                gym.radiusMeters = snapshot.radiusMeters
                context.insert(gym)
            }
        }

        if backup.stackProfiles != nil, context.container.schema.entities.contains(where: { $0.name == "MachineStackProfile" }) {
            for profile in try context.fetch(FetchDescriptor<MachineStackProfile>()) {
                context.delete(profile)
            }
        }
        if context.container.schema.entities.contains(where: { $0.name == "MachineStackProfile" }) {
        for snapshot in backup.stackProfiles ?? [] {
            let profile = MachineStackProfile(gymID: snapshot.gymID, exerciseID: snapshot.exerciseID)
            profile.id = snapshot.id
            profile.stepPounds = snapshot.stepPounds
            profile.offsetPounds = snapshot.offsetPounds ?? 0
            profile.pinsRaw = snapshot.pinsRaw
            profile.pinUnitRaw = snapshot.pinUnitRaw
            profile.addOnsRaw = snapshot.addOnsRaw
            profile.policyRaw = snapshot.policyRaw
            profile.originRaw = snapshot.originRaw
            profile.learnedSessionIDsRaw = snapshot.learnedSessionIDsRaw
            profile.clearedAt = snapshot.clearedAt
            profile.learningEnabled = snapshot.learningEnabled
            profile.rangeMin = snapshot.rangeMin
            profile.rangeMax = snapshot.rangeMax
            profile.updatedAt = snapshot.updatedAt
            context.insert(profile)
        }
        }

        for snapshot in backup.bodyMetrics ?? [] {
            guard let kind = BodyMetricKind(rawValue: snapshot.kindRaw) else { continue }
            let entry = BodyMetricEntry(
                kind: kind,
                value: snapshot.value,
                date: snapshot.date,
                note: snapshot.note
            )
            entry.id = snapshot.id
            entry.kindRaw = snapshot.kindRaw
            context.insert(entry)
        }

        // Renames, split days, and day-plan membership stay unsaved so they
        // commit with the rows above or roll back with them.
        SeedData.migrateExerciseNames(context: context, saves: false)
        restoreSplitDays(from: backup, context: context, saves: false)
        SeedData.restoreDayPlans(from: backup, context: context, saves: false)
        let orphans = dissolveOrphanedGroups(in: context)
        return BackupRestoreReport(
            droppedExerciseRecords: droppedExerciseRecords,
            unknownTrainingModes: unknownModes,
            unknownKeyCount: inspection.unknownKeyCount,
            unknownEnumCount: inspection.unknownEnumCount,
            orphanedGroupIDs: orphans
        )
    }

    /// A group id left with fewer than two lifts is cleared. The ids are reported.
    @MainActor
    private static func dissolveOrphanedGroups(in context: ModelContext) -> [UUID] {
        let records = (try? context.fetch(FetchDescriptor<ExerciseRecord>())) ?? []
        var counts: [UUID: Int] = [:]
        for record in records {
            guard let group = record.groupID else { continue }
            counts[group, default: 0] += 1
        }
        let orphans = counts.filter { $0.value < 2 }.map(\.key).sorted { $0.uuidString < $1.uuidString }
        guard !orphans.isEmpty else { return [] }
        let orphanSet = Set(orphans)
        for record in records where record.groupID.map(orphanSet.contains) == true {
            record.groupID = nil
            record.groupPosition = 0
        }
        return orphans
    }

    /// UserDefaults / iCloud KVS mirrors. Called only after the store save commits.
    @MainActor
    private static func commitRestorePreferences(from backup: AppBackup, context: ModelContext) {
        if let plans = backup.dayPlans, !plans.isEmpty {
            SeedData.storeDayPlanSnapshot(plans)
        } else {
            SeedData.persistDayPlanSnapshot(context: context)
        }
        SeedData.markCatalogSeeded()
        SeedData.markDayPlansTrusted()
        SeedData.markSplitConfigured(context: context)
    }

    /// Prefer the stored split. Older backups only have session/exercise names —
    /// rebuild from session days (not catalog home days, which add unused Arms / Full Body).
    private static func restoreSplitDays(from backup: AppBackup, context: ModelContext, saves: Bool) {
        if let stored = backup.splitDays {
            // An empty list is a v2 file that has no days. Do not invent a split.
            guard !stored.isEmpty else { return }
            _ = SeedData.applySplitSnapshot(stored, context: context, saves: saves)
            return
        }
        let inferred = inferSplit(from: backup)
        guard !inferred.isEmpty else {
            SeedData.seedSplitDaysIfNeeded(context: context, saves: saves)
            return
        }
        _ = SeedData.applySplitSnapshot(inferred, context: context, saves: saves)
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
