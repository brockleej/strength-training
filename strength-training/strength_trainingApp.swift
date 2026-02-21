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
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Exercise.self,
            WorkoutSession.self,
            ExerciseRecord.self,
            SetRecord.self
        ])
    }
}
