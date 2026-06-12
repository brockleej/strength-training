//
//  Num.swift
//  strength-training
//
//  Hero-numeral wrapper: SF Pro Display + tabular digits + tight tracking.
//  Use for stat values, stepper values, score headlines, the PR number.
//  Small inline data numerals should use Font.uplift.mono directly instead.
//

import SwiftUI

struct Num: View {
    let text: String
    let size: CGFloat
    let weight: Font.Weight
    let color: Color

    init(_ text: String, size: CGFloat = 28, weight: Font.Weight = .bold, color: Color = .uplift.fg) {
        self.text = text
        self.size = size
        self.weight = weight
        self.color = color
    }

    init(_ value: Int, size: CGFloat = 28, weight: Font.Weight = .bold, color: Color = .uplift.fg) {
        self.init(String(value), size: size, weight: weight, color: color)
    }

    var body: some View {
        Text(text)
            .font(.uplift.display(size, weight: weight))
            .monospacedDigit()
            .kerning(size >= 36 ? -1.0 : -0.5)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

#Preview("Num") {
    VStack(spacing: 16) {
        Num(235, size: 120)
        Num("14,820", size: 42)
        Num("47.5", size: 40, color: .uplift.accent)
        Num(19, size: 22, weight: .semibold, color: .uplift.pr)
    }
    .padding(24)
    .frame(maxWidth: .infinity)
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
}
