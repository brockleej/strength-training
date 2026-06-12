//
//  Typography.swift
//  strength-training
//
//  Font roles for the Refined Native design system.
//  Display = SF Pro Display (headlines + hero numerals; the system picks
//  Display automatically at large sizes). Mono = SF Mono (data numerals,
//  live-ticking values). Text = SF Pro Text (body).
//

import SwiftUI

extension Font {
    enum uplift {
        /// Headlines and hero numerals (28–120pt).
        /// At sizes below ~20pt the system serves SF Pro Text — use `text()` instead.
        static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
            .system(size: size, weight: weight)
        }

        /// Body and labels (10–17pt).
        static func text(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
            .system(size: size, weight: weight)
        }

        /// Data numerals and ticking values.
        static func mono(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
    }
}
