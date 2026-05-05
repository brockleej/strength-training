import SwiftUI

extension Color {
    /// Hex-RGB initializer. `0xRRGGBB` for the channels, opacity passed separately.
    /// Example: `Color(hex: 0xFF4D88)` → vivid pink. `Color(hex: 0x000000, opacity: 0.5)` → 50% black.
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >>  8) & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    /// UpLift design palette ("Refined Native"). Access via `Color.uplift.<token>`.
    static let uplift = UpliftPalette()
}

struct UpliftPalette {
    // Surfaces
    let bg              = Color(hex: 0x000000)
    let bgElev          = Color(hex: 0x0E1014)
    let surface1        = Color(hex: 0x161A20)
    let surface2        = Color(hex: 0x1F242C)
    let surface3        = Color(hex: 0x2A3038)
    let hairline        = Color.white.opacity(0.06)
    let hairlineStrong  = Color.white.opacity(0.10)

    // Foreground (cool whites — referenced rgba(235,235,245,X) in design)
    let fg       = Color.white
    let fgMuted  = Color(red: 235/255, green: 235/255, blue: 245/255, opacity: 0.62)
    let fgDim    = Color(red: 235/255, green: 235/255, blue: 245/255, opacity: 0.38)
    let fgFaint  = Color(red: 235/255, green: 235/255, blue: 245/255, opacity: 0.14)

    // Primary (ice blue)
    let accent      = Color(hex: 0x5AB8F5)
    let accentSoft  = Color(hex: 0x5AB8F5, opacity: 0.16)
    let accentDeep  = Color(hex: 0x3D9DDB)
    /// On-accent text (used as foreground when accent is the bg)
    let onAccent    = Color(hex: 0x001220)

    // Day types — vivid
    let armsInk   = Color(hex: 0xFF4D88)
    let armsWash  = Color(hex: 0xFF4D88, opacity: 0.14)
    let legsInk   = Color(hex: 0x3F9CFF)
    let legsWash  = Color(hex: 0x3F9CFF, opacity: 0.14)
    let fullInk   = Color(hex: 0xB569FF)
    let fullWash  = Color(hex: 0xB569FF, opacity: 0.14)

    // Mode
    let strength  = Color.white
    let endurance = Color(hex: 0xFF8B47)

    // Semantic
    let up   = Color(hex: 0x34D399)
    let down = Color(hex: 0xFB7185)
    let flat = Color(red: 235/255, green: 235/255, blue: 245/255, opacity: 0.5)
    let pr   = Color(hex: 0xFFB547)

    // Apple Health (used only by HealthKitCard)
    let ahkitGreen  = Color(hex: 0x30D158)
    let ahkitOrange = Color(hex: 0xFF9F0A)
    let ahkitRed    = Color(hex: 0xFF375F)
}
