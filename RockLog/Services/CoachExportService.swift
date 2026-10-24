//
//  CoachExportService.swift
//  Builds a rocklog.coach.session file from a finished workout.
//

import Foundation
import SwiftData

/// The gym rides on the coach file when the store already has a gym.
/// A session with no gym yet is exported as Home. A container that predates
/// the gym model exports without one.
@MainActor
func coachGym(for session: WorkoutSession) -> (id: UUID, name: String)? {
    guard let context = session.modelContext,
          let gyms = try? context.fetch(FetchDescriptor<Gym>()),
          !gyms.isEmpty
    else { return nil }
    if let id = session.gymID, let gym = gyms.first(where: { $0.id == id }) {
        let name = session.gymName.isEmpty ? gym.name : session.gymName
        return (id, name)
    }
    if let id = session.gymID, !session.gymName.isEmpty {
        return (id, session.gymName)
    }
    if let home = gyms.first(where: \.isHome) {
        return (home.id, home.name)
    }
    return nil
}

enum CoachExportError: LocalizedError {
    case noWorkingSets
    case nothingNewSinceLastShare
    case nothingLastWeek

    var errorDescription: String? {
        switch self {
        case .noWorkingSets:
            return "This workout has no logged sets to send."
        case .nothingNewSinceLastShare:
            return "Nothing new to send. Send a workout from History if you want to send it again."
        case .nothingLastWeek:
            return "No completed workouts last week to send."
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
            let sets = record.loggedSetsArray
                .sorted { $0.setNumber < $1.setNumber }
                .map { set in
                    CoachSetPayload(
                        setNumber: max(1, set.setNumber),
                        weightLbs: set.weightLbs,
                        reps: set.reps,
                        isWarmup: set.isWarmup,
                        isEachSide: set.isEachSide,
                        isAssisted: set.isAssisted,
                        completedAt: set.completedAt,
                        loadMode: set.loadModeRaw.isEmpty ? (set.isAssisted ? "assist" : nil) : set.loadModeRaw,
                        bodyWeightLbs: set.bodyWeightUsedLbs > 0 ? set.bodyWeightUsedLbs : nil
                    )
                }
            guard !sets.isEmpty else { continue }

            let name = record.exercise?.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let notes = record.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let muscle = record.exercise?.muscleGroup.trimmingCharacters(in: .whitespacesAndNewlines)
            let stack = stackUsed(for: record.exercise, in: session)
            let pins = stack.map { profile in
                profile.pins.map { MassMath.pounds(fromDisplay: $0, unit: profile.pinUnit) }
            } ?? []
            exercises.append(
                CoachExercisePayload(
                    id: record.id,
                    name: (name?.isEmpty == false) ? name! : "Exercise",
                    muscleGroup: (muscle?.isEmpty == false) ? muscle : nil,
                    trainingMode: record.trainingMode.rawValue,
                    notes: notes.isEmpty ? nil : notes,
                    sets: sets,
                    groupID: record.groupID,
                    groupPosition: record.groupPosition > 0 ? record.groupPosition : nil,
                    restSeconds: record.exercise?.defaultRestSeconds ?? 0 > 0 ? record.exercise?.defaultRestSeconds : nil,
                    stackStepPounds: stack?.step,
                    stackOffsetLbs: stack?.step == nil ? nil : stack?.offset,
                    stackPinsLbs: pins.isEmpty ? nil : pins
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
                exercises: exercises,
                gymID: coachGym(for: session)?.id,
                gymName: coachGym(for: session)?.name
            )
        )
    }

    /// The profile for the session's gym, then Home. Not whichever gym is selected now.
    private static func stackUsed(for exercise: Exercise?, in session: WorkoutSession) -> StackDefinition? {
        guard let exercise, let context = session.modelContext ?? exercise.modelContext else { return nil }
        guard GymLibrary.storeHasGyms(context) else { return nil }
        let gyms = (try? context.fetch(FetchDescriptor<Gym>())) ?? []
        let home = gyms.first(where: \.isHome)?.id
        let gym = session.gymID ?? home
        guard let gym else { return nil }
        let profiles = ((try? context.fetch(FetchDescriptor<MachineStackProfile>())) ?? []).map {
            StackCandidate(id: $0.id, gymID: $0.gymID, exerciseID: $0.exerciseID, updatedAt: $0.updatedAt, stack: $0.definition)
        }
        return GymStackLookup.resolve(exerciseID: exercise.id, gymID: gym, homeGymID: home, profiles: profiles)
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
            data = try CoachSessionCodec.interchangeData(for: first)
            filename = CoachSessionCodec.suggestedFilename(for: first)
        } else {
            let batch = CoachBatchDocument(
                format: CoachFormat.batchFormatName,
                schemaVersion: CoachFormat.batchSchemaVersion,
                exportedAt: exportedAt,
                athlete: athlete,
                sessions: documents.map(\.session)
            )
            data = try CoachSessionCodec.interchangeData(for: batch)
            filename = CoachSessionCodec.suggestedFilename(for: batch)
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return CoachSharePackage(url: url, sessionIDs: documents.map(\.session.id))
    }

    static func writeLastWeekPackage(
        from completed: [WorkoutSession],
        now: Date = .now
    ) throws -> CoachSharePackage {
        let week = SplitScheduleLogic.completedSessions(inPreviousWeekOf: now, from: completed)
            .filter { SessionMath.setCount(of: $0) > 0 }
        guard !week.isEmpty else { throw CoachExportError.nothingLastWeek }
        return try writePackage(for: week)
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
