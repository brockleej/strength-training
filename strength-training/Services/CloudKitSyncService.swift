//
//  CloudKitSyncService.swift
//  strength-training
//

import Foundation
import CloudKit
import CoreData
import SwiftData

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
                self.syncError = CloudKitErrorFormatting.userFacingMessage(from: error)
            }
        }
    }

    /// Wait briefly for iCloud before first-run catalog/split seed, so we don't
    /// overwrite a PPL-PC library with bro-split defaults on an empty local store.
    /// Returns when: no iCloud account, already has data, first successful import, or timeout.
    @MainActor
    func waitBeforeInitialSeedIfNeeded(
        modelContext: ModelContext,
        timeout: Duration = .seconds(5)
    ) async {
        guard Self.isEnabled else { return }

        if !hasCheckedAccount {
            await checkAccountStatus()
        }
        // No iCloud → seed immediately.
        guard accountStatus == .available else { return }

        let exerciseCount = (try? modelContext.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        let splitCount = (try? modelContext.fetchCount(FetchDescriptor<SplitDay>())) ?? 0
        if exerciseCount > 0 || splitCount > 0 { return }

        // Empty local store with iCloud on: give CloudKit a few seconds to land.
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if lastSyncDate != nil { return }
            let e = (try? modelContext.fetchCount(FetchDescriptor<Exercise>())) ?? 0
            let s = (try? modelContext.fetchCount(FetchDescriptor<SplitDay>())) ?? 0
            if e > 0 || s > 0 { return }
            try? await Task.sleep(for: .milliseconds(250))
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
            syncError = CloudKitErrorFormatting.userFacingMessage(from: event.error)
        }
    }
}
