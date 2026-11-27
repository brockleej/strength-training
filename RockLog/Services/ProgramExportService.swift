//
//  ProgramExportService.swift
//  RockLog
//
//  Write a stored training block back out as rocklog.program v1, so a plan
//  (and each lift's machine step) can go back to whoever authors the next one.
//  Planned targets only. Logged sets are never written here.
//

import Foundation
import SwiftData

enum ProgramExportService {
    /// The block's planned sessions in queue order. Each lift carries
    /// `weightIncrementLbs` when it has a fixed machine step (current gym, then Home).
    @MainActor
    static func document(blockID: UUID, context: ModelContext, exportedAt: Date = .now) -> ProgramDocument? {
        let id = blockID
        let descriptor = FetchDescriptor<TrainingBlock>(predicate: #Predicate { $0.id == id })
        guard let block = try? context.fetch(descriptor).first else { return nil }
        let sessions = block.sessionsArray
            .filter { !$0.isDeleted }
            .sorted { ($0.planOrder, $0.date) < ($1.planOrder, $1.date) }
        var stepCache: [UUID: Double?] = [:]
        func increment(for exercise: Exercise) -> Double? {
            if let cached = stepCache[exercise.id] { return cached }
            let pounds = MachineIncrement.pounds(of: StackProfileStore.resolved(exerciseID: exercise.id, in: context))
            stepCache[exercise.id] = pounds
            return pounds
        }
        let payloads: [ProgramSessionPayload] = sessions.map { session in
            let exercises = session.exerciseRecordsArray
                .sorted { $0.sortOrder < $1.sortOrder }
                .compactMap { record -> ProgramExercisePayload? in
                    guard let exercise = record.exercise else { return nil }
                    let sets = record.plannedSetsArray.map {
                        ProgramSetPayload(
                            setNumber: $0.setNumber,
                            weightLbs: $0.weightLbs,
                            reps: $0.reps,
                            isWarmup: $0.isWarmup ? true : nil,
                            isEachSide: $0.isEachSide ? true : nil,
                            isAssisted: $0.isAssisted ? true : nil
                        )
                    }
                    return ProgramExercisePayload(
                        id: exercise.id,
                        name: exercise.name,
                        muscleGroup: exercise.muscleGroup.isEmpty ? nil : exercise.muscleGroup,
                        trainingMode: record.trainingMode.rawValue,
                        notes: record.notes.isEmpty ? nil : record.notes,
                        sets: sets,
                        weightIncrementLbs: increment(for: exercise)
                    )
                }
            return ProgramSessionPayload(
                id: session.id,
                date: session.date,
                dayType: session.dayType,
                rotationTrack: session.track.badge,
                notes: session.notes.isEmpty ? nil : session.notes,
                exercises: exercises
            )
        }
        guard !payloads.isEmpty else { return nil }
        return ProgramDocument(
            format: ProgramFormat.formatName,
            schemaVersion: ProgramFormat.schemaVersion,
            exportedAt: exportedAt,
            weightUnit: "lb",
            block: ProgramBlockPayload(
                id: block.id,
                name: block.name,
                notes: block.notes.isEmpty ? nil : block.notes,
                startDate: block.startDate,
                sessions: payloads
            )
        )
    }

    @MainActor
    static func data(blockID: UUID, context: ModelContext) throws -> Data? {
        guard let document = document(blockID: blockID, context: context) else { return nil }
        return try ProgramCodec.encode(document)
    }
}
