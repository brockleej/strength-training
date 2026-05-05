import SwiftUI

/// Frosted-glass top header used on Exercise List and Focus screens.
/// Renders a fixed-position bar at the top of the screen with:
/// - 56pt safe-area-respecting top padding
/// - `ultraThinMaterial` backdrop blur
/// - vertical gradient (top: bgElev @ 85%, fade to transparent over 70%)
///
/// Usage: place inside a `ZStack(alignment: .top)` over your scrollable content.
///
/// ```swift
/// ZStack(alignment: .top) {
///     ScrollView { ... }
///     GlassHeader {
///         CircleButton(icon: "chevron.down") { dismiss() }
///         Spacer()
///         Text("LEG DAY").font(.uplift.text(11, weight: .semibold)).tracking(0.4)
///             .foregroundStyle(Color.uplift.fgMuted)
///         Spacer()
///         CircleButton(icon: "ellipsis") {}
///     }
/// }
/// ```
struct GlassHeader<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, 14)
        .padding(.top, 56)
        .padding(.bottom, 14)
        .background {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.uplift.bgElev.opacity(0.85),
                        Color.uplift.bgElev.opacity(0.55),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .background(.ultraThinMaterial)
            }
            .ignoresSafeArea(edges: .top)
        }
    }
}

#Preview("GlassHeader") {
    ZStack(alignment: .top) {
        // Mock scrollable content underneath
        ScrollView {
            VStack(spacing: 12) {
                ForEach(0..<20) { _ in
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.uplift.surface1)
                        .frame(height: 60)
                }
            }
            .padding(.top, 120)
            .padding(.horizontal, 20)
        }
        .background(Color.uplift.bgElev)

        GlassHeader {
            CircleButton(icon: "chevron.down") {}
            Spacer()
            Text("LEG DAY")
                .font(.uplift.text(11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Color.uplift.fgMuted)
            Spacer()
            CircleButton(icon: "ellipsis") {}
        }
    }
}
