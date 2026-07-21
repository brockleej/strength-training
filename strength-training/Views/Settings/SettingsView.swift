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

    @AppStorage(RestTimerPreferences.enabledKey)
    private var restTimerEnabled: Bool = RestTimerPreferences.defaultEnabled

    @AppStorage(RestTimerPreferences.secondsKey)
    private var restTimerSeconds: Int = RestTimerPreferences.defaultSeconds

    @AppStorage(GymMembershipPreferences.codeKey)
    private var gymCode: String = ""

    @AppStorage(GymMembershipPreferences.labelKey)
    private var gymLabel: String = ""

    @AppStorage(GymMembershipPreferences.formatKey)
    private var gymFormatRaw: String = GymMembershipPreferences.Format.code128.rawValue

    @State private var showGymPass = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if healthKitService.isAvailable {
                        switch healthKitService.authorizationStatus {
                        case .none:
                            Button {
                                Task {
                                    await healthKitService.requestAuthorization()
                                }
                            } label: {
                                Label("Connect Apple Health", systemImage: "heart.fill")
                            }
                        case true?:
                            Label("Apple Health Connected", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(Color.uplift.ahGreen)
                        case false?:
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Apple Health Not Authorized", systemImage: "exclamationmark.triangle")
                                    .foregroundStyle(Color.uplift.customBadge)
                                Text("Open Settings > Privacy > Health to grant access.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Label("Apple Health Not Available", systemImage: "heart.slash")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    sectionHeader("Health")
                } footer: {
                    sectionFooter("When connected, workouts are saved to Apple Health for Activity Ring credit and fitness tracking.")
                }
                .listRowBackground(Color.uplift.surface1)

                Section {
                    UpliftSegmentedControl(
                        segments: ProgressionAggressiveness.allCases.map { mode in
                            UpliftSegment(id: mode.rawValue, label: mode.rawValue)
                        },
                        selection: $aggressiveness
                    )
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                } header: {
                    sectionHeader("Progressive Overload")
                } footer: {
                    sectionFooter("Moderate recommends a weight increase after 2 consistent sessions. Conservative requires 3.")
                }
                .listRowBackground(Color.uplift.surface1)

                Section {
                    NavigationLink {
                        TrainingSplitSettingsView()
                    } label: {
                        Label("Training Split", systemImage: "calendar")
                    }
                } header: {
                    sectionHeader("Training")
                } footer: {
                    sectionFooter("Choose a bro split, push/pull/legs, or define your own day types.")
                }
                .listRowBackground(Color.uplift.surface1)

                Section {
                    TextField("Label", text: $gymLabel, prompt: Text(GymMembershipPreferences.defaultLabel))
                        .font(.uplift.text(15, weight: .medium))
                        .foregroundStyle(Color.uplift.fg)
                        .textInputAutocapitalization(.words)

                    TextField("Member ID / barcode number", text: $gymCode)
                        .font(.uplift.mono(15, weight: .medium))
                        .foregroundStyle(Color.uplift.fg)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)

                    Picker("Format", selection: $gymFormatRaw) {
                        ForEach(GymMembershipPreferences.Format.allCases) { format in
                            Text(format.title).tag(format.rawValue)
                        }
                    }
                    .font(.uplift.text(15, weight: .medium))

                    Button {
                        showGymPass = true
                    } label: {
                        Label(
                            gymCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "Preview pass (add ID first)"
                                : "Show gym pass",
                            systemImage: "barcode.viewfinder"
                        )
                        .foregroundStyle(
                            gymCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.uplift.fgDim
                                : Color.uplift.accent
                        )
                    }
                    .disabled(gymCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } header: {
                    sectionHeader("Gym pass")
                } footer: {
                    sectionFooter("Paste the number under your membership barcode. Open the pass from Today (barcode button) at check-in — screen goes bright white for scanners.")
                }
                .listRowBackground(Color.uplift.surface1)

                Section {
                    Toggle(isOn: $restTimerEnabled) {
                        Label("Rest timer", systemImage: "timer")
                    }
                    .tint(Color.uplift.accent)

                    if restTimerEnabled {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Default rest")
                                    .font(.uplift.text(15, weight: .medium))
                                    .foregroundStyle(Color.uplift.fg)
                                Spacer()
                                Text(RestTimerPreferences.formatDuration(restTimerSeconds > 0 ? restTimerSeconds : RestTimerPreferences.defaultSeconds))
                                    .font(.uplift.mono(15, weight: .semibold))
                                    .foregroundStyle(Color.uplift.accent)
                            }

                            // 2×3 preset grid — easier to hit in the gym than a continuous slider
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8),
                            ], spacing: 8) {
                                ForEach(RestTimerPreferences.presets, id: \.self) { seconds in
                                    let selected = (restTimerSeconds > 0 ? restTimerSeconds : RestTimerPreferences.defaultSeconds) == seconds
                                    Button {
                                        restTimerSeconds = seconds
                                    } label: {
                                        Text(RestTimerPreferences.formatDuration(seconds))
                                            .font(.uplift.text(13, weight: .semibold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background {
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .fill(selected ? Color.uplift.accent.opacity(0.2) : Color.uplift.surface2)
                                            }
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .strokeBorder(selected ? Color.uplift.accent : Color.clear, lineWidth: 1)
                                            }
                                            .foregroundStyle(selected ? Color.uplift.accent : Color.uplift.fgMuted)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    sectionHeader("Rest Timer")
                } footer: {
                    sectionFooter("Starts after each logged set on the Focus screen. You can still turn it off mid-session.")
                }
                .listRowBackground(Color.uplift.surface1)

                iCloudSyncSection

                Section {
                    Button(action: exportBackup) {
                        Label("Export Backup", systemImage: "square.and.arrow.up")
                            .foregroundStyle(Color.uplift.accent)
                    }

                    Button {
                        isImporting = true
                    } label: {
                        Label("Restore from Backup", systemImage: "square.and.arrow.down")
                            .foregroundStyle(Color.uplift.customBadge)
                    }
                } header: {
                    sectionHeader("Data Management")
                } footer: {
                    sectionFooter("Export a complete backup of your data as a JSON file for safekeeping or to transfer to another device. Restoring replaces all current data.")
                }
                .listRowBackground(Color.uplift.surface1)
            }
            .scrollContentBackground(.hidden)
            .background(Color.uplift.bgElev)
            .navigationTitle("Settings")
            .fullScreenCover(isPresented: $showGymPass) {
                GymPassView()
            }
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

    // MARK: - iCloud Sync Section

    @ViewBuilder
    private var iCloudSyncSection: some View {
        Section {
            if !CloudKitSyncService.isEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Local Storage Only", systemImage: "iphone")
                        .foregroundStyle(Color.uplift.fgMuted)
                    Text("iCloud sync is off in this build (Personal Team cannot use CloudKit). Use Export Backup to keep a copy.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                switch cloudKitSyncService.accountStatus {
                case .available:
                    if cloudKitSyncService.isSyncing {
                        HStack {
                            Label("Syncing", systemImage: "arrow.triangle.2.circlepath.icloud")
                            Spacer()
                            ProgressView()
                        }
                    } else if let error = cloudKitSyncService.syncError {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Sync Error", systemImage: "exclamationmark.icloud")
                                .foregroundStyle(Color.uplift.customBadge)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack {
                            Label("iCloud Sync Active", systemImage: "checkmark.icloud.fill")
                                .foregroundStyle(Color.uplift.ahGreen)
                            Spacer()
                            if let lastSync = cloudKitSyncService.lastSyncDate {
                                Text(lastSync, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                case .noAccount:
                    VStack(alignment: .leading, spacing: 4) {
                        Label("iCloud Not Signed In", systemImage: "icloud.slash")
                            .foregroundStyle(Color.uplift.customBadge)
                        Text("Sign in to iCloud in Settings to sync your workout data across devices.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                case .restricted:
                    Label("iCloud Restricted", systemImage: "exclamationmark.icloud")
                        .foregroundStyle(.secondary)

                case .temporarilyUnavailable:
                    Label("iCloud Temporarily Unavailable", systemImage: "exclamationmark.icloud")
                        .foregroundStyle(.secondary)

                case .couldNotDetermine:
                    Label("Checking iCloud Status...", systemImage: "icloud")
                        .foregroundStyle(.secondary)

                @unknown default:
                    Label("iCloud Unavailable", systemImage: "icloud.slash")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            sectionHeader("iCloud Sync")
        } footer: {
            sectionFooter(
                CloudKitSyncService.isEnabled
                    ? "Your workout data automatically syncs to iCloud and is available across all your devices."
                    : "Workouts are stored on this device only. Export a backup from Data Management below."
            )
        }
        .listRowBackground(Color.uplift.surface1)
    }

    // MARK: - Section text styling

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .textCase(.uppercase)
            .font(.uplift.text(11, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(Color.uplift.fgMuted)
    }

    private func sectionFooter(_ text: String) -> some View {
        Text(text)
            .font(.uplift.text(12, weight: .medium))
            .foregroundStyle(Color.uplift.fgDim)
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
