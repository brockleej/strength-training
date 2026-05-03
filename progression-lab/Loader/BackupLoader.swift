//
//  BackupLoader.swift
//  ProgressionLab
//

import Foundation

enum BackupLoaderError: LocalizedError {
    case fileReadFailed(URL, underlying: Error)
    case decodeFailed(URL, underlying: Error)
    case unsupportedVersion(found: Int, supported: Int)

    var errorDescription: String? {
        switch self {
        case .fileReadFailed(let url, let err):
            return "Couldn't read \(url.lastPathComponent): \(err.localizedDescription)"
        case .decodeFailed(let url, let err):
            return "Couldn't decode \(url.lastPathComponent): \(err.localizedDescription)"
        case .unsupportedVersion(let found, let supported):
            return "Backup file is version \(found); this build understands up to version \(supported). Update ProgressionLab."
        }
    }
}

struct BackupLoader {

    /// Backup schema versions this build can parse. Bump in lockstep with
    /// `BackupService.currentVersion` in the iOS app.
    static let supportedBackupVersion = 1

    /// Load and parse a backup JSON at the given URL. The URL must already be
    /// readable (the caller is responsible for security-scoped resource access).
    static func load(from url: URL) throws -> LoadedDataset {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw BackupLoaderError.fileReadFailed(url, underlying: error)
        }

        let backup: AppBackup
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            backup = try decoder.decode(AppBackup.self, from: data)
        } catch {
            throw BackupLoaderError.decodeFailed(url, underlying: error)
        }

        guard backup.version <= supportedBackupVersion else {
            throw BackupLoaderError.unsupportedVersion(
                found: backup.version,
                supported: supportedBackupVersion
            )
        }

        return adapt(backup: backup, sourceURL: url)
    }

    /// Build a `LoadedDataset` from a decoded `AppBackup`. Public for tests.
    static func adapt(backup: AppBackup, sourceURL: URL) -> LoadedDataset {
        let exerciseByID = Dictionary(uniqueKeysWithValues: backup.exercises.map { ($0.id, $0) })

        var skipCounts: [LoadedDatasetSummary.SkipReason: Int] = [:]
        var snapshotsByExerciseID: [UUID: [ExerciseRecordSnapshot]] = [:]
        var totalSessions = 0
        var dateMin: Date?
        var dateMax: Date?

        for session in backup.sessions {
            dateMin = dateMin.map { min($0, session.date) } ?? session.date
            dateMax = dateMax.map { max($0, session.date) } ?? session.date

            guard session.isCompleted else {
                skipCounts[.incompleteSession, default: 0] += session.exerciseRecords.count
                continue
            }
            totalSessions += 1

            for record in session.exerciseRecords {
                guard let exerciseID = record.exerciseID,
                      let exercise = exerciseByID[exerciseID] else {
                    skipCounts[.orphanedExerciseID, default: 0] += 1
                    continue
                }
                guard let mode = TrainingMode(rawValue: record.trainingMode) else {
                    skipCounts[.unknownTrainingMode, default: 0] += 1
                    continue
                }

                let snapshot = ExerciseRecordSnapshot(
                    trainingMode: mode,
                    sessionDate: session.date,
                    sets: record.sets.map { setBackup in
                        SetSnapshot(
                            weightLbs: setBackup.weightLbs,
                            reps: setBackup.reps,
                            isWarmup: setBackup.isWarmup,
                            completedAt: setBackup.completedAt
                        )
                    }
                )

                snapshotsByExerciseID[exercise.id, default: []].append(snapshot)
            }
        }

        let loadedExercises: [LoadedExerciseRecords] = backup.exercises
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { exBackup in
                guard let snapshots = snapshotsByExerciseID[exBackup.id] else { return nil }
                let sortedNewestFirst = snapshots.sorted { $0.sessionDate > $1.sessionDate }
                let loaded = LoadedExercise(
                    id: exBackup.id,
                    name: exBackup.name,
                    dayType: exBackup.dayType,
                    muscleGroup: exBackup.muscleGroup
                )
                return LoadedExerciseRecords(exercise: loaded, snapshots: sortedNewestFirst)
            }

        let summary = LoadedDatasetSummary(
            exerciseCount: loadedExercises.count,
            sessionCount: totalSessions,
            dateRangeStart: dateMin,
            dateRangeEnd: dateMax,
            skipReasons: skipCounts
        )

        return LoadedDataset(
            sourceURL: sourceURL,
            exportedAt: backup.exportedAt,
            exercises: loadedExercises,
            summary: summary
        )
    }
}
