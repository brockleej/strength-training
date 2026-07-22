//
//  strength_trainingApp.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI
import SwiftData

@main
struct strength_trainingApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([
            Exercise.self,
            WorkoutSession.self,
            ExerciseRecord.self,
            SetRecord.self,
            SplitDay.self,
            BodyMetricEntry.self,
        ])
        // Local-only store. CloudKit / iCloud requires a paid Apple Developer
        // Program team (Personal teams cannot provision iCloud or Push).
        // Flip to `.automatic` and restore iCloud entitlements when you enroll.
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .none
        )
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
