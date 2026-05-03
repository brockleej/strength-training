//
//  LoaderView.swift
//  ProgressionLab
//

import SwiftUI
import UniformTypeIdentifiers

struct LoaderView: View {
    @Environment(AppState.self) private var appState
    @State private var recents: [URL] = []
    @State private var isTargeted = false

    var body: some View {
        @Bindable var appStateBinding = appState

        VStack(spacing: 24) {
            Text("ProgressionLab")
                .font(.largeTitle)
                .fontWeight(.semibold)

            dropZone
                .frame(maxWidth: 600, maxHeight: 240)

            if let error = appStateBinding.loadError {
                Text(error)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
            }

            if !recents.isEmpty {
                recentFilesList
            }
        }
        .padding(40)
        .frame(minWidth: 700, minHeight: 500)
        .onAppear { recents = RecentFilesStore.load() }
    }

    private var dropZone: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Drop a strength-training backup JSON here")
                .font(.headline)
            Text("or")
                .foregroundStyle(.secondary)
            Button("Open File…") { openFilePicker() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
        )
        .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private var recentFilesList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(recents, id: \.self) { url in
                Button {
                    appState.attemptLoad(from: url)
                    recents = RecentFilesStore.load()
                } label: {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                        Text(url.lastPathComponent)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
            }
        }
        .frame(maxWidth: 600)
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            appState.attemptLoad(from: url)
            recents = RecentFilesStore.load()
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            DispatchQueue.main.async {
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                appState.attemptLoad(from: url)
                recents = RecentFilesStore.load()
            }
        }
        return true
    }
}
