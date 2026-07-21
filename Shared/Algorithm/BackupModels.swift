//
//  BackupModels.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import Foundation

struct AppBackup: Codable {
    let version: Int
    let exportedAt: Date
    let exercises: [ExerciseBackup]
    let sessions: [WorkoutSessionBackup]
}

struct ExerciseBackup: Codable {
    let id: UUID
    let name: String
    let dayType: String
    let muscleGroup: String
    let sortOrder: Int
    let isCustom: Bool
    let notes: String
    /// "" / "A" / "B" — optional for older backups.
    let rotationTrack: String?
    /// Comma-separated extra day names — optional for older backups.
    let extraDayTypes: String?

    init(
        id: UUID,
        name: String,
        dayType: String,
        muscleGroup: String,
        sortOrder: Int,
        isCustom: Bool,
        notes: String,
        rotationTrack: String? = nil,
        extraDayTypes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.dayType = dayType
        self.muscleGroup = muscleGroup
        self.sortOrder = sortOrder
        self.isCustom = isCustom
        self.notes = notes
        self.rotationTrack = rotationTrack
        self.extraDayTypes = extraDayTypes
    }
}

struct WorkoutSessionBackup: Codable {
    let id: UUID
    let date: Date
    let dayType: String
    let notes: String
    let isCompleted: Bool
    let exerciseRecords: [ExerciseRecordBackup]
    /// "" / "A" / "B" — optional for older backups.
    let rotationTrack: String?

    init(
        id: UUID,
        date: Date,
        dayType: String,
        notes: String,
        isCompleted: Bool,
        exerciseRecords: [ExerciseRecordBackup],
        rotationTrack: String? = nil
    ) {
        self.id = id
        self.date = date
        self.dayType = dayType
        self.notes = notes
        self.isCompleted = isCompleted
        self.exerciseRecords = exerciseRecords
        self.rotationTrack = rotationTrack
    }
}

struct ExerciseRecordBackup: Codable {
    let id: UUID
    let exerciseID: UUID?
    let trainingMode: String
    let sortOrder: Int
    let isCompleted: Bool
    let notes: String
    let sets: [SetRecordBackup]
}

struct SetRecordBackup: Codable {
    let id: UUID
    let setNumber: Int
    let weightLbs: Double
    let reps: Int
    let isWarmup: Bool
    let completedAt: Date
}
