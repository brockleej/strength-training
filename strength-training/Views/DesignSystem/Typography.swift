import SwiftUI

extension Font {
    /// UpLift typography helpers. SF Pro Display for headlines, SF Pro Text for body,
    /// SF Mono for numerals. Sizes match the design's pt values directly.
    enum uplift {
        /// SF Pro Display — headlines (h1, big numbers, eyebrow titles).
        static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
            .system(size: size, weight: weight, design: .default)
        }

        /// SF Pro Text — body, labels, button copy.
        static func text(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
            .system(size: size, weight: weight, design: .default)
        }

        /// SF Mono — every numeral that ticks or aligns in a column
        /// (weights, reps, durations, dates, counts).
        static func mono(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
    }
}
