//
//  WorkoutFormat.swift
//  strength-training
//
//  Small pure formatters shared by the workout screens.
//

import Foundation

enum WorkoutFormat {

    /// "18:42" / "1:02:05" / "0:00".
    static func elapsed(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}
