//
//  DashboardView.swift
//  ProgressionLab
//

import SwiftUI
import UniformTypeIdentifiers

struct DashboardView: View {
    @Bindable var store: SimulationStore
    let onClose: () -> Void

    @Environment(AppState.self) private var appState

    // Save dialog state
    @State private var savingSlot: ConfigSlot?
    @State private var savingName: String = ""
    @State private var savingDescription: String = ""
    @State private var saveError: String?

    var body: some View {
        VStack(spacing: 0) {
            header

            HStack(alignment: .top, spacing: 12) {
                ParameterPanel(
                    slot: store.configA,
                    accent: .blue,
                    onParametersChanged: { store.recompute() },
                    onSave: { presentSaveDialog(for: store.configA) },
                    onLoad: { presentLoadDialog(for: store.configA) }
                )
                ParameterPanel(
                    slot: store.configB,
                    accent: .orange,
                    onParametersChanged: { store.recompute() },
                    onSave: { presentSaveDialog(for: store.configB) },
                    onLoad: { presentLoadDialog(for: store.configB) }
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Divider()

            tableHeader
                .padding(.horizontal, 16)
                .padding(.vertical, 4)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(store.replays) { replay in
                        ExerciseDashboardRow(
                            replay: replay,
                            onSelect: { appState.selectedReplayID = replay.id }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
        .sheet(item: $savingSlot) { slot in
            saveDialog(for: slot)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("ProgressionLab").font(.title2).fontWeight(.semibold)
                Text(store.dataset.summary.displayLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open Different File") { onClose() }
        }
        .padding(16)
    }

    private var tableHeader: some View {
        HStack(spacing: 12) {
            Text("Exercise · Mode").frame(width: 220, alignment: .leading)
            Text("Sessions").frame(width: 50, alignment: .trailing)
            Text("History").frame(width: 80)
            Text("Config A: next").frame(width: 110, alignment: .leading)
            Text("Config B: next").frame(width: 110, alignment: .leading)
            Text("Disagree %").frame(width: 80, alignment: .trailing)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Save / Load

    private func presentSaveDialog(for slot: ConfigSlot) {
        savingName = slot.name
        savingDescription = ""
        saveError = nil
        savingSlot = slot
    }

    private func performSave(slot: ConfigSlot) {
        let artifact = ConfigArtifactWriter.build(
            name: savingName,
            description: savingDescription,
            parameters: slot.parameters,
            baseline: .productionModerate,
            baselineName: "productionModerate",
            dataset: store.dataset,
            replays: store.replays
        )
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = ConfigArtifactWriter.suggestedFilename(name: savingName)
        if let lastDir = lastUsedSaveDirectory() {
            panel.directoryURL = lastDir
        }
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try ConfigArtifactWriter.write(artifact, to: url)
                rememberSaveDirectory(url.deletingLastPathComponent())
                savingSlot = nil
            } catch {
                saveError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        } else {
            savingSlot = nil
        }
    }

    private func presentLoadDialog(for slot: ConfigSlot) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let lastDir = lastUsedSaveDirectory() {
            panel.directoryURL = lastDir
        }
        if panel.runModal() == .OK, let url = panel.url {
            let didStart = url.startAccessingSecurityScopedResource()
            defer { if didStart { url.stopAccessingSecurityScopedResource() } }
            do {
                let (params, name) = try ConfigArtifactReader.load(from: url)
                slot.parameters = params
                slot.name = name
                store.recompute()
            } catch {
                saveError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func lastUsedSaveDirectory() -> URL? {
        guard let bookmark = UserDefaults.standard.data(forKey: "ProgressionLab.lastSaveDir.bookmark.v1") else { return nil }
        var isStale = false
        return try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            bookmarkDataIsStale: &isStale
        )
    }

    private func rememberSaveDirectory(_ url: URL) {
        guard let data = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        UserDefaults.standard.set(data, forKey: "ProgressionLab.lastSaveDir.bookmark.v1")
    }

    @ViewBuilder
    private func saveDialog(for slot: ConfigSlot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Save \(slot.name)").font(.headline)
            Form {
                TextField("Name", text: $savingName)
                TextField("Description", text: $savingDescription, axis: .vertical)
                    .lineLimit(3...6)
            }
            if let error = saveError {
                Text(error).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel") { savingSlot = nil }
                Button("Save…") { performSave(slot: slot) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
