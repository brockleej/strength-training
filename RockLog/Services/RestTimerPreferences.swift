//
//  RestTimerPreferences.swift
//  RockLog
//
//  UserDefaults-backed rest timer defaults (Focus screen).
//

import Foundation

enum RestTimerPreferences {
    static let enabledKey = "restTimerEnabled"
    static let secondsKey = "restTimerSeconds"
    static let soundEnabledKey = "restTimerSoundEnabled"

    static let defaultEnabled = true
    static let defaultSoundEnabled = true
    /// 3 minutes — matches the original Focus default.
    static let defaultSeconds = 180

    /// Preset chips shown in Settings (seconds).
    static let presets: [Int] = [60, 90, 120, 180, 240, 300]

    static var isEnabled: Bool {
        if AppDefaults.local.object(forKey: enabledKey) == nil {
            return defaultEnabled
        }
        return AppDefaults.local.bool(forKey: enabledKey)
    }

    /// True when the End alert plays a sound (Chirp at zero or 5-second countdown).
    /// The old "Countdown sounds" key is read only as a migration input.
    static var isSoundEnabled: Bool {
        RestAlertPreferences.endAlert.playsSound
    }

    static var targetSeconds: Int {
        let value = AppDefaults.local.integer(forKey: secondsKey)
        return value > 0 ? value : defaultSeconds
    }

    static func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if secs == 0 { return "\(mins) min" }
        return "\(mins):\(String(format: "%02d", secs))"
    }

    // MARK: - Per-exercise on/off (supersets)

    /// Key for a per-exercise rest-timer override.
    static func exerciseEnabledKey(for id: UUID) -> String {
        "restTimerExerciseEnabled.\(id.uuidString)"
    }

    /// Whether rest should auto-start after logging a set on this exercise.
    /// Uses the exercise’s last choice when set; otherwise the global Settings default.
    static func isEnabled(forExercise id: UUID) -> Bool {
        let key = exerciseEnabledKey(for: id)
        if AppDefaults.local.object(forKey: key) == nil {
            return isEnabled
        }
        return AppDefaults.local.bool(forKey: key)
    }

    static func setEnabled(_ enabled: Bool, forExercise id: UUID) {
        AppDefaults.local.set(enabled, forKey: exerciseEnabledKey(for: id))
    }

    /// The later row of a duplicate exercise id keeps the per-lift switch.
    /// The original key stays so the first row does too.
    static func copyExerciseSetting(from old: UUID, to new: UUID) {
        let oldKey = exerciseEnabledKey(for: old)
        guard AppDefaults.local.object(forKey: oldKey) != nil else { return }
        setEnabled(AppDefaults.local.bool(forKey: oldKey), forExercise: new)
    }

    static func discardExerciseSetting(_ id: UUID) {
        AppDefaults.local.removeObject(forKey: exerciseEnabledKey(for: id))
    }
}
