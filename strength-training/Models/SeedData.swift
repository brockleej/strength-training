//
//  SeedData.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftData

struct SeedData {
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Exercise>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

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
    }
}
