//
//  DayTypeRegistryTests.swift
//  strength-training-tests
//
//  Duplicate SplitDay names (leftover sim store, CloudKit + seed, mixed
//  split + block days) must not fatal in reindex/reload.
//

import XCTest
import SwiftData
@testable import strength_training

@MainActor
final class DayTypeRegistryTests: XCTestCase {

    override func tearDown() {
        if let container = try? inMemoryContainer() {
            DayTypeRegistry.shared.reload(context: container.mainContext)
        }
        super.tearDown()
    }

    func test_uniquedDefinitions_keepsFirstName_caseInsensitive() {
        let defs = [
            DayTypeDefinition(
                name: "Push",
                systemImage: "dumbbell.fill",
                subtitle: "first",
                colorHex: 0xFF8C42,
                includesAllExercises: false,
                sortOrder: 0
            ),
            DayTypeDefinition(
                name: "push",
                systemImage: "figure.boxing",
                subtitle: "dup",
                colorHex: 0x34C759,
                includesAllExercises: false,
                sortOrder: 1
            ),
            DayTypeDefinition(
                name: "Pull",
                systemImage: "figure.indoor.rowing",
                subtitle: "",
                colorHex: 0x3F9CFF,
                includesAllExercises: false,
                sortOrder: 2
            ),
        ]
        let uniqued = DayTypeRegistry.uniquedDefinitions(defs)
        XCTAssertEqual(uniqued.map(\.name), ["Push", "Pull"])
        XCTAssertEqual(uniqued.first?.subtitle, "first")
    }

    func test_reload_duplicateSplitDayNames_doesNotCrashAndKeepsOne() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        context.insert(SplitDay(
            name: "Push",
            systemImage: "dumbbell.fill",
            colorHex: 0xFF8C42,
            sortOrder: 0
        ))
        context.insert(SplitDay(
            name: "Push",
            systemImage: "figure.boxing",
            colorHex: 0x34C759,
            sortOrder: 1
        ))
        context.insert(SplitDay(
            name: "Lower",
            systemImage: "figure.stair.stepper",
            colorHex: 0x3F9CFF,
            sortOrder: 2
        ))
        try context.save()

        DayTypeRegistry.shared.reload(context: context)

        let names = DayTypeRegistry.shared.activeDays.map(\.rawValue)
        XCTAssertEqual(names.filter { $0.caseInsensitiveCompare("Push") == .orderedSame }.count, 1)
        XCTAssertTrue(names.contains { $0.caseInsensitiveCompare("Lower") == .orderedSame })

        let stored = try context.fetch(FetchDescriptor<SplitDay>())
        XCTAssertEqual(stored.filter { $0.name.lowercased() == "push" }.count, 1)
        XCTAssertEqual(stored.filter { $0.name.lowercased() == "lower" }.count, 1)
    }

    private func inMemoryContainer() throws -> ModelContainer {
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
