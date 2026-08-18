//
//  CoachImportService.swift
//  RockCoach
//

import Foundation
import SwiftData

enum CoachImportError: LocalizedError {
    case unreadableFile(String)
    case emptyFile

    var errorDescription: String? {
        switch self {
        case .unreadableFile(let detail):
            return "Couldn’t read that file. \(detail)"
        case .emptyFile:
            return "That file was empty. In Messages, tap the attachment, then Open in RockCoach."
        }
    }
}

struct PendingCoachImport: Identifiable {
    var id: UUID { athlete.id }
    var athlete: CoachAthlete
    var documents: [CoachSessionDocument]
}

enum CoachImportService {
    static func file(from url: URL) throws -> CoachFile {
        do {
            let data = try CoachInbox.readData(from: url)
            guard !data.isEmpty else { throw CoachImportError.emptyFile }
            return try CoachSessionCodec.decodeFile(data)
        } catch let error as CoachSessionDocument.CoachFormatError {
            throw error
        } catch let error as CoachImportError {
            throw error
        } catch {
            throw CoachImportError.unreadableFile(error.localizedDescription)
        }
    }

    static func matchingClient(for athlete: CoachAthlete, in context: ModelContext) -> CoachClient? {
        let athleteID = athlete.id
        let name = athlete.displayName
        let clients = (try? context.fetch(FetchDescriptor<CoachClient>())) ?? []
        if let byID = clients.first(where: { $0.athleteID == athleteID }) {
            return byID
        }
        return clients.first {
            $0.displayName.caseInsensitiveCompare(name) == .orderedSame
        }
    }

    @discardableResult
    static func upsert(
        _ documents: [CoachSessionDocument],
        into context: ModelContext,
        client: CoachClient
    ) throws -> [CoachStoredSession] {
        guard let first = documents.first else { return [] }
        if client.athleteID == nil {
            client.athleteID = first.athlete.id
        }
        var stored: [CoachStoredSession] = []
        for document in documents {
            if let existing = client.sessionsArray.first(where: { $0.id == document.session.id }) {
                existing.apply(document)
                stored.append(existing)
            } else {
                let row = CoachStoredSession(document: document)
                row.client = client
                context.insert(row)
                stored.append(row)
            }
        }
        refreshSummary(client)
        try context.save()
        return stored
    }

    static func refreshSummary(_ client: CoachClient) {
        let sessions = client.sortedSessions
        client.sessionCount = sessions.count
        client.lastSessionAt = sessions.first?.startedAt
        client.lastSessionDayType = sessions.first?.dayType ?? ""
    }

    @discardableResult
    static func upsert(
        _ document: CoachSessionDocument,
        into context: ModelContext,
        client: CoachClient
    ) throws -> CoachStoredSession {
        try upsert([document], into: context, client: client)[0]
    }

    static func makeClient(named name: String, athleteID: UUID, in context: ModelContext) throws -> CoachClient {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let client = CoachClient(
            displayName: trimmed.isEmpty ? "Client" : trimmed,
            athleteID: athleteID
        )
        context.insert(client)
        try context.save()
        return client
    }
}
