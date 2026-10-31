//
//  SetProgressLabel.swift
//  RockLog
//
//  "Set 2 of 4 · 2 more below" above the steppers, so it is clear more set
//  rows are further down the list (Lee, t290u).
//

import Foundation

nonisolated enum SetProgressLabel {
    static func text(loggedCount: Int, plannedCount: Int, editingSetNumber: Int? = nil) -> String {
        if let editingSetNumber {
            return plannedCount > 0
                ? "Editing set \(editingSetNumber) of \(max(plannedCount, loggedCount))"
                : "Editing set \(editingSetNumber)"
        }
        let next = max(0, loggedCount) + 1
        guard plannedCount > 0 else { return "Set \(next)" }
        guard next <= plannedCount else { return "Set \(next) · extra (\(plannedCount) planned)" }
        let below = plannedCount - next
        let base = "Set \(next) of \(plannedCount)"
        return below > 0 ? base + " · \(below) more below" : base + " · last planned"
    }
}
