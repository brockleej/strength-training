//
//  CloudKitSyncService.swift
//  strength-training
//

import Foundation
import CloudKit
import CoreData

@Observable
final class CloudKitSyncService {
    private(set) var accountStatus: CKAccountStatus = .couldNotDetermine
    private(set) var isSyncing = false
    private(set) var lastSyncDate: Date?
    private(set) var syncError: String?

    private var observers: [Any] = []

    init() {
        lastSyncDate = UserDefaults.standard.object(forKey: "lastCloudKitSyncDate") as? Date
        setupObservers()
        Task { await checkAccountStatus() }
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - Account Status

    func checkAccountStatus() async {
        do {
            let status = try await CKContainer.default().accountStatus()
            await MainActor.run { self.accountStatus = status }
        } catch {
            await MainActor.run { self.accountStatus = .couldNotDetermine }
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

        // Monitor CloudKit sync events
        let syncObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSPersistentCloudKitContainer.eventChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleSyncEvent(notification)
        }
        observers.append(syncObserver)
    }

    private func handleSyncEvent(_ notification: Notification) {
        // Extract the event from userInfo using the Core Data key
        guard let event = notification.userInfo?["event"] as? NSPersistentCloudKitContainer.Event else {
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
