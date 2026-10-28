//
//  ProgramsHubView.swift
//  RockLog
//
//  Program import, the training split, and day plans. Opened from the Workout tab.
//

import SwiftUI
import SwiftData
internal import UniformTypeIdentifiers

struct ProgramsHubView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SplitDay.sortOrder) private var days: [SplitDay]
    @AppStorage(SplitSchedulePreferences.modeKey)
    private var splitScheduleModeRaw: String = SplitScheduleMode.rolling.rawValue

    @State private var isImporting = false
    @State private var pendingProgram: ProgramDocument?
    @State private var pendingProgramPrompt = RestorePrompt(
        title: "Add planned workouts?",
        message: ProgramImportService.confirmationMessage(weekCount: 8),
        confirmTitle: "Add workouts",
        cancelTitle: "Don't add"
    )
    @State private var showProgramConfirmation = false
    @State private var pendingSplitDocument: ProgramDocument?
    @State private var showImportSplitConfirm = false
    @State private var showClearPlannedConfirm = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successMessage = ""

    @Query(
        filter: #Predicate<WorkoutSession> {
            $0.isCompleted == false && ($0.planState == "planned" || $0.planState == "skipped")
        }
    )
    private var queuedPlannedSessions: [WorkoutSession]

    var body: some View {
        List {
            Section {
                NavigationLink {
                    TrainingSplitSettingsView()
                } label: {
                    Label("Edit training split", systemImage: "calendar")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .accessibilityIdentifier(AccessibilityID.settingsEditSplit)
            } header: {
                Text("Split")
            }
            .listRowBackground(Color.uplift.surface1)

            Section {
                UpliftSegmentedControl(
                    segments: SplitScheduleMode.allCases.map {
                        UpliftSegment(id: $0.rawValue, label: $0.shortTitle)
                    },
                    selection: $splitScheduleModeRaw
                )
                .accessibilityIdentifier(AccessibilityID.programsSchedule)
            } header: {
                Text("Today’s day schedule")
            }
            .listRowBackground(Color.uplift.surface1)

            Section {
                ForEach(days) { day in
                    NavigationLink {
                        DayPlanEditorView(dayType: day.asDayType)
                    } label: {
                        Text(day.name)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .accessibilityIdentifier(AccessibilityID.programsDay(day.name))
                }
            } header: {
                Text("Day plans")
            }
            .listRowBackground(Color.uplift.surface1)

            Section {
                Button {
                    isImporting = true
                } label: {
                    Label("Add planned workouts", systemImage: "calendar.badge.plus")
                        .foregroundStyle(Color.uplift.accent)
                }
                .accessibilityIdentifier(AccessibilityID.settingsAddPlanned)
                Button {
                    isImporting = true
                } label: {
                    Label("Import training split", systemImage: "rectangle.split.3x1")
                        .foregroundStyle(Color.uplift.accent)
                }
                .accessibilityIdentifier(AccessibilityID.settingsImportSplit)
                Button(action: shareInstructions) {
                    Label("Instructions for AI", systemImage: "doc.text")
                        .foregroundStyle(Color.uplift.accent)
                }
                .accessibilityIdentifier(AccessibilityID.programsInstructions)
                if !queuedPlannedSessions.isEmpty {
                    Button(role: .destructive) {
                        showClearPlannedConfirm = true
                    } label: {
                        Label("Remove unused planned workouts", systemImage: "trash")
                    }
                    .accessibilityIdentifier(AccessibilityID.programsClearPlanned)
                }
            } header: {
                Text("Import")
            }
            .listRowBackground(Color.uplift.surface1)
        }
        .settingsPage("Programs")
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json, .rockLogProgram],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert(pendingProgramPrompt.title, isPresented: $showProgramConfirmation) {
            Button(pendingProgramPrompt.cancelTitle) { pendingProgram = nil }
            Button(pendingProgramPrompt.confirmTitle) {
                if let document = pendingProgram {
                    importProgram(document)
                }
            }
        } message: {
            Text(pendingProgramPrompt.message)
        }
        .alert(ProgramImportService.importSplitTitle, isPresented: $showImportSplitConfirm) {
            Button(ProgramImportService.importSplitCancelTitle, role: .cancel) {}
            Button(ProgramImportService.importSplitConfirmTitle) {
                if let document = pendingSplitDocument {
                    importSplit(document)
                }
            }
        } message: {
            Text(ProgramImportService.importSplitMessage())
        }
        .confirmationDialog(
            "Remove unused planned workouts?",
            isPresented: $showClearPlannedConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove leftover plan", role: .destructive) {
                ProgramImportService.removeUnusedPlannedSessions(context: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deletes planned workouts you haven’t started. Finished workouts stay in History.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("Close", role: .cancel) {}
                .accessibilityIdentifier(AccessibilityID.screenClose)
        } message: {
            Text(successMessage)
        }
    }

    private func shareInstructions() {
        do {
            ShareSheetPresenter.presentFile(try ProgramAuthoringGuide.writeFile())
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
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
                let data = try Data(contentsOf: url)
                switch try IncomingRockLogFile.parse(data) {
                case .program(let document):
                    pendingProgram = document
                    pendingProgramPrompt = ProgramImportService.summarize(document).confirmationPrompt
                    showProgramConfirmation = true
                case .split(let document):
                    pendingSplitDocument = document
                    showImportSplitConfirm = true
                case .backup:
                    errorMessage = "That file is a backup. Restore it from Settings → Data & Backup."
                    showError = true
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func importSplit(_ document: ProgramDocument) {
        do {
            try ProgramImportService.importSplit(document, context: modelContext)
            successMessage = ProgramImportService.importSplitResultMessage(removedUnusedPlan: false)
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func importProgram(_ document: ProgramDocument) {
        do {
            _ = try ProgramImportService.importDocument(
                document,
                context: modelContext,
                shiftingStartTo: nil,
                replaceUnusedPlan: false
            )
            successMessage = "Planned workouts added."
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
