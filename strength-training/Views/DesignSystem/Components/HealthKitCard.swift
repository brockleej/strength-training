import SwiftUI

/// Apple-Health-branded live-metrics card. Renders as a single horizontal pill with:
/// 1. Source badge (left) — green tile with heart icon + "APPLE HEALTH · Workout · live"
/// 2. Three live tiles — BPM (red heart, beats), kcal (orange flame), elapsed (green clock)
///
/// Pure-display: caller passes current values. HealthKit wiring (binding to `HKWorkoutSession`
/// observer) is added in Phase 2 by the consumer.
///
/// ```swift
/// HealthKitCard(bpm: 142, kcal: 234, elapsed: "18:42")
/// ```
struct HealthKitCard: View {
    let bpm: Int
    let kcal: Int
    let elapsed: String

    var body: some View {
        HStack(spacing: 1) {
            sourceBadge
            tile(icon: "heart.fill",  iconColor: .uplift.ahkitRed,   value: "\(bpm)",     unit: "bpm",  beat: true)
            tileDivider
            tile(icon: "flame.fill",  iconColor: Color(hex: 0xFF9F0A), value: "\(kcal)",   unit: "kcal", beat: false)
            tileDivider
            tile(icon: "clock.fill",  iconColor: .uplift.ahkitGreen, value: elapsed,                 beat: false)
        }
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.uplift.ahkitGreen.opacity(0.10))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.uplift.ahkitGreen.opacity(0.28), lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var sourceBadge: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.uplift.ahkitGreen)
                .frame(width: 22, height: 22)
                .overlay {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
            VStack(alignment: .leading, spacing: 1) {
                Text("APPLE HEALTH")
                    .font(.uplift.text(9, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(Color.uplift.ahkitGreen)
                Text("Workout · live")
                    .font(.uplift.text(10, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.uplift.ahkitGreen.opacity(0.14))
    }

    private func tile(icon: String, iconColor: Color, value: String, unit: String? = nil, beat: Bool) -> some View {
        VStack(spacing: 4) {
            HeartBeatIcon(symbol: icon, color: iconColor, animate: beat)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.uplift.mono(16, weight: .bold))
                    .kerning(-0.4)
                    .foregroundStyle(Color.uplift.fg)
                if let unit {
                    Text(unit.uppercased())
                        .font(.uplift.text(9, weight: .semibold))
                        .tracking(0.2)
                        .foregroundStyle(Color.uplift.fgMuted)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
    }

    private var tileDivider: some View {
        Rectangle()
            .fill(Color.uplift.ahkitGreen.opacity(0.22))
            .frame(width: 0.5)
            .padding(.vertical, 8)
    }
}

/// Small SF Symbol that pulses with a heartbeat rhythm when `animate` is true.
/// Two-pulse cadence per beat (lub-dub), then a longer rest, looping forever via a
/// stored Task so the view can cancel it on disappear.
private struct HeartBeatIcon: View {
    let symbol: String
    let color: Color
    let animate: Bool

    @State private var scale: CGFloat = 1.0
    @State private var beatTask: Task<Void, Never>? = nil

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .scaleEffect(scale)
            .onAppear {
                guard animate, beatTask == nil else { return }
                beatTask = Task { @MainActor in
                    while !Task.isCancelled {
                        // 150ms sleep matches animation duration so each pulse begins as the previous settles
                        withAnimation(.easeInOut(duration: 0.15)) { scale = 1.25 }
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        withAnimation(.easeInOut(duration: 0.15)) { scale = 1.0 }
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        withAnimation(.easeInOut(duration: 0.12)) { scale = 1.18 }
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        withAnimation(.easeInOut(duration: 0.12)) { scale = 1.0 }
                        try? await Task.sleep(nanoseconds: 500_000_000)  // rest between beats
                    }
                }
            }
            .onDisappear {
                beatTask?.cancel()
                beatTask = nil
            }
    }
}

#Preview("HealthKitCard — live workout") {
    VStack(spacing: 14) {
        HealthKitCard(bpm: 128, kcal: 184, elapsed: "11:24")
        HealthKitCard(bpm: 142, kcal: 234, elapsed: "18:42")
    }
    .padding(20)
    .background(Color.uplift.bgElev)
}
