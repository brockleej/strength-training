//
//  ProgressionLabApp.swift
//  ProgressionLab
//

import SwiftUI

@main
struct ProgressionLabApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
        .windowResizability(.contentSize)
    }
}

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        switch appState.screen {
        case .loader:
            LoaderView()
        case .loaded(let store):
            if let selectedID = appState.selectedReplayID,
               let replay = store.replays.first(where: { $0.id == selectedID }) {
                ExerciseDetailView(
                    replay: replay,
                    configAName: store.configA.name,
                    configBName: store.configB.name,
                    onBack: { appState.clearSelection() }
                )
            } else {
                DashboardView(store: store, onClose: appState.returnToLoader)
            }
        }
    }
}
