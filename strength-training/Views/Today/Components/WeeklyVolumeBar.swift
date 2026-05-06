import SwiftUI

/// Horizontal "this-week vs last-week" volume comparison bar with a delta pill.
/// The bar shows two stacked segments: this week (accent) above last week (fgFaint reference).
/// If there's no last-week data, the comparison pill is suppressed.
struct WeeklyVolumeBar: View {
    let thisWeekVolume: Int
    let delta: Double?  // nil when last week was zero (no comparison possible)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("vs last week")
                    .font(.uplift.text(11, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(Color.uplift.fgMuted)
                Spacer()
                if let delta {
                    deltaPill(delta)
                } else {
                    Text("no comparison yet")
                        .font(.uplift.text(11, weight: .medium))
                        .foregroundStyle(Color.uplift.fgDim)
                }
            }
            bar
        }
    }

    private var bar: some View {
        // We render two adjacent rectangles: this-week's relative size + last-week's reference size.
        GeometryReader { geo in
            let total = geo.size.width
            let thisFraction = barFraction(for: thisWeekVolume, delta: delta, isThisWeek: true)
            let lastFraction = barFraction(for: thisWeekVolume, delta: delta, isThisWeek: false)
            HStack(spacing: 4) {
                Capsule()
                    .fill(Color.uplift.accent)
                    .frame(width: max(8, total * thisFraction))
                Capsule()
                    .fill(Color.uplift.fgFaint)
                    .frame(width: max(8, total * lastFraction))
            }
        }
        .frame(height: 8)
    }

    /// Bar widths are normalized relative to the larger of the two weeks' volumes
    /// so the bigger week always reaches the right edge minus inter-bar gap.
    private func barFraction(for thisWeek: Int, delta: Double?, isThisWeek: Bool) -> CGFloat {
        // delta is nil iff last week's volume was 0 (handled by `weeklyVolumeDelta`).
        // In that case we hide the last-week segment entirely.
        guard let delta else {
            return isThisWeek ? 1.0 : 0.0
        }
        // Reconstruct last week's volume from the delta: thisWeek = lastWeek * (1 + delta).
        // delta cannot be -1.0 here because that would imply last week was 0 (handled above).
        let lastWeek = Double(thisWeek) / (1.0 + delta)
        let max = Swift.max(Double(thisWeek), lastWeek)
        guard max > 0 else { return 0.5 }
        let value = isThisWeek ? Double(thisWeek) : lastWeek
        // Each bar gets up to ~48% of the total (leaving 4% for the gap).
        return CGFloat(value / max) * 0.48
    }

    private func deltaPill(_ delta: Double) -> some View {
        let pct = Int((abs(delta) * 100).rounded())
        let isUp = delta >= 0
        let bg = isUp ? Color.uplift.up.opacity(0.16) : Color.uplift.down.opacity(0.16)
        let fg = isUp ? Color.uplift.up : Color.uplift.down
        return HStack(spacing: 3) {
            Image(systemName: isUp ? "arrow.up" : "arrow.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(fg)
            Num("\(pct)%", size: 11, weight: .bold, color: fg)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(bg, in: Capsule())
    }
}

#Preview("WeeklyVolumeBar") {
    VStack(spacing: 16) {
        WeeklyVolumeBar(thisWeekVolume: 38_460, delta:  0.24)   // +24%
        WeeklyVolumeBar(thisWeekVolume: 12_000, delta: -0.18)   // -18%
        WeeklyVolumeBar(thisWeekVolume: 5_000,  delta: nil)     // no comparison
    }
    .padding(20)
    .background(Color.uplift.bgElev)
}
