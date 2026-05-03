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
}

struct WorkoutSessionBackup: Codable {
    let id: UUID
    let date: Date
    let dayType: String
    let notes: String
    let isCompleted: Bool
    let exerciseRecords: [ExerciseRecordBackup]
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
