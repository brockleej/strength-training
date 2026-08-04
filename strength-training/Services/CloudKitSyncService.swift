//
//  CloudKitSyncService.swift
//  strength-training
//

import Foundation
import CloudKit
import CoreData

@Observable
final class CloudKitSyncService {
    /// Must match the iCloud container in `strength-training.entitlements`
    /// and `ModelConfiguration(cloudKitDatabase:)` in `strength_trainingApp`.
    static let containerIdentifier = "iCloud.com.lee.lift2026"

    /// When false, never call CloudKit APIs — `accountStatus()` can hang forever
    /// without a configured iCloud container. Keep in sync with
    /// `ModelConfiguration(cloudKitDatabase:)` in `strength_trainingApp`.
    static var isEnabled: Bool { true }

    private(set) var accountStatus: CKAccountStatus = .couldNotDetermine
    private(set) var isSyncing = false
    private(set) var lastSyncDate: Date?
    private(set) var syncError: String?
    /// True after the first `checkAccountStatus` attempt finishes (success or failure).
    private(set) var hasCheckedAccount = false

    private var observers: [Any] = []
    private let container = CKContainer(identifier: CloudKitSyncService.containerIdentifier)

    init() {
        lastSyncDate = UserDefaults.standard.object(forKey: "lastCloudKitSyncDate") as? Date
        guard Self.isEnabled else {
            // Distinct from "still checking" so Settings can show local-only copy.
            accountStatus = .couldNotDetermine
            hasCheckedAccount = true
            syncError = nil
            return
        }
        setupObservers()
        Task { await checkAccountStatus() }
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - Account Status

    func checkAccountStatus() async {
        guard Self.isEnabled else {
            await MainActor.run {
                self.accountStatus = .couldNotDetermine
                self.hasCheckedAccount = true
            }
            return
        }
        do {
            let status = try await container.accountStatus()
            await MainActor.run {
                self.accountStatus = status
                self.hasCheckedAccount = true
            }
        } catch {
            await MainActor.run {
                self.accountStatus = .couldNotDetermine
                self.hasCheckedAccount = true
                self.syncError = error.localizedDescription
            }
        }
    }

    // MARK: - Observers

    private func setupObservers() {
        // Monitor iCloud account changes
        let accountObserver = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { await self?.checkAccountStatus() }
        }
        observers.append(accountObserver)

        // Monitor CloudKit sync events from the underlying persistent container
        let syncObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleSyncEvent(notification)
        }
        observers.append(syncObserver)
    }

    private func handleSyncEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
            as? NSPersistentCloudKitContainer.Event
        else {
            return
        }

        if event.endDate == nil {
            // Event is in progress
            isSyncing = true
            syncError = nil
        } else if event.succeeded {
            // Event completed successfully
            isSyncing = false
            syncError = nil
            lastSyncDate = event.endDate
            UserDefaults.standard.set(event.endDate, forKey: "lastCloudKitSyncDate")
        } else {
            // Event failed
            isSyncing = false
            syncError = event.error?.localizedDescription
        }
    }
}
