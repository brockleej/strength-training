//
//  WorkoutFormat.swift
//  RockLog
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

    /// "135×5 · 225×4 · −50×8w" — plan or last-session recipe.
    static func setRecipe(_ sets: [SetRecord]) -> String {
        let ordered = sets.sorted { $0.setNumber < $1.setNumber }
        guard !ordered.isEmpty else { return "" }
        return ordered.map { set in
            let w = set.isAssisted
                ? "−\(StepperLogic.format(set.weightLbs))"
                : StepperLogic.format(set.weightLbs)
            var piece = "\(w)×\(set.reps)"
            if set.isEachSide { piece += "ea" }
            return set.isWarmup ? "\(piece)w" : piece
        }
        .joined(separator: " · ")
    }
}
