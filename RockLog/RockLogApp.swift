//
//  RockLogApp.swift
//  RockLog
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct RockLogApp: App {
    @State private var container: ModelContainer?
    @State private var storeError: String?

    init() {
        // Rest timer is audio-only; suppress/clear any leftover rest-timer notifications.
        UNUserNotificationCenter.current().delegate = RestTimerNotificationDelegate.shared
        RestTimerNotificationScheduler.cancelAll()
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                ContentView()
                    .modelContainer(container)
            } else if let storeError {
                RockLogLaunchPlaceholder(showsProgress: false)
                    .overlay(alignment: .bottom) {
                        VStack(spacing: 12) {
                            Text(storeError)
                                .font(.footnote)
                                .foregroundStyle(Color.uplift.fgMuted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 28)
                            Button("Try again") {
                                self.storeError = nil
                            }
                            .font(.headline)
                            .foregroundStyle(Color.uplift.accent)
                        }
                        .padding(.bottom, 48)
                    }
            } else {
                RockLogLaunchPlaceholder(showsProgress: true)
                    .task { await openStore() }
            }
        }
    }

    /// First frame must paint before CloudKit store setup. `ModelContainer`
    /// with `.automatic` can take tens of seconds on a brand-new install.
    @MainActor
    private func openStore() async {
        await Task.yield()
        #if DEBUG
        if UITestLaunch.isEnabled {
            openUITestStore()
            return
        }
        #endif
        let schema = Schema(versionedSchema: RockLogSchemaV1.self)
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .automatic
        )
        do {
            container = try await Task.detached(priority: .userInitiated) {
                try ModelContainer(
                    for: schema,
                    migrationPlan: RockLogMigrationPlan.self,
                    configurations: [config]
                )
            }.value
        } catch {
            storeError = "Couldn’t open the workout store. \(error.localizedDescription)"
        }
    }

    #if DEBUG
    /// In-memory (or a wiped temp file for the relaunch test). No CloudKit.
    @MainActor
    private func openUITestStore() {
        UITestLaunch.prepareDefaults()
        do {
            container = try UITestLaunch.makeContainer()
        } catch {
            storeError = "Couldn’t open the UI test store. \(error.localizedDescription)"
        }
    }
    #endif
}
