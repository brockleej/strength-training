//
//  SeedData.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import Foundation
import SwiftData

struct SeedData {
    /// One-time, idempotent display-name corrections for seeded exercises.
    /// Runs on every launch and after every backup restore — existing records
    /// keep their relationships (rename only), and restoring an old backup
    /// re-applies the fix on the spot.
    static func migrateExerciseNames(context: ModelContext) {
        let renames = ["Hip Abduction (Inner)": "Hip Adduction (Inner)"]
        let descriptor = FetchDescriptor<Exercise>()
        guard let all = try? context.fetch(descriptor) else { return }
        var changed = false
        for exercise in all {
            if let newName = renames[exercise.name] {
                exercise.name = newName
                changed = true
            }
        }
        if changed { try? context.save() }
    }

    /// Removes duplicate exercises (same name + dayType), keeping the one with the most history.
    /// Records from duplicates are reassigned to the kept exercise before deletion.
    static func deduplicateExercises(context: ModelContext) {
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        var grouped: [String: [Exercise]] = [:]
        for exercise in exercises {
            let key = "\(exercise.name)|\(exercise.dayType.rawValue)"
            grouped[key, default: []].append(exercise)
        }
        for (_, group) in grouped where group.count > 1 {
            // Keep the exercise with the most records
            let sorted = group.sorted { $0.recordsArray.count > $1.recordsArray.count }
            let keeper = sorted[0]
            for duplicate in sorted.dropFirst() {
                // Reassign any records from the duplicate to the keeper
                for record in duplicate.recordsArray {
                    record.exercise = keeper
                }
                context.delete(duplicate)
            }
        }
        try? context.save()
    }

    static func seedIfNeeded(context: ModelContext) {
        let hasSeeded = UserDefaults.standard.bool(forKey: "hasSeededExercises")
        guard !hasSeeded else { return }
        let count = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        guard count == 0 else {
            // Data exists (possibly from iCloud sync) — mark as seeded
            UserDefaults.standard.set(true, forKey: "hasSeededExercises")
            return
        }

        let armsExercises: [(String, String)] = [
            ("Shoulder Press", "Shoulders"),
            ("Rear Deltoid", "Shoulders"),
            ("Pectoral Fly", "Chest"),
            ("Row", "Back"),
            ("Pulldown", "Back"),
            ("Torso Rotation", "Core"),
            ("Chest Press", "Chest"),
            ("Biceps Curl", "Biceps"),
            ("Triceps Press", "Triceps")
        ]

        let legsExercises: [(String, String)] = [
            ("Leg Curl", "Hamstrings"),
            ("Calf Extension", "Calves"),
            ("Leg Extension", "Quads"),
            ("Glute", "Glutes"),
            ("Back Extension", "Lower Back"),
            ("Hip Abduction (Glute)", "Glutes"),
            ("Hip Adduction (Inner)", "Adductors"),
            ("Seated Leg Press", "Quads"),
            ("Seated Leg Curl", "Hamstrings"),
            ("Abdominal", "Core")
        ]

        for (index, (name, muscle)) in armsExercises.enumerated() {
            context.insert(
                Exercise(name: name, dayType: .arms, muscleGroup: muscle, sortOrder: index)
            )
        }

        for (index, (name, muscle)) in legsExercises.enumerated() {
            context.insert(
                Exercise(name: name, dayType: .legs, muscleGroup: muscle, sortOrder: index)
            )
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: "hasSeededExercises")
    }
}
