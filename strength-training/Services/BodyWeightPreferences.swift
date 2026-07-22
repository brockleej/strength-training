//
//  BodyWeightPreferences.swift
//  strength-training
//
//  Body weight for assisted lifts (pull-ups, dips, etc.).
//  Used to compute effective load = bodyWeight − assistance.
//

import Foundation

enum BodyWeightPreferences {
    static let poundsKey = "bodyWeightPounds"

    /// 0 means not set.
    static var pounds: Double {
        get {
            let value = UserDefaults.standard.double(forKey: poundsKey)
            return value > 0 ? value : 0
        }
        set {
            if newValue > 0 {
                UserDefaults.standard.set(newValue, forKey: poundsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: poundsKey)
            }
        }
    }

    static var isSet: Bool { pounds > 0 }

    static func format(_ value: Double = pounds) -> String {
        guard value > 0 else { return "—" }
        return StepperLogic.format(value) + " lb"
    }
}

/// Per-exercise default for assist mode (pull-ups / dips / etc.).
enum ExerciseAssistPreferences {
    static func key(for id: UUID) -> String {
        "exerciseAssistMode.\(id.uuidString)"
    }

    static func prefersAssist(for id: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: key(for: id))
    }

    static func setPrefersAssist(_ enabled: Bool, for id: UUID) {
        UserDefaults.standard.set(enabled, forKey: key(for: id))
    }
}
