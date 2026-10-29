//
//  RestAlertPreferences.swift
//  RockLog
//
//  Phone-local rest choices. They are not SwiftData and they are not in the backup.
//

import Foundation

enum RestAlertPreferences {
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
