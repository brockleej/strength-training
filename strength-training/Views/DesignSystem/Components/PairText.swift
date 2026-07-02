//
//  PairText.swift
//  strength-training
//
//  Canonical "weight × reps" rendering: weight always first, weight numerals
//  in weightTint (ice), reps in repsTint (white), separators dim. One place
//  to change the convention.
//

import SwiftUI

enum PairText {
    /// "225 × 5" or "225 × 5 · 5 · 4" (a same-weight run).
    static func pair(weight: Double, reps: [Int], font: Font) -> Text {
        var text = Text(StepperLogic.format(weight)).font(font).foregroundColor(.uplift.weightTint)
        text = text + Text(" × ").font(font).foregroundColor(.uplift.fgDim)
        for (index, rep) in reps.enumerated() {
            if index > 0 {
                text = text + Text(" · ").font(font).foregroundColor(.uplift.fgDim)
            }
            text = text + Text("\(rep)").font(font).foregroundColor(.uplift.repsTint)
        }
        return text
    }

    static func pair(weight: Double, reps: Int, font: Font) -> Text {
        pair(weight: weight, reps: [reps], font: font)
    }
}
