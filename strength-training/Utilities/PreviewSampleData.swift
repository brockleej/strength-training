//
//  PreviewSampleData.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftData

@MainActor
let previewContainer: ModelContainer = {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Exercise.self,
        WorkoutSession.self,
        ExerciseRecord.self,
        SetRecord.self,
        configurations: config
    )
    SeedData.seedIfNeeded(context: container.mainContext)
    return container
}()
