//
//  SettingsView.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI
import SwiftData
import UIKit
internal import UniformTypeIdentifiers
import CloudKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    var healthKitService: HealthKitWorkoutService
    var cloudKitSyncService: CloudKitSyncService

    @State private var isImporting = false
    @State private var pendingRestoreData: Data?
    @State private var showRestoreConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successMessage = ""

    @AppStorage("progressionAggressiveness")
    private var aggressiveness: String = ProgressionAggressiveness.moderate.rawValue

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NavBar(
                    title: "Settings",
                    style: .large(size: 38),
                    leading: { EmptyView() },
                    trailing: { EmptyView() }
                )
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        appleHealthSection
                        progressiveOverloadSection
                        iCloudSyncSection
                        dataManagementSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)
            }
            .background(Color.uplift.bgElev)
            .toolbar(.hidden, for: .navigationBar)
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
            .confirmationDialog(
                "Restore Backup?",
                isPresented: $showRestoreConfirmation,
                titleVisibility: .visible
            ) {
                Button("Replace All Data", role: .destructive) {
                    if let data = pendingRestoreData {
                        performRestore(data: data)
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingRestoreData = nil
                }
            } message: {
                Text("This will permanently replace all current workout data. This cannot be undone.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(successMessage)
            }
        }
    }

    // MARK: - Apple Health Section

    @ViewBuilder
    private var appleHealthSection: some View {
        SettingsSection(
            header: "Apple Health",
            footer: "When connected, workouts are saved to Apple Health for Activity Ring credit and fitness tracking."
        ) {
            let canTap = healthKitService.isAvailable && healthKitService.authorizationStatus == nil
            HStack(spacing: 12) {
                statusIcon
                statusLabel
                Spacer()
            }
            .padding(14)
            .background(Color.uplift.surface1, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture { if canTap { tryRequestAuth() } }
        }
    }

    private var statusIcon: some View {
        let (bg, sym, tint): (Color, String, Color) = {
            guard healthKitService.isAvailable else {
                return (Color.uplift.fgFaint, "heart.slash", Color.uplift.fgMuted)
            }
            switch healthKitService.authorizationStatus {
            case true?:  return (Color.uplift.ahkitGreen.opacity(0.18), "checkmark", Color.uplift.ahkitGreen)
            case false?: return (Color.uplift.ahkitOrange.opacity(0.18), "exclamationmark", Color.uplift.ahkitOrange)
            case nil:    return (Color.uplift.accentSoft, "heart.fill", Color.uplift.accent)
            }
        }()
        return ZStack {
            Circle().fill(bg).frame(width: 28, height: 28)
            Image(systemName: sym)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        if !healthKitService.isAvailable {
            Text("Apple Health Not Available")
                .font(.uplift.text(15, weight: .semibold))
                .kerning(-0.2)
                .foregroundStyle(Color.uplift.fgMuted)
        } else {
            switch healthKitService.authorizationStatus {
            case true?:
                Text("Apple Health Connected")
                    .font(.uplift.text(15, weight: .semibold))
                    .kerning(-0.2)
                    .foregroundStyle(Color.uplift.ahkitGreen)
            case false?:
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Health Not Authorized")
                        .font(.uplift.text(15, weight: .semibold))
                        .kerning(-0.2)
                        .foregroundStyle(Color.uplift.ahkitOrange)
                    Text("Open Settings > Privacy > Health to grant access.")
                        .font(.uplift.text(12, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                }
            case nil:
                Text("Connect Apple Health")
                    .font(.uplift.text(15, weight: .semibold))
                    .kerning(-0.2)
                    .foregroundStyle(Color.uplift.accent)
            }
        }
    }

    private func tryRequestAuth() {
        guard healthKitService.isAvailable, healthKitService.authorizationStatus == nil else { return }
        Task { await healthKitService.requestAuthorization() }
    }

    // MARK: - Progressive Overload Section

    private var progressiveOverloadSection: some View {
        SettingsSection(
            header: "Progressive Overload",
            footer: footerText(for: aggressiveness)
        ) {
            HStack(spacing: 4) {
                overloadSegment(rawValue: ProgressionAggressiveness.moderate.rawValue, label: "Moderate")
                overloadSegment(rawValue: ProgressionAggressiveness.conservative.rawValue, label: "Conservative")
            }
            .padding(3)
            .background(Color.uplift.surface1, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func overloadSegment(rawValue: String, label: String) -> some View {
        let active = (aggressiveness == rawValue)
        return Button { aggressiveness = rawValue } label: {
            Text(label)
                .font(.uplift.text(14, weight: .semibold))
                .kerning(-0.1)
                .foregroundStyle(active ? Color.uplift.fg : Color.uplift.fgMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(active ? Color.uplift.surface3 : Color.clear,
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func footerText(for raw: String) -> String {
        raw == ProgressionAggressiveness.moderate.rawValue
            ? "Moderate recommends a weight increase after 2 consistent sessions. Conservative requires 3."
            : "Conservative requires 3 consistent sessions before recommending a weight increase. Moderate requires 2."
    }

    // MARK: - iCloud Sync Section

    @ViewBuilder
    private var iCloudSyncSection: some View {
        SettingsSection(
            header: "iCloud Sync",
            footer: "Your workout data automatically syncs to iCloud and is available across all your devices. Data persists even if you uninstall the app."
        ) {
            HStack(spacing: 12) {
                iCloudIcon
                iCloudLabel
                Spacer(minLength: 0)
                iCloudTrailing
            }
            .padding(14)
            .background(Color.uplift.surface1, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var iCloudIcon: some View {
        let (bg, sym, tint): (Color, String, Color) = {
            switch cloudKitSyncService.accountStatus {
            case .available:
                if cloudKitSyncService.syncError != nil {
                    return (Color.uplift.ahkitOrange.opacity(0.18), "exclamationmark.icloud", Color.uplift.ahkitOrange)
                }
                return (Color.uplift.ahkitGreen.opacity(0.18), "icloud.fill", Color.uplift.ahkitGreen)
            case .noAccount:
                return (Color.uplift.ahkitOrange.opacity(0.18), "icloud.slash", Color.uplift.ahkitOrange)
            case .restricted, .temporarilyUnavailable:
                return (Color.uplift.fgFaint, "exclamationmark.icloud", Color.uplift.fgMuted)
            case .couldNotDetermine:
                return (Color.uplift.fgFaint, "icloud", Color.uplift.fgMuted)
            @unknown default:
                return (Color.uplift.fgFaint, "icloud.slash", Color.uplift.fgMuted)
            }
        }()
        return ZStack {
            Circle().fill(bg).frame(width: 28, height: 28)
            Image(systemName: sym)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
        }
    }

    @ViewBuilder
    private var iCloudLabel: some View {
        switch cloudKitSyncService.accountStatus {
        case .available:
            if cloudKitSyncService.isSyncing {
                Text("Syncing")
                    .font(.uplift.text(15, weight: .semibold))
                    .kerning(-0.2)
                    .foregroundStyle(Color.uplift.fg)
            } else if let error = cloudKitSyncService.syncError {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sync Error")
                        .font(.uplift.text(15, weight: .semibold))
                        .kerning(-0.2)
                        .foregroundStyle(Color.uplift.ahkitOrange)
                    Text(error)
                        .font(.uplift.text(12, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                        .lineLimit(2)
                }
            } else {
                Text("iCloud Sync Active")
                    .font(.uplift.text(15, weight: .semibold))
                    .kerning(-0.2)
                    .foregroundStyle(Color.uplift.ahkitGreen)
            }
        case .noAccount:
            VStack(alignment: .leading, spacing: 2) {
                Text("iCloud Not Signed In")
                    .font(.uplift.text(15, weight: .semibold))
                    .kerning(-0.2)
                    .foregroundStyle(Color.uplift.ahkitOrange)
                Text("Sign in to iCloud in Settings to sync your workout data across devices.")
                    .font(.uplift.text(12, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
                    .lineLimit(2)
            }
        case .restricted:
            Text("iCloud Restricted")
                .font(.uplift.text(15, weight: .semibold))
                .kerning(-0.2)
                .foregroundStyle(Color.uplift.fgMuted)
        case .temporarilyUnavailable:
            Text("iCloud Temporarily Unavailable")
                .font(.uplift.text(15, weight: .semibold))
                .kerning(-0.2)
                .foregroundStyle(Color.uplift.fgMuted)
        case .couldNotDetermine:
            Text("Checking iCloud Status...")
                .font(.uplift.text(15, weight: .semibold))
                .kerning(-0.2)
                .foregroundStyle(Color.uplift.fgMuted)
        @unknown default:
            Text("iCloud Unavailable")
                .font(.uplift.text(15, weight: .semibold))
                .kerning(-0.2)
                .foregroundStyle(Color.uplift.fgMuted)
        }
    }

    @ViewBuilder
    private var iCloudTrailing: some View {
        if cloudKitSyncService.accountStatus == .available,
           cloudKitSyncService.syncError == nil,
           !cloudKitSyncService.isSyncing,
           let lastSync = cloudKitSyncService.lastSyncDate {
            Text(lastSync, style: .relative)
                .font(.uplift.text(11, weight: .medium))
                .foregroundStyle(Color.uplift.fgMuted)
                .monospacedDigit()
        } else if cloudKitSyncService.isSyncing {
            ProgressView()
                .scaleEffect(0.8)
                .tint(Color.uplift.fgMuted)
        }
    }

    // MARK: - Data Management Section

    private var dataManagementSection: some View {
        SettingsSection(
            header: "Data Management",
            footer: "Export a complete backup of your data as a JSON file for safekeeping or to transfer to another device. Restoring replaces all current data."
        ) {
            VStack(spacing: 0) {
                dataRow(icon: "square.and.arrow.up", iconColor: Color.uplift.accent, label: "Export Backup", action: exportBackup)
                Divider().background(Color.uplift.hairline)
                dataRow(icon: "square.and.arrow.down", iconColor: Color.uplift.ahkitOrange, label: "Restore from Backup", action: { isImporting = true })
            }
            .background(Color.uplift.surface1, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func dataRow(icon: String, iconColor: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 24)
                Text(label)
                    .font(.uplift.text(15, weight: .semibold))
                    .kerning(-0.2)
                    .foregroundStyle(iconColor)
                Spacer()
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func exportBackup() {
        do {
            let data = try BackupService.export(context: modelContext)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let filename = "strength-training-backup-\(formatter.string(from: .now)).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url)

            // Present UIActivityViewController directly from root — embedding it in a
            // SwiftUI .sheet causes a nested modal that renders blank.
            guard let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows.first?.rootViewController else { return }

            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            rootVC.present(activityVC, animated: true)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Could not access the selected file."
                showError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                pendingRestoreData = try Data(contentsOf: url)
                showRestoreConfirmation = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func performRestore(data: Data) {
        do {
            try BackupService.restore(from: data, context: modelContext)
            successMessage = "Backup restored successfully."
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
