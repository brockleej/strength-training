//
//  CoachStoredSession.swift
//  RockCoach
//

import Foundation
import SwiftData

@Model
final class CoachStoredSession {
    var id: UUID = UUID()
    var importedAt: Date = Date.now
    var startedAt: Date = Date.now
    var dayType: String = ""
    var rotationTrack: String = ""
    var effortRating: Int?
    var payload: Data = Data()

    var client: CoachClient?

    @Transient private var cachedDocument: CoachSessionDocument?

    init(document: CoachSessionDocument) {
        self.id = document.session.id
        self.importedAt = .now
        self.startedAt = document.session.startedAt
        self.dayType = document.session.dayType
        self.rotationTrack = document.session.rotationTrack ?? ""
        self.effortRating = document.session.effortRating
        self.payload = (try? CoachSessionCodec.encode(document)) ?? Data()
    }

    func apply(_ document: CoachSessionDocument) {
        startedAt = document.session.startedAt
        dayType = document.session.dayType
        rotationTrack = document.session.rotationTrack ?? ""
        effortRating = document.session.effortRating
        payload = (try? CoachSessionCodec.encode(document)) ?? payload
        importedAt = .now
        cachedDocument = document
    }

    var document: CoachSessionDocument? {
        if let cachedDocument { return cachedDocument }
        let decoded = try? CoachSessionCodec.decode(payload)
        cachedDocument = decoded
        return decoded
    }
}
