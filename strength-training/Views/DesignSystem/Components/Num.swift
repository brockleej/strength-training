import SwiftUI

/// Renders a numeric string in SF Mono with tabular figures and tight letter spacing.
/// Use for weights, reps, counts, durations, dates — anywhere numbers should align in columns
/// or update in place without horizontal jitter.
///
/// ```swift
/// Num("235", size: 40, weight: .bold)
/// Num("12,840", size: 22, color: .uplift.fg)
/// ```
struct Num: View {
    let value: String
    var size: CGFloat = 22
    var weight: Font.Weight = .semibold
    var color: Color = .uplift.fg

    init(_ value: String, size: CGFloat = 22, weight: Font.Weight = .semibold, color: Color = .uplift.fg) {
        self.value = value
        self.size = size
        self.weight = weight
        self.color = color
    }

    /// Convenience for `Int` values.
    init(_ value: Int, size: CGFloat = 22, weight: Font.Weight = .semibold, color: Color = .uplift.fg) {
        self.init(String(value), size: size, weight: weight, color: color)
    }

    var body: some View {
        Text(value)
            .font(.uplift.mono(size, weight: weight))
            .monospacedDigit()
            .kerning(-0.5)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

#Preview("Num — sizes") {
    VStack(alignment: .leading, spacing: 16) {
        Num("235", size: 120, weight: .bold)
        Num("47", size: 40)
        Num("12,840", size: 22)
        Num("2:00", size: 14)
    }
    .padding()
    .background(Color.uplift.bgElev)
}
