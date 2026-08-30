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
    /// Dated plan the athlete never logged. Still not trained work.
    case skipped = "skipped"

    init(storage: String?) {
        switch (storage ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case SessionPlanState.planned.rawValue: self = .planned
        case SessionPlanState.skipped.rawValue: self = .skipped
        default: self = .none
        }
    }
}
