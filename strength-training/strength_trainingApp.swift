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
        do {
            let config = ModelConfiguration(cloudKitDatabase: .automatic)
            container = try ModelContainer(
                for: Exercise.self, WorkoutSession.self, ExerciseRecord.self, SetRecord.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
