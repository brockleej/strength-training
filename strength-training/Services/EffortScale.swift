//
//  EffortScale.swift
//  strength-training
//
//  Shared 1–10 effort bands: Easy (1–3) / Moderate (4–6) / Hard (7–8) /
//  All Out (9–10), with the green→red color progression. Used by the
//  rating sheet, the Workout Summary chip, and History's session detail.
//

import SwiftUI

enum EffortScale {
    static func label(for rating: Int) -> String {
        switch rating {
        case 1...3: "Easy"
        case 4...6: "Moderate"
        case 7, 8: "Hard"
        case 9, 10: "All Out"
        default: ""
        }
    }

    static func color(for rating: Int) -> Color {
        switch rating {
        case 1...3: .green
        case 4...6: .yellow
        case 7, 8: .orange
        default: .red
        }
    }
}
