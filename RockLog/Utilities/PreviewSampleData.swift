//
//  PreviewSampleData.swift
//  RockLog
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftData

@MainActor
let previewContainer: ModelContainer = {
    precondition(
        !RockLogTestHost.isUnitTestHost,
        "The preview store must not be created while the app is the unit-test host."
    )
    let config = ModelConfiguration(
        "RockLogPreviews",
        isStoredInMemoryOnly: true,
        cloudKitDatabase: .none
    )
    let container = try! ModelContainer(
        for: Exercise.self,
        WorkoutSession.self,
        ExerciseRecord.self,
        SetRecord.self,
        SplitDay.self,
        BodyMetricEntry.self,
        TrainingBlock.self,
        Gym.self,
        MachineStackProfile.self,
        configurations: config
    )
    SeedData.seedIfNeeded(context: container.mainContext)
    DayTypeRegistry.shared.applyPreset(
        .pushPullLegs,
        context: container.mainContext,
        includeStarters: true
    )
    return container
}()
