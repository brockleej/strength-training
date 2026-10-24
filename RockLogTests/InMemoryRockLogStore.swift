//
//  InMemoryRockLogStore.swift
//  RockLogTests
//

import SwiftData
@testable import RockLog

enum InMemoryRockLogStore {
    @MainActor
    static func make() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Exercise.self,
            WorkoutSession.self,
            ExerciseRecord.self,
            SetRecord.self,
            SplitDay.self,
            BodyMetricEntry.self,
            TrainingBlock.self,
            configurations: config
        )
    }
}
