//
//  SetMutation.swift
//  strength-training
//
//  Remove a logged set from its record and keep set numbers contiguous.
//

import Foundation
import SwiftData

enum SetMutation {
    /// Deletes `set` from `record` (or from `set.exerciseRecord`) and renumbers 1…n.
    static func delete(_ set: SetRecord, from record: ExerciseRecord?, in context: ModelContext) {
        let owner = record ?? set.exerciseRecord
        owner?.sets?.removeAll { $0.id == set.id }
        context.delete(set)
        guard let owner else { return }
        let remaining = owner.setsArray.sorted { $0.setNumber < $1.setNumber }
        for (index, remainingSet) in remaining.enumerated() {
            remainingSet.setNumber = index + 1
        }
    }
}
