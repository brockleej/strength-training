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

    static let defaultEnabled = true
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
}
