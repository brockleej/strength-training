//
//  SetPrefillPreferences.swift
//  strength-training
//
//  How steppers seed the *next* set after logging (and the first set of a lift).
//

import Foundation

/// Where the Focus weight/reps steppers get their next values.
enum SetPrefillMode: String, CaseIterable, Identifiable {
    /// Copy the set you just logged (good for straight sets: 225×5, 225×5…).
    case repeatLast
    /// Use last session’s set at the same position (good for ramps: 135 → 225 → 315).
    case matchHistory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .repeatLast: return "Last set"
        case .matchHistory: return "Last session"
        }
    }

    var detail: String {
        switch self {
        case .repeatLast:
            return "After each set, keep the same weight and reps (classic straight sets)."
        case .matchHistory:
            return "After each set, load weight and reps from the same set number last time (warm-up ramps)."
        }
    }
}

enum SetPrefillPreferences {
    static let modeKey = "setPrefillMode"

    /// Default: match last session by set # — better for progressive warm-ups.
    static let defaultMode: SetPrefillMode = .matchHistory

    static var mode: SetPrefillMode {
        get {
            let raw = UserDefaults.standard.string(forKey: modeKey) ?? ""
            return SetPrefillMode(rawValue: raw) ?? defaultMode
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: modeKey)
        }
    }
}
