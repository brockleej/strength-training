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
    @State private var storeAttempt = 0

    init() {
        // Rest timer is audio-only; suppress/clear any leftover rest-timer notifications.
        UNUserNotificationCenter.current().delegate = RestTimerNotificationDelegate.shared
        RestTimerNotificationScheduler.cancelAll()
        MassUnitPreferences.pullFromCloud()
    }

    var body: some Scene {
        WindowGroup {
            if RockLogTestHost.isUnitTestHost {
                // No model container and no CloudKit. Unit tests open their own stores.
                Color.clear
            } else if let container {
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
                            Button("Retry") {
                                self.storeError = nil
                                storeAttempt += 1
                            }
                            .font(.headline)
                            .foregroundStyle(Color.uplift.accent)
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityIdentifier(AccessibilityID.storeRetry)
                        }
                        .padding(.bottom, 48)
                    }
            } else {
                RockLogLaunchPlaceholder(showsProgress: true)
                    .task(id: storeAttempt) { await openStore() }
            }
        }
    }

    /// First frame must paint before CloudKit store setup. `ModelContainer`
    /// with `.automatic` can take tens of seconds on a brand-new install.
    @MainActor
    private func openStore() async {
        if RockLogTestHost.isUnitTestHost { return }
        await Task.yield()
        #if DEBUG
        if UITestLaunch.isEnabled {
            openUITestStore()
            return
        }
        #endif
        let schema = Schema(versionedSchema: RockLogSchemaV3.self)
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
            if let container {
                BackupService.recoverRestorePreferencesIfNeeded(context: container.mainContext)
            }
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
