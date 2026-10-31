//
//  RestAlertPreferences.swift
//  RockLog
//
//  Phone-local rest choices. They are not SwiftData and they are not in the backup.
//

import Foundation

/// What happens when rest runs out. Sounds play only while RockLog is on screen and
/// duck (lower, not stop) other audio such as music or an audiobook.
nonisolated enum RestEndAlert: String, CaseIterable, Sendable {
    case chirp
    case countdown
    case buzz
    case off

    var title: String {
        switch self {
        case .chirp: "Chirp at zero"
        case .countdown: "5-second countdown beeps"
        case .buzz: "Buzz only"
        case .off: "Off"
        }
    }

    /// Chirp at zero (countdown also ends on the chirp).
    var playsSound: Bool { self == .chirp || self == .countdown }
    var beepsLastFive: Bool { self == .countdown }
    var buzzes: Bool { self != .off }

    /// Stored choice, else the old "Countdown sounds" switch (off → Buzz only), else Chirp.
    static func resolve(stored: String?, legacySoundEnabled: Bool?) -> RestEndAlert {
        if let stored, let alert = RestEndAlert(rawValue: stored) { return alert }
        if legacySoundEnabled == false { return .buzz }
        return .chirp
    }
}

enum RestAlertPreferences {
    static let endAlertKey = "restEndAlert"

    static var endAlert: RestEndAlert {
        get {
            let legacyKey = RestTimerPreferences.soundEnabledKey
            let legacy: Bool? = AppDefaults.local.object(forKey: legacyKey) == nil
                ? nil : AppDefaults.local.bool(forKey: legacyKey)
            return RestEndAlert.resolve(stored: AppDefaults.local.string(forKey: endAlertKey), legacySoundEnabled: legacy)
        }
        set { AppDefaults.local.set(newValue.rawValue, forKey: endAlertKey) }
    }

    /// Light tap when 10 seconds remain. Off until he turns it on.
    static let tapAtTenKey = "restTapAtTenSeconds"
    /// Ask to change a lift's rest only after enough real rests. Off until he turns it on.
    static let learningKey = "restLearningEnabled"

    static var tapAtTen: Bool {
        get { AppDefaults.local.bool(forKey: tapAtTenKey) }
        set { AppDefaults.local.set(newValue, forKey: tapAtTenKey) }
    }

    static var learningEnabled: Bool {
        get {
            guard FeatureFlags.restLearningPrompts else { return false }
            return AppDefaults.local.bool(forKey: learningKey)
        }
        set { AppDefaults.local.set(newValue, forKey: learningKey) }
    }
}

enum RestSampleStore {
    private static func key(_ exerciseID: UUID) -> String { "restSamples.\(exerciseID.uuidString)" }

    static func samples(for exerciseID: UUID) -> [Int] {
        let raw = AppDefaults.local.string(forKey: key(exerciseID)) ?? ""
        return raw.split(separator: ",").compactMap { Int($0) }
    }

    static func record(_ seconds: Int, for exerciseID: UUID) {
        var next = samples(for: exerciseID)
        next.append(seconds)
        if next.count > 24 { next.removeFirst(next.count - 24) }
        AppDefaults.local.set(next.map(String.init).joined(separator: ","), forKey: key(exerciseID))
    }

    /// Duplicate-id repair: the later row keeps the samples gathered under the shared id.
    static func copySamples(from old: UUID, to new: UUID) {
        let existing = samples(for: old)
        guard !existing.isEmpty else { return }
        AppDefaults.local.set(existing.map(String.init).joined(separator: ","), forKey: key(new))
    }

    static func discard(exerciseID: UUID) {
        AppDefaults.local.removeObject(forKey: key(exerciseID))
    }
}

/// Copies the old per-lift UserDefaults switch onto the exercise once.
enum RestPreferenceMigration {
    static func legacyKey(for exerciseID: UUID) -> String {
        "restTimerExerciseEnabled.\(exerciseID.uuidString)"
    }

    /// True when this call changed the exercise and the caller should save.
    @discardableResult
    static func copyIfNeeded(_ exercise: Exercise) -> Bool {
        guard !exercise.autoRestCopied else { return false }
        let key = legacyKey(for: exercise.id)
        if AppDefaults.local.object(forKey: key) != nil {
            exercise.autoRestEnabled = AppDefaults.local.bool(forKey: key)
        }
        exercise.autoRestCopied = true
        return true
    }
}
