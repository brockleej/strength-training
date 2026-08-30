//
//  SessionPlanState.swift
//  strength-training
//
//  Planned days from a rocklog.program file vs trained (or skipped) work.
//

import Foundation

enum SessionPlanState: String, Codable, Sendable {
    /// Live or finished log — the historical default.
    case none = ""
    /// Imported target session; not started. Must not count as trained.
    case planned = "planned"
    /// Legacy: a calendar miss used to flip planned → skipped. Unused
    /// skipped rows stay in the queue and are healed back to planned.
    case skipped = "skipped"

    init(storage: String?) {
        switch (storage ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case SessionPlanState.planned.rawValue: self = .planned
        case SessionPlanState.skipped.rawValue: self = .skipped
        default: self = .none
        }
    }
}
