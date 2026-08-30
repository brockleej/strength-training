//
//  Theme.swift
//  RockCoach — dark companion palette (ice accent, related to RockLog).
//

import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    enum coach {
        static let bg = Color(hex: 0x0E1014)
        static let surface = Color(hex: 0x161A20)
        static let surface2 = Color(hex: 0x1F242C)
        static let fg = Color.white
        static let muted = Color(hex: 0xEBEBF5, opacity: 0.62)
        static let dim = Color(hex: 0xEBEBF5, opacity: 0.38)
        static let faint = Color(hex: 0xEBEBF5, opacity: 0.14)
        static let accent = Color(hex: 0x5AB8F5)
        static let onAccent = Color(hex: 0x001220)
        static let up = Color(hex: 0x34D399)
        static let down = Color(hex: 0xFB7185)
        static let flat = Color(hex: 0xEBEBF5, opacity: 0.5)
    }
}
