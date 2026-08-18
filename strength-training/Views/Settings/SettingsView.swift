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
    @Environment(\.scenePhase) private var scenePhase
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

    @AppStorage(SplitSchedulePreferences.modeKey)
    private var splitScheduleModeRaw: String = SplitScheduleMode.rolling.rawValue

    @AppStorage(RestTimerPreferences.enabledKey)
    private var restTimerEnabled: Bool = RestTimerPreferences.defaultEnabled

    @AppStorage(RestTimerPreferences.secondsKey)
    private var restTimerSeconds: Int = RestTimerPreferences.defaultSeconds

    @AppStorage(RestTimerPreferences.soundEnabledKey)
    private var restTimerSoundEnabled: Bool = RestTimerPreferences.defaultSoundEnabled

    @AppStorage(SetPrefillPreferences.modeKey)
    private var setPrefillModeRaw: String = SetPrefillPreferences.defaultMode.rawValue

    @AppStorage(CoachAthletePreferences.enabledKey)
    private var coachFeaturesEnabled: Bool = false

    @AppStorage(CoachAthletePreferences.nameKey)
    private var coachDisplayName: String = ""

    @AppStorage(CoachAthletePreferences.shareAfterFinishKey)
    private var shareSessionWithCoach: Bool = false

    /// Body profile drafts — edit freely, then Save (zeros/empty fields are easier than live Double bindings).
    @State private var draftWeightText = ""
    @State private var draftFeetText = ""
    @State private var draftInchesText = ""
    @State private var draftSexRaw: String = BiologicalSex.male.rawValue
    @State private var bodyProfileDirty = false
    @State private var showBodyProfileSaved = false

    @Bindable private var gymMembership = GymMembershipStore.shared

    @State private var showGymPass = false
    @State private var showWelcomeGuide = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        TrainingSplitSettingsView()
                    } label: {
                        Label("Edit training split", systemImage: "calendar")
                    }
                } header: {
                    sectionHeader("Training split")
                }
                .listRowBackground(Color.uplift.surface1)

                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Today’s day schedule")
                            .font(.uplift.text(15, weight: .semibold))
                            .foregroundStyle(Color.uplift.fg)
                        UpliftSegmentedControl(
                            segments: SplitScheduleMode.allCases.map {
                                UpliftSegment(id: $0.rawValue, label: $0.shortTitle)
                            },
                            selection: $splitScheduleModeRaw
                        )
                        Text((SplitScheduleMode(rawValue: splitScheduleModeRaw) ?? .rolling).detail)
                            .font(.uplift.text(12, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                } header: {
                    sectionHeader("Rolling / Weekly")
                }
                .listRowBackground(Color.uplift.surface1)

                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Next set defaults to")
                            .font(.uplift.text(15, weight: .semibold))
                            .foregroundStyle(Color.uplift.fg)
                        UpliftSegmentedControl(
                            segments: SetPrefillMode.allCases.map {
                                UpliftSegment(id: $0.rawValue, label: $0.title)
                            },
                            selection: $setPrefillModeRaw
                        )
                        Text((SetPrefillMode(rawValue: setPrefillModeRaw) ?? SetPrefillPreferences.defaultMode).detail)
                            .font(.uplift.text(12, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                } header: {
                    sectionHeader("Next set default")
                }
                .listRowBackground(Color.uplift.surface1)

                Section {
                    UpliftSegmentedControl(
                        segments: ProgressionAggressiveness.allCases.map { mode in
                            UpliftSegment(id: mode.rawValue, label: mode.rawValue)
                        },
                        selection: $aggressiveness
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .padding(.vertical, 4)
                } header: {
                    sectionHeader("Progression")
                } footer: {
                    sectionFooter("How quickly weight or reps go up after consistent sessions. Moderate ≈ after 2; Conservative ≈ after 3.")
                }
                .listRowBackground(Color.uplift.surface1)

                Section {
                    Toggle(isOn: $restTimerEnabled) {
                        Label("Rest timer", systemImage: "timer")
                    }
                    .tint(Color.uplift.accent)

                    if restTimerEnabled {
                        Toggle(isOn: $restTimerSoundEnabled) {
                            Label("Countdown sounds", systemImage: "speaker.wave.2.fill")
                        }
                        .tint(Color.uplift.accent)

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
                    sectionHeader("Timer")
                } footer: {
                    sectionFooter("Default length for new lifts. On Focus you can turn rest on/off per exercise (useful for supersets). Sounds are ticks then a go chirp; off = haptics only.")
                }
                .listRowBackground(Color.uplift.surface1)

                Section {
                    HStack {
                        Label("Weight", systemImage: "scalemass.fill")
                            .font(.uplift.text(15, weight: .medium))
                            .foregroundStyle(Color.uplift.fg)
                        Spacer()
                        TextField("e.g. 185", text: $draftWeightText)
                            .font(.uplift.mono(15, weight: .semibold))
                            .foregroundStyle(Color.uplift.accent)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .frame(minWidth: 72, maxWidth: 96, alignment: .trailing)
                            .onChange(of: draftWeightText) { _, _ in bodyProfileDirty = true }
                        Text("lb")
                            .font(.uplift.text(13, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                    }

                    HStack {
                        Label("Height", systemImage: "ruler")
                            .font(.uplift.text(15, weight: .medium))
                            .foregroundStyle(Color.uplift.fg)
                        Spacer()
                        TextField("ft", text: $draftFeetText)
                            .font(.uplift.mono(15, weight: .semibold))
                            .foregroundStyle(Color.uplift.accent)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .frame(width: 40)
                            .onChange(of: draftFeetText) { _, _ in bodyProfileDirty = true }
                        Text("ft")
                            .font(.uplift.text(13, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                        TextField("in", text: $draftInchesText)
                            .font(.uplift.mono(15, weight: .semibold))
                            .foregroundStyle(Color.uplift.accent)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .frame(width: 40)
                            .onChange(of: draftInchesText) { _, _ in bodyProfileDirty = true }
                        Text("in")
                            .font(.uplift.text(13, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sex (Navy formula)")
                            .font(.uplift.text(15, weight: .medium))
                            .foregroundStyle(Color.uplift.fg)
                        UpliftSegmentedControl(
                            segments: BiologicalSex.allCases.map {
                                UpliftSegment(id: $0.rawValue, label: $0.title)
                            },
                            selection: $draftSexRaw
                        )
                        .onChange(of: draftSexRaw) { _, _ in bodyProfileDirty = true }
                    }
                    .padding(.vertical, 4)

                    Button {
                        saveBodyProfileDraft()
                    } label: {
                        Label(
                            bodyProfileDirty ? "Save body profile" : "Body profile saved",
                            systemImage: bodyProfileDirty ? "checkmark.circle.fill" : "checkmark.circle"
                        )
                        .font(.uplift.text(15, weight: .semibold))
                        .foregroundStyle(bodyProfileDirty ? Color.uplift.accent : Color.uplift.fgDim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(!bodyProfileDirty)
                    .accessibilityHint("Saves weight, height, and sex to this device and iCloud")
                } header: {
                    sectionHeader("Body profile")
                } footer: {
                    sectionFooter("Save after editing. Weight is used for assisted lifts; height + sex unlock body-fat and FFMI on Progress. Trends only—not medical advice. Syncs with iCloud when available.")
                }
                .listRowBackground(Color.uplift.surface1)
                .onAppear { loadBodyProfileDraft() }

                Section {
                    TextField(
                        "Label",
                        text: $gymMembership.label,
                        prompt: Text(GymMembershipPreferences.defaultLabel)
                    )
                    .font(.uplift.text(15, weight: .medium))
                    .foregroundStyle(Color.uplift.fg)
                    .textInputAutocapitalization(.words)

                    TextField("Member ID / barcode number", text: $gymMembership.code)
                        .font(.uplift.mono(15, weight: .medium))
                        .foregroundStyle(Color.uplift.fg)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)

                    Picker("Format", selection: $gymMembership.formatRaw) {
                        ForEach(GymMembershipPreferences.Format.allCases) { format in
                            Text(format.title).tag(format.rawValue)
                        }
                    }
                    .font(.uplift.text(15, weight: .medium))

                    Button {
                        showGymPass = true
                    } label: {
                        Label(
                            gymMembership.isConfigured
                                ? "Show gym pass"
                                : "Preview pass (add ID first)",
                            systemImage: "barcode.viewfinder"
                        )
                        .foregroundStyle(
                            gymMembership.isConfigured
                                ? Color.uplift.accent
                                : Color.uplift.fgDim
                        )
                    }
                    .disabled(!gymMembership.isConfigured)
                } header: {
                    sectionHeader("Gym pass")
                } footer: {
                    sectionFooter("Number under your membership barcode. Syncs via iCloud. Open from Today’s barcode button at check-in.")
                }
                .listRowBackground(Color.uplift.surface1)

                Section {
                    Toggle(isOn: $coachFeaturesEnabled) {
                        Label("Use RockCoach", systemImage: "person.2")
                    }
                    .tint(Color.uplift.accent)

                    if coachFeaturesEnabled {
                        TextField(
                            "Your name on coach files",
                            text: $coachDisplayName,
                            prompt: Text(CoachAthletePreferences.defaultDisplayName)
                        )
                        .font(.uplift.text(15, weight: .medium))
                        .foregroundStyle(Color.uplift.fg)
                        .textInputAutocapitalization(.words)

                        Toggle(isOn: $shareSessionWithCoach) {
                            Label("Offer to send after finish", systemImage: "paperplane")
                        }
                        .tint(Color.uplift.accent)

                        Button(action: shareLastSessionWithCoach) {
                            Label("Send last workout to coach", systemImage: "paperplane")
                                .foregroundStyle(Color.uplift.accent)
                        }

                        Button(action: shareSinceLastShareWithCoach) {
                            Label("Send unsent workouts", systemImage: "clock.arrow.circlepath")
                                .foregroundStyle(Color.uplift.accent)
                        }
                    }
                } header: {
                    sectionHeader("RockCoach")
                } footer: {
                    sectionFooter(
                        coachFeaturesEnabled
                            ? "These files are for RockCoach — not a backup. Name appears on the file, not your Apple ID. One workout is a session file; two or more unsent go as one batch. Your coach imports it in RockCoach. Use Backup below to save or move your log."
                            : "Off by default. Turn on only if you send workouts to a coach in RockCoach."
                    )
                }
                .listRowBackground(Color.uplift.surface1)

                Section {
                    Button(action: exportBackup) {
                        Label("Export backup", systemImage: "square.and.arrow.up")
                            .foregroundStyle(Color.uplift.accent)
                    }

                    Button {
                        isImporting = true
                    } label: {
                        Label("Restore from backup", systemImage: "square.and.arrow.down")
                            .foregroundStyle(Color.uplift.customBadge)
                    }
                } header: {
                    sectionHeader("Backup")
                } footer: {
                    sectionFooter("This is your save/export — a JSON of this phone’s log. Restore replaces everything on this device. Coach files above cannot restore RockLog.")
                }
                .listRowBackground(Color.uplift.surface1)

                Section {
                    Button {
                        showWelcomeGuide = true
                    } label: {
                        Label("Welcome guide", systemImage: "book")
                            .foregroundStyle(Color.uplift.accent)
                    }
                } header: {
                    sectionHeader("Welcome guide")
                } footer: {
                    sectionFooter("Same pages as first launch: Today, logging (assist, sides, warm-up, Done), History, Progress.")
                }
                .listRowBackground(Color.uplift.surface1)

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
                            Button(action: openHealthSettings) {
                                Label("Apple Health Connected", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(Color.uplift.ahGreen)
                            }
                        case false?:
                            Button(action: openHealthSettings) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Label("Allow in Health settings", systemImage: "exclamationmark.triangle")
                                        .foregroundStyle(Color.uplift.customBadge)
                                    Text("Opens Settings so you can turn on RockLog under Health.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        Label("Apple Health Not Available", systemImage: "heart.slash")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    sectionHeader("Apple Health")
                } footer: {
                    sectionFooter("Saves finished workouts for Activity rings and fitness history. After the first ask, iOS only lets you change Health access in Settings.")
                }
                .listRowBackground(Color.uplift.surface1)
                .onAppear { healthKitService.checkAuthorization() }

                iCloudSyncSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.uplift.bgElev)
            // Number pads have no Return key — swipe/scroll must dismiss so tabs are reachable.
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                guard CloudKitSyncService.isEnabled else { return }
                await cloudKitSyncService.nudgeSync(modelContext: modelContext)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    healthKitService.checkAuthorization()
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        dismissKeyboard()
                    }
                    .fontWeight(.semibold)
                }
            }
            .fullScreenCover(isPresented: $showGymPass) {
                GymPassView()
            }
            .fullScreenCover(isPresented: $showWelcomeGuide) {
                FirstRunView { showWelcomeGuide = false }
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
            .alert("Body profile saved", isPresented: $showBodyProfileSaved) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Weight, height, and sex are saved on this device and synced with iCloud when available.")
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
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Couldn’t sync", systemImage: "exclamationmark.icloud")
                                .foregroundStyle(Color.uplift.customBadge)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            retrySyncButton
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
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
                            if let warning = cloudKitSyncService.lastExportWarning {
                                Text(warning)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            retrySyncButton
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
                    if !cloudKitSyncService.hasCheckedAccount {
                        Label("Checking iCloud Status…", systemImage: "icloud")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("iCloud Status Unknown", systemImage: "exclamationmark.icloud")
                                .foregroundStyle(Color.uplift.customBadge)
                            if let error = cloudKitSyncService.syncError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Could not determine account status. Check network and iCloud sign-in, then pull to refresh.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

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
                    ? "Workouts stay on this phone. iCloud copies them when it can. Tap Retry or pull to refresh to poke iCloud — a later “skipped some items” line after a green status is a retryable upload, not lost data."
                    : "Workouts stay on this device only. Use Backup → Export below for a copy."
            )
        }
        .listRowBackground(Color.uplift.surface1)
        .task {
            guard CloudKitSyncService.isEnabled else { return }
            await cloudKitSyncService.checkAccountStatus()
        }
    }

    private var retrySyncButton: some View {
        Button {
            Task { await cloudKitSyncService.nudgeSync(modelContext: modelContext) }
        } label: {
            Text("Retry sync")
                .font(.uplift.text(13, weight: .semibold))
                .foregroundStyle(Color.uplift.accent)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Checks iCloud and asks CloudKit to sync again")
    }

    // MARK: - Keyboard

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    /// HealthKit will not show the permission sheet again after a denial.
    /// The app’s Settings page is where iOS puts the Health toggle.
    private func openHealthSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Body profile draft

    private func loadBodyProfileDraft() {
        let store = BodyProfileStore.shared
        draftWeightText = store.weightPounds > 0
            ? Self.formatDraftNumber(store.weightPounds)
            : ""
        if store.heightInches > 0 {
            let total = Int(store.heightInches.rounded())
            draftFeetText = "\(total / 12)"
            draftInchesText = "\(total % 12)"
        } else {
            draftFeetText = ""
            draftInchesText = ""
        }
        draftSexRaw = store.sex.rawValue
        bodyProfileDirty = false
    }

    private func saveBodyProfileDraft() {
        let weight = Double(draftWeightText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let feet = Int(draftFeetText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let inchesPart = min(11, max(0, Int(draftInchesText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0))
        let height = Double(max(0, feet) * 12 + inchesPart)
        let sex = BiologicalSex(rawValue: draftSexRaw) ?? .male

        BodyProfileStore.shared.apply(
            weightPounds: max(0, weight),
            heightInches: height,
            sex: sex
        )
        // Normalize draft text after save (empty if cleared).
        loadBodyProfileDraft()
        showBodyProfileSaved = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private static func formatDraftNumber(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%g", value)
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
            ShareSheetPresenter.presentFile(url)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func shareLastSessionWithCoach() {
        do {
            var fetch = FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.isCompleted == true },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            fetch.fetchLimit = 1
            guard let session = try modelContext.fetch(fetch).first else {
                errorMessage = "No finished workout to send yet."
                showError = true
                return
            }
            CoachExportService.present(try CoachExportService.writePackage(for: [session]))
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func shareSinceLastShareWithCoach() {
        do {
            let completed = try modelContext.fetch(
                FetchDescriptor<WorkoutSession>(
                    predicate: #Predicate { $0.isCompleted == true },
                    sortBy: [SortDescriptor(\.date)]
                )
            )
            CoachExportService.present(try CoachExportService.writeUnsharedPackage(from: completed))
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
