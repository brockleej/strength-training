//
//  PairText.swift
//  strength-training
//
//  Canonical "weight × reps" rendering: weight always first, weight numerals
//  in weightTint (ice), reps in repsTint (white), separators dim. One place
//  to change the convention.
//
//  Built with AttributedString — avoids deprecated Text + and nested Text
//  interpolation quirks on iOS 26.
//

import SwiftUI

enum PairText {
    /// "225 × 5" or "225 × 5 · 5 · 4" (a same-weight run). An empty `reps`
    /// renders the weight alone — no dangling separator.
    static func pair(weight: Double, reps: [Int], font: Font) -> Text {
        var result = AttributedString(StepperLogic.format(weight))
        result.font = font
        result.foregroundColor = Color.uplift.weightTint

        guard !reps.isEmpty else { return Text(result) }

        result.append(styled(" × ", font: font, color: Color.uplift.fgDim))
        for (index, rep) in reps.enumerated() {
            if index > 0 {
                result.append(styled(" · ", font: font, color: Color.uplift.fgDim))
            }
            result.append(styled("\(rep)", font: font, color: Color.uplift.repsTint))
        }
        return Text(result)
    }

    static func pair(weight: Double, reps: Int, font: Font) -> Text {
        pair(weight: weight, reps: [reps], font: font)
    }

    private static func styled(_ string: String, font: Font, color: Color) -> AttributedString {
        var part = AttributedString(string)
        part.font = font
        part.foregroundColor = color
        return part
    }
}
