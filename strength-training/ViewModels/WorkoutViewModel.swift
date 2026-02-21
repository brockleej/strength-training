//
//  WorkoutViewModel.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI
import SwiftData

@Observable
final class WorkoutViewModel {
    var modelContext: ModelContext
    var activeSession: WorkoutSession?
    var selectedMode: TrainingMode = .highWeightLowReps

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        resolveSessionState()
    }

    // MARK: - Session Lifecycle

    /// On launch: resume today's session, auto-complete stale ones, or start fresh.
    func resolveSessionState() {
        autoCompleteStaleSession()

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> {
                $0.isCompleted == false &&
                $0.date >= startOfToday &&
                $0.date < endOfToday
            }
        )
        descriptor.fetchLimit = 1

        activeSession = try? modelContext.fetch(descriptor).first
    }

    /// Auto-complete any sessions from previous days that were never finished.
    func autoCompleteStaleSession() {
        let startOfToday = Calendar.current.startOfDay(for: .now)

        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> {
                $0.isCompleted == false &&
                $0.date < startOfToday
            }
        )

        if let staleSessions = try? modelContext.fetch(descriptor) {
            for session in staleSessions {
                session.isCompleted = true
            }
            try? modelContext.save()
        }
    }

    func startSession(dayType: DayType) {
        let session = WorkoutSession(dayType: dayType)
        modelContext.insert(session)
        try? modelContext.save()
        activeSession = session
    }

    func finishSession() {
        guard let session = activeSession else { return }
        session.isCompleted = true
        try? modelContext.save()
        activeSession = nil
    }

    // MARK: - Exercises

    func exercises(for dayType: DayType) -> [Exercise] {
        // Fetch all exercises then filter in Swift — avoids #Predicate enum comparison issues
        let descriptor = FetchDescriptor<Exercise>(
            sortBy: [SortDescriptor(\Exercise.sortOrder)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        if dayType == .fullBody { return all }
        return all.filter { $0.dayType == dayType }
    }

    // MARK: - Last Session Query

    /// The key query: what did I do last time for this exercise in this mode?
    /// Uses the existing relationship on Exercise instead of a fetch — avoids
    /// #Predicate limitations with optional chaining and enum rawValue.
    func lastRecord(for exercise: Exercise, mode: TrainingMode) -> ExerciseRecord? {
        exercise.records
            .filter { $0.trainingMode == mode && $0.session?.isCompleted == true }
            .sorted { ($0.session?.date ?? .distantPast) > ($1.session?.date ?? .distantPast) }
            .first
    }

    /// Get the current session's record for an exercise in the active mode.
    func currentRecord(for exercise: Exercise) -> ExerciseRecord? {
        guard let session = activeSession else { return nil }
        let modeRaw = selectedMode.rawValue
        return session.exerciseRecords.first {
            $0.exercise?.id == exercise.id &&
            $0.trainingMode.rawValue == modeRaw
        }
    }

    // MARK: - Set Logging

    func addSet(exercise: Exercise, weight: Double, reps: Int) {
        let record = findOrCreateRecord(for: exercise)
        let setNumber = record.sets.count + 1
        let set = SetRecord(setNumber: setNumber, weightLbs: weight, reps: reps)
        set.exerciseRecord = record
        record.sets.append(set)
        modelContext.insert(set)
        try? modelContext.save()
    }

    func deleteSet(_ set: SetRecord, from exercise: Exercise) {
        modelContext.delete(set)
        // Renumber remaining sets
        if let record = currentRecord(for: exercise) {
            let sorted = record.sets.sorted { $0.setNumber < $1.setNumber }
            for (index, s) in sorted.enumerated() {
                s.setNumber = index + 1
            }
        }
        try? modelContext.save()
    }

    // MARK: - Exercise Completion

    func markExerciseComplete(_ exercise: Exercise) {
        let record = findOrCreateRecord(for: exercise)

        // If no sets logged, copy from last session
        if record.sets.isEmpty {
            if let lastRecord = lastRecord(for: exercise, mode: selectedMode) {
                for lastSet in lastRecord.sets.sorted(by: { $0.setNumber < $1.setNumber }) {
                    let copiedSet = SetRecord(
                        setNumber: lastSet.setNumber,
                        weightLbs: lastSet.weightLbs,
                        reps: lastSet.reps,
                        isWarmup: lastSet.isWarmup
                    )
                    copiedSet.exerciseRecord = record
                    record.sets.append(copiedSet)
                    modelContext.insert(copiedSet)
                }
            }
        }

        record.isCompleted = true
        try? modelContext.save()
    }

    func markExerciseIncomplete(_ exercise: Exercise) {
        if let record = currentRecord(for: exercise) {
            record.isCompleted = false
            try? modelContext.save()
        }
    }

    func isExerciseCompleted(_ exercise: Exercise) -> Bool {
        currentRecord(for: exercise)?.isCompleted ?? false
    }

    // MARK: - Helpers

    private func findOrCreateRecord(for exercise: Exercise) -> ExerciseRecord {
        if let existing = currentRecord(for: exercise) {
            return existing
        }

        guard let session = activeSession else {
            fatalError("No active session when trying to create ExerciseRecord")
        }

        let record = ExerciseRecord(
            trainingMode: selectedMode,
            sortOrder: session.exerciseRecords.count
        )
        record.exercise = exercise
        record.session = session
        session.exerciseRecords.append(record)
        modelContext.insert(record)
        try? modelContext.save()
        return record
    }
}
