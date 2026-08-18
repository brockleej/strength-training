//
//  CoachClient.swift
//  RockCoach
//

import Foundation
import SwiftData

@Model
final class CoachClient {
    var id: UUID = UUID()
    var displayName: String = ""
    /// Last athlete.id seen in an imported file. Used to match later exports.
    var athleteID: UUID?
    var notes: String = ""
    var createdAt: Date = Date.now
    /// Cached so the roster never faults every session payload on launch.
    var lastSessionDayType: String = ""
    var lastSessionAt: Date?
    var sessionCount: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \CoachStoredSession.client)
    var sessions: [CoachStoredSession]?

    var sessionsArray: [CoachStoredSession] { sessions ?? [] }

    var sortedSessions: [CoachStoredSession] {
        sessionsArray.sorted { $0.startedAt > $1.startedAt }
    }

    init(displayName: String, athleteID: UUID? = nil) {
        self.id = UUID()
        self.displayName = displayName
        self.athleteID = athleteID
        self.notes = ""
        self.createdAt = .now
        self.sessions = []
    }
}
