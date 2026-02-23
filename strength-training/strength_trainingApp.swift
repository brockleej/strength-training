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
    init() {
        // Pre-create the Application Support directory so SwiftData doesn't
        // hit "No such file or directory" errors on first launch.
        let fileManager = FileManager.default
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            if !fileManager.fileExists(atPath: appSupportURL.path) {
                try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
            }
        }
    }

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
