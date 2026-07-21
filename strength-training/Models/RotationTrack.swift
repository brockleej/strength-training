//
//  RotationTrack.swift
//  strength-training
//
//  A/B week labels on exercises and sessions. One calendar day type (e.g. Push)
//  can carry both A-week and B-week movements; the session filter shows Every + A
//  or Every + B so you don't need separate "Push A" / "Push B" day types.
//

import Foundation

enum RotationTrack: String, CaseIterable, Identifiable, Codable, Sendable {
    /// Always show — shared main lifts (bench, etc.).
    case every = ""
    case a = "A"
    case b = "B"

    var id: String { storageKey }

    /// UserDefaults / segmented-control id (empty string is awkward as a control id).
    var storageKey: String {
        switch self {
        case .every: "every"
        case .a: "A"
        case .b: "B"
        }
    }

    /// Short badge on rows: nil for Every.
    var badge: String? {
        switch self {
        case .every: nil
        case .a: "A"
        case .b: "B"
        }
    }

    var pickerLabel: String {
        switch self {
        case .every: "Every week"
        case .a: "A weeks"
        case .b: "B weeks"
        }
    }

    var sessionFilterLabel: String {
        switch self {
        case .every: "All"
        case .a: "A week"
        case .b: "B week"
        }
    }

    init(storage: String?) {
        switch (storage ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "A": self = .a
        case "B": self = .b
        case "EVERY", "ALL", "": self = .every
        default:
            // Legacy / unknown → treat as always-on so nothing disappears.
            self = .every
        }
    }

    init(storageKey: String) {
        switch storageKey {
        case "A": self = .a
        case "B": self = .b
        default: self = .every
        }
    }

    /// Whether this exercise should appear when the session is filtered to `sessionTrack`.
    /// - Session All: everything
    /// - Session A: Every + A
    /// - Session B: Every + B
    func isVisible(whenSessionTrack sessionTrack: RotationTrack) -> Bool {
        switch sessionTrack {
        case .every: return true
        case .a: return self == .every || self == .a
        case .b: return self == .every || self == .b
        }
    }

    /// Flip A↔B for the next week of the same day type; stay on A if last was All.
    var suggestedNext: RotationTrack {
        switch self {
        case .a: return .b
        case .b: return .a
        case .every: return .a
        }
    }

    static var sessionFilters: [RotationTrack] { [.a, .b, .every] }
    static var exerciseLabels: [RotationTrack] { [.every, .a, .b] }
}
