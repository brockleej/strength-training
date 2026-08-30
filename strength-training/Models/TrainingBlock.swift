//
//  TrainingBlock.swift
//  strength-training
//
//  An imported training block (rocklog.program.v1). Sessions hang off
//  WorkoutSession.trainingBlock; deleting a block does not delete history.
//

import Foundation
import SwiftData

@Model
final class TrainingBlock {
    var id: UUID = UUID()
    var name: String = ""
    var notes: String = ""
    var startDate: Date = Date.now
    var importedAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.trainingBlock)
    var sessions: [WorkoutSession]?

    var sessionsArray: [WorkoutSession] { sessions ?? [] }

    init(name: String, startDate: Date, notes: String = "") {
        self.id = UUID()
        self.name = name
        self.notes = notes
        self.startDate = startDate
        self.importedAt = .now
        self.sessions = []
    }
}
