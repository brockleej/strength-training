//
//  ModelSave.swift
//  RockLog
//
//  One save path. Failures log the action name only — never a lift, a name, or a note.
//

import Foundation
import SwiftData

enum ModelSave {
    /// Tests set this to read failure lines. Production leaves it nil.
    static var record: ((String) -> Void)?

    static func failureLine(action: String, error: Error) -> String {
        "save failed: \(action) (\(String(describing: type(of: error))))"
    }

    static func logged(_ context: ModelContext, action: String) {
        do {
            try context.save()
        } catch {
            let line = failureLine(action: action, error: error)
            record?(line)
        }
    }
}
