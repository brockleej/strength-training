//
//  ImportInbox.swift
//  RockCoach
//

import Foundation
import Observation

@Observable
final class ImportInbox {
    static let shared = ImportInbox()

    var pending: PendingCoachImport?
    var errorMessage: String?
    var importedCount = 0

    private init() {}

    func receive(_ url: URL) {
        if url.scheme == "rockcoach" {
            drainQueuedFiles()
            return
        }
        do {
            let staged = try CoachInbox.stage(url)
            enqueue(try CoachImportService.file(from: staged))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func drainQueuedFiles() {
        let urls = CoachInbox.pendingURLs()
        guard !urls.isEmpty else { return }
        for url in urls {
            do {
                enqueue(try CoachImportService.file(from: url))
                CoachInbox.consume(url)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func enqueue(_ file: CoachFile) {
        let documents = file.sessionDocuments
        guard !documents.isEmpty else {
            errorMessage = "That file has no workouts."
            return
        }
        if let existing = pending, existing.athlete.id == file.athlete.id {
            pending = PendingCoachImport(
                athlete: file.athlete,
                documents: existing.documents + documents
            )
        } else {
            pending = PendingCoachImport(athlete: file.athlete, documents: documents)
        }
    }
}
