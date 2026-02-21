//
//  SeedData.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftData
import Foundation

struct SeedData {
    private static let seededKey = "hasSeededExercises"

    static func seedIfNeeded(context: ModelContext) {
        let kvStore = NSUbiquitousKeyValueStore.default

        // Already seeded — skip.
        if kvStore.bool(forKey: seededKey) { return }

        // Migration path: existing local data from before CloudKit was added.
        // Mark as seeded so we don't duplicate on next launch, then bail.
        let count = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        if count > 0 {
            kvStore.set(true, forKey: seededKey)
            kvStore.synchronize()
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
            ("Hip Abduction (Inner)", "Adductors"),
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
        kvStore.set(true, forKey: seededKey)
        kvStore.synchronize()
    }
}
