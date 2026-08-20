//
//  CloudKitSyncService.swift
//  strength-training
//

import CloudKit
import CoreData
import Foundation
import os
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
    /// Blocking failure (auth, quota, schema). Nil if we only had a retryable export skip.
    private(set) var syncError: String?
    /// Last retryable export skip — Settings stays green if `lastSyncDate` is set.
    private(set) var lastExportWarning: String?
    /// True after the first `checkAccountStatus` attempt finishes (success or failure).
    private(set) var hasCheckedAccount = false

    private var observers: [Any] = []
    private let container = CKContainer(identifier: CloudKitSyncService.containerIdentifier)
    private let log = Logger(subsystem: "com.lee.lift2026", category: "CloudKit")

    init() {
        lastSyncDate = UserDefaults.standard.object(forKey: "lastCloudKitSyncDate") as? Date
        guard Self.isEnabled else {
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

    // MARK: - Account / nudge

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

    /// Pull-to-refresh / Retry: re-check the account and wake the private DB.
    /// SwiftData has no public “sync now”; this plus a save is the supported poke.
    @MainActor
    func nudgeSync(modelContext: ModelContext? = nil) async {
        guard Self.isEnabled else { return }
        isSyncing = true
        await checkAccountStatus()
        do {
            _ = try await container.privateCloudDatabase.allRecordZones()
        } catch {
            log.error("nudgeSync zones failed: \(error.localizedDescription, privacy: .public)")
            apply(error: error, eventType: nil)
            isSyncing = false
            return
        }
        try? modelContext?.save()
        // Give NSPersistentCloudKitContainer a moment to emit import/export events.
        try? await Task.sleep(for: .seconds(2))
        if isSyncing { isSyncing = false }
    }

    /// Wait briefly for iCloud before first-run catalog/split seed, so we don't
    /// overwrite a PPL-PC library with bro-split defaults on an empty local store.
    @MainActor
    func waitBeforeInitialSeedIfNeeded(
        modelContext: ModelContext,
        timeout: Duration = .seconds(5)
    ) async {
        guard Self.isEnabled else { return }

        if !hasCheckedAccount {
            await checkAccountStatus()
        }
        guard accountStatus == .available else { return }

        // Split days may already exist from the KVS snapshot. Still wait for
        // the exercise library — otherwise we seed starters onto PPL-PC days
        // and CloudKit later merges them with the user's roster.
        let exerciseCount = (try? modelContext.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        if exerciseCount > 0 { return }

        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if lastSyncDate != nil { return }
            let e = (try? modelContext.fetchCount(FetchDescriptor<Exercise>())) ?? 0
            if e > 0 { return }
            try? await Task.sleep(for: .milliseconds(250))
        }
    }

    // MARK: - Observers

    private func setupObservers() {
        let accountObserver = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { await self?.checkAccountStatus() }
        }
        observers.append(accountObserver)

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
            isSyncing = true
            return
        }

        isSyncing = false
        if event.succeeded {
            syncError = nil
            lastExportWarning = nil
            lastSyncDate = event.endDate
            UserDefaults.standard.set(event.endDate, forKey: "lastCloudKitSyncDate")
            return
        }

        log.error("CloudKit \(String(describing: event.type), privacy: .public) failed: \(event.error?.localizedDescription ?? "nil", privacy: .public)")
        apply(error: event.error, eventType: event.type)
    }

    private func apply(error: Error?, eventType: NSPersistentCloudKitContainer.EventType?) {
        let summary = CloudKitErrorFormatting.summarize(error)
        let message = summary?.message ?? "iCloud hit an unknown error."
        let retryable = summary?.isRetryable ?? false
        let isExport = eventType == .export
        // Import/setup already worked this session (or a previous one): a later
        // export PartialFailure is CloudKit retrying, not “sync is dead.”
        if retryable, lastSyncDate != nil, isExport || eventType == nil {
            lastExportWarning = message
            syncError = nil
            return
        }
        if retryable, lastSyncDate != nil, eventType == .import || eventType == .setup {
            lastExportWarning = message
            syncError = nil
            return
        }
        syncError = message
    }
}
