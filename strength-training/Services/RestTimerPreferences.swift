//
//  RestTimerPreferences.swift
//  strength-training
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
        if UserDefaults.standard.object(forKey: enabledKey) == nil {
            return defaultEnabled
        }
        return UserDefaults.standard.bool(forKey: enabledKey)
    }

    /// Audible countdown ticks + done chirp (still haptics when sound is off).
    static var isSoundEnabled: Bool {
        if UserDefaults.standard.object(forKey: soundEnabledKey) == nil {
            return defaultSoundEnabled
        }
        return UserDefaults.standard.bool(forKey: soundEnabledKey)
    }

    static var targetSeconds: Int {
        let value = UserDefaults.standard.integer(forKey: secondsKey)
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
        if UserDefaults.standard.object(forKey: key) == nil {
            return isEnabled
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    static func setEnabled(_ enabled: Bool, forExercise id: UUID) {
        UserDefaults.standard.set(enabled, forKey: exerciseEnabledKey(for: id))
    }
}
