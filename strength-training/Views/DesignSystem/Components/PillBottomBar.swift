import SwiftUI

/// Floating capsule action bar pinned to the bottom of a screen. Used for:
/// - The 5-tab `TabBar` (see TabBar.swift)
/// - In-workout action footers (rest timer + Log Set, Add Exercise + Finish)
///
/// Render via `.safeAreaInset(edge: .bottom)` on the scroll/parent so content slides under it
/// rather than being covered by it.
///
/// ```swift
/// ScrollView { ... }
///     .safeAreaInset(edge: .bottom) {
///         PillBottomBar {
///             HStack(spacing: 8) { ... your buttons ... }
///         }
///     }
/// ```
struct PillBottomBar<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 8) {
            content()
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.uplift.surface3.opacity(0.85))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.uplift.hairlineStrong, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 8)
        .padding(.horizontal, 12)
        .padding(.bottom, 22)
    }
}

#Preview("PillBottomBar — Log Set example") {
    ZStack(alignment: .bottom) {
        Color.uplift.bgElev.ignoresSafeArea()

        PillBottomBar {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.uplift.fgMuted)
                Num("2:00", size: 14)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Button {
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Log set")
                        .font(.uplift.text(15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(Color.uplift.accent, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .foregroundStyle(Color.uplift.onAccent)
            }
            .buttonStyle(.plain)
        }
    }
}
