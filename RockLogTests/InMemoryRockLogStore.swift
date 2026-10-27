//
//  InMemoryRockLogStore.swift
//  RockLogTests
//

import XCTest
import SwiftData
@testable import RockLog

enum InMemoryRockLogStore {
    /// One store per call. The name is unique so parallel (or overlapping)
    /// tests cannot attach to the same SQLite memory identifier, and CloudKit
    /// is off so the test host never asks for an iCloud connection.
    @MainActor
    static func make() throws -> ModelContainer {
        let name = "RockLogTest-\(UUID().uuidString)"
        let schema = Schema([
            Exercise.self,
            WorkoutSession.self,
            ExerciseRecord.self,
            SetRecord.self,
            SplitDay.self,
            BodyMetricEntry.self,
            TrainingBlock.self,
            Gym.self,
            MachineStackProfile.self,
        ])
        let config = ModelConfiguration(
            name,
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}

/// Owns the SwiftData store for one test method.
///
/// `setUp` opens it and `tearDown` releases it. Tests use `container`
/// instead of a local `ModelContainer`, which would deallocate before
/// `tearDown` and race the store.
@MainActor
class RockLogStoreTestCase: XCTestCase {
    var container: ModelContainer!
    /// Second store for a test that copies between two containers.
    var secondaryContainer: ModelContainer?
    /// Kept until tearDown so deferred saves can be cancelled before the store is released.
    private var heldWorkoutViewModels: [WorkoutViewModel] = []

    func holdWorkoutViewModel(_ viewModel: WorkoutViewModel) -> WorkoutViewModel {
        heldWorkoutViewModels.append(viewModel)
        return viewModel
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try InMemoryRockLogStore.make()
        container.mainContext.autosaveEnabled = false
    }

    override func tearDown() {
        heldWorkoutViewModels.forEach { $0.cancelPendingWork() }
        heldWorkoutViewModels.removeAll()
        DayTypeRegistry.shared.resetToFallback()
        secondaryContainer?.mainContext.rollback()
        container?.mainContext.rollback()
        secondaryContainer = nil
        container = nil
        super.tearDown()
    }

    func openSecondaryContainer() throws {
        let opened = try InMemoryRockLogStore.make()
        opened.mainContext.autosaveEnabled = false
        secondaryContainer = opened
    }
}
