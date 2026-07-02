//
//  WorkoutFormat.swift
//  strength-training
//
//  Small pure formatters shared by the workout screens.
//

import Foundation

enum WorkoutFormat {

    /// Exercise-row subtitle: "3 × 12 · 40 lb" (last session's sets × avg reps
    /// · target weight). Degrades gracefully; "—" when nothing is known.
    static func rowSubtitle(lastSets: Int?, reps: Int?, weight: Double?) -> String {
        let setsPart: String? = {
            guard let lastSets, let reps else { return nil }
            return "\(lastSets) × \(reps)"
        }()
        let weightPart = weight.map { "\(StepperLogic.format($0)) lb" }
        let parts = [setsPart, weightPart].compactMap { $0 }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

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
