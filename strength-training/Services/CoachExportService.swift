//
//  CoachExportService.swift
//  Builds a rocklog.coach.session file from a finished workout.
//

import Foundation

enum CoachExportError: LocalizedError {
    case noWorkingSets
    case nothingNewSinceLastShare

    var errorDescription: String? {
        switch self {
        case .noWorkingSets:
            return "This workout has no logged sets to send."
        case .nothingNewSinceLastShare:
            return "Nothing new to send. Send a workout from History if you want to send it again."
        }
    }
}

struct CoachSharePackage {
    var url: URL
    var sessionIDs: [UUID]
}

@MainActor
enum CoachExportService {
    @MainActor
    static func document(
        from session: WorkoutSession,
        athlete: CoachAthlete,
        exportedAt: Date = .now
    ) throws -> CoachSessionDocument {
        var exercises: [CoachExercisePayload] = []
        for record in session.exerciseRecordsArray.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let sets = record.setsArray
                .sorted { $0.setNumber < $1.setNumber }
                .map { set in
                    CoachSetPayload(
                        setNumber: max(1, set.setNumber),
                        weightLbs: set.weightLbs,
                        reps: set.reps,
                        isWarmup: set.isWarmup,
                        isEachSide: set.isEachSide,
                        isAssisted: set.isAssisted,
                        completedAt: set.completedAt
                    )
                }
            guard !sets.isEmpty else { continue }

            let name = record.exercise?.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let notes = record.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let muscle = record.exercise?.muscleGroup.trimmingCharacters(in: .whitespacesAndNewlines)
            exercises.append(
                CoachExercisePayload(
                    id: record.id,
                    name: (name?.isEmpty == false) ? name! : "Exercise",
                    muscleGroup: (muscle?.isEmpty == false) ? muscle : nil,
                    trainingMode: record.trainingMode.rawValue,
                    notes: notes.isEmpty ? nil : notes,
                    sets: sets
                )
            )
        }
        guard !exercises.isEmpty else { throw CoachExportError.noWorkingSets }

        let notes = session.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let track = session.rotationTrack.trimmingCharacters(in: .whitespacesAndNewlines)

        return CoachSessionDocument(
            format: CoachFormat.formatName,
            schemaVersion: CoachFormat.schemaVersion,
            exportedAt: exportedAt,
            athlete: athlete,
            session: CoachSessionPayload(
                id: session.id,
                startedAt: session.date,
                dayType: session.dayType,
                rotationTrack: track.isEmpty ? nil : track,
                notes: notes.isEmpty ? nil : notes,
                effortRating: session.effortRating,
                exercises: exercises
            )
        )
    }

    static func encodedData(for session: WorkoutSession) throws -> Data {
        try CoachSessionCodec.encode(document(from: session, athlete: CoachAthletePreferences.athlete))
    }

    static func writeTemporaryFile(for session: WorkoutSession) throws -> URL {
        try writePackage(for: [session]).url
    }

    /// One session → `rocklog.coach.session`. Two or more → `rocklog.coach.batch`.
    @MainActor
    static func writePackage(
        for sessions: [WorkoutSession],
        athlete: CoachAthlete? = nil,
        exportedAt: Date = .now
    ) throws -> CoachSharePackage {
        let athlete = athlete ?? CoachAthletePreferences.athlete
        let documents = try sessions.map { session in
            try document(from: session, athlete: athlete, exportedAt: exportedAt)
        }
        guard let first = documents.first else { throw CoachExportError.noWorkingSets }

        let data: Data
        let filename: String
        if documents.count == 1 {
            data = try CoachSessionCodec.encode(first)
            filename = CoachSessionCodec.suggestedFilename(for: first)
        } else {
            let batch = CoachBatchDocument(
                format: CoachFormat.batchFormatName,
                schemaVersion: CoachFormat.batchSchemaVersion,
                exportedAt: exportedAt,
                athlete: athlete,
                sessions: documents.map(\.session)
            )
            data = try CoachSessionCodec.encode(batch)
            filename = CoachSessionCodec.suggestedFilename(for: batch)
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return CoachSharePackage(url: url, sessionIDs: documents.map(\.session.id))
    }

    static func present(_ package: CoachSharePackage) {
        ShareSheetPresenter.presentFile(package.url) { completed in
            if completed {
                CoachShareLedger.markShared(package.sessionIDs)
            }
        }
    }

    static func writeUnsharedPackage(
        from completed: [WorkoutSession],
        athlete: CoachAthlete? = nil
    ) throws -> CoachSharePackage {
        let pending = CoachShareLedger.unshared(from: completed)
        guard !pending.isEmpty else { throw CoachExportError.nothingNewSinceLastShare }
        return try writePackage(for: pending, athlete: athlete ?? CoachAthletePreferences.athlete)
    }
}
