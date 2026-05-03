//
//  AppState.swift
//  ProgressionLab
//

import Foundation
import Observation

@Observable
final class AppState {
    enum Screen {
        case loader
        case loaded(SimulationStore)
    }

    var screen: Screen = .loader
    var loadError: String?

    /// When non-nil while in the .loaded screen, render the detail view for the
    /// matching replay ID. Cleared by tapping "Back" in the detail header.
    var selectedReplayID: ExerciseModeReplay.ID?

    func attemptLoad(from url: URL) {
        loadError = nil
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }
        do {
            let dataset = try BackupLoader.load(from: url)
            RecentFilesStore.remember(url)
            screen = .loaded(SimulationStore(dataset: dataset))
        } catch {
            loadError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func returnToLoader() {
        screen = .loader
        selectedReplayID = nil
    }

    func clearSelection() {
        selectedReplayID = nil
    }
}
