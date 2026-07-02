//
//  Tokens.swift
//  strength-training
//
//  UpLift v2 "Refined Native" color palette.
//  Source of truth: uplift-redesign/project/v2/tokens2.jsx
//

import SwiftUI

extension Color {
    /// Design-token hex initializer: `Color(hex: 0x5AB8F5)`.
    init(hex: UInt32, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    enum uplift {
        // Surfaces
        static let bg = Color(hex: 0x000000)
        static let bgElev = Color(hex: 0x0E1014)        // page background under cards
        static let surface1 = Color(hex: 0x161A20)      // card
        static let surface2 = Color(hex: 0x1F242C)      // nested / stepper buttons
        static let surface3 = Color(hex: 0x2A3038)      // pressed / active / segmented thumb
        static let pillBg = Color(hex: 0x1C1E24, opacity: 0.85)   // floating pill bars
        static let hairline = Color(hex: 0xFFFFFF, opacity: 0.06)
        static let hairlineStrong = Color(hex: 0xFFFFFF, opacity: 0.10)

        // Foreground (cool whites)
        static let fg = Color(hex: 0xFFFFFF)
        static let fgMuted = Color(hex: 0xEBEBF5, opacity: 0.62)
        static let fgDim = Color(hex: 0xEBEBF5, opacity: 0.38)
        static let fgFaint = Color(hex: 0xEBEBF5, opacity: 0.14)

        // Primary (ice)
        static let accent = Color(hex: 0x5AB8F5)
        static let accentSoft = Color(hex: 0x5AB8F5, opacity: 0.16)
        static let accentDeep = Color(hex: 0x3D9DDB)
        static let onAccent = Color(hex: 0x001220)      // content on accent fills

        // Metric identity (weight × reps pairs, app-wide)
        static let weightTint = Color(hex: 0x5AB8F5)   // = accent ice
        static let repsTint = Color(hex: 0xFFFFFF)     // = fg

        // Day types (vivid)
        static let armsInk = Color(hex: 0xFF4D88)
        static let armsWash = Color(hex: 0xFF4D88, opacity: 0.14)
        static let legsInk = Color(hex: 0x3F9CFF)
        static let legsWash = Color(hex: 0x3F9CFF, opacity: 0.14)
        static let fullInk = Color(hex: 0xB569FF)
        static let fullWash = Color(hex: 0xB569FF, opacity: 0.14)

        // Training mode
        static let strength = Color(hex: 0xFFFFFF)
        static let endurance = Color(hex: 0xFF8B47)

        // Semantic
        static let up = Color(hex: 0x34D399)
        static let down = Color(hex: 0xFB7185)
        static let flat = Color(hex: 0xEBEBF5, opacity: 0.5)
        static let pr = Color(hex: 0xFFB547)            // amber — trophies, PR badges

        // Apple Health (HK-sourced UI only)
        static let ahGreen = Color(hex: 0x30D158)
        static let ahRed = Color(hex: 0xFF375F)
        static let kcalFlame = Color(hex: 0xFF9F0A)

        // Misc
        static let customBadge = Color(hex: 0xFF9F0A)   // library CUSTOM tag
    }
}

extension DayType {
    /// Vivid identity color for this day type.
    var upliftInk: Color {
        switch self {
        case .arms: .uplift.armsInk
        case .legs: .uplift.legsInk
        case .fullBody: .uplift.fullInk
        }
    }

    /// 14%-opacity wash used behind chips and tags.
    var upliftWash: Color {
        switch self {
        case .arms: .uplift.armsWash
        case .legs: .uplift.legsWash
        case .fullBody: .uplift.fullWash
        }
    }
}
