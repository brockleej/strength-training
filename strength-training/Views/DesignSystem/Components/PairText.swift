//
//  PairText.swift
//  strength-training
//
//  Canonical "weight × reps" rendering: weight always first, weight numerals
//  in weightTint (ice), reps in repsTint (white), separators dim. One place
//  to change the convention.
//
//  Uses Text interpolation (iOS 26+) — `Text + Text` is deprecated.
//

import SwiftUI

enum PairText {
    /// "225 × 5" or "225 × 5 · 5 · 4" (a same-weight run). An empty `reps`
    /// renders the weight alone — no dangling separator.
    static func pair(weight: Double, reps: [Int], font: Font) -> Text {
        let weightPart = Text(StepperLogic.format(weight))
            .font(font)
            .foregroundStyle(Color.uplift.weightTint)
        guard !reps.isEmpty else { return weightPart }

        var result = Text("\(weightPart)\(Text(" × ").font(font).foregroundStyle(Color.uplift.fgDim))")
        for (index, rep) in reps.enumerated() {
            if index > 0 {
                result = Text("\(result)\(Text(" · ").font(font).foregroundStyle(Color.uplift.fgDim))")
            }
            result = Text("\(result)\(Text("\(rep)").font(font).foregroundStyle(Color.uplift.repsTint))")
        }
        return result
    }

    static func pair(weight: Double, reps: Int, font: Font) -> Text {
        pair(weight: weight, reps: [reps], font: font)
    }
}
