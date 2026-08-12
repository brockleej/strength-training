//
//  strength_trainingApp.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct strength_trainingApp: App {
    let container: ModelContainer

    init() {
        // Rest timer is audio-only; suppress/clear any leftover rest-timer notifications.
        UNUserNotificationCenter.current().delegate = RestTimerNotificationDelegate.shared
        RestTimerNotificationScheduler.cancelAll()

        let schema = Schema([
            Exercise.self,
            WorkoutSession.self,
            ExerciseRecord.self,
            SetRecord.self,
            SplitDay.self,
            BodyMetricEntry.self,
        ])
        // Private CloudKit database via the iCloud container in
        // strength-training.entitlements (iCloud.com.lee.lift2026).
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .automatic
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
