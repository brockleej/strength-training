import SwiftUI

/// Circular icon button used in nav bars, glass headers, and overflow positions.
/// `surface1` background, `fg` icon. Two sizes: 36pt (compact, default) or 44pt (large title).
///
/// ```swift
/// CircleButton(icon: "chevron.left") { dismiss() }
/// CircleButton(icon: "plus", size: .large) { showAddSheet = true }
/// ```
struct CircleButton: View {
    enum Size {
        case compact, large
        var px: CGFloat   { self == .compact ? 36 : 44 }
        var icon: CGFloat { self == .compact ? 18 : 18 }   // icon size doesn't grow proportionally
    }

    let icon: String
    var size: Size = .compact
    var iconColor: Color = .uplift.fg
    var background: Color = .uplift.surface1
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(background)
                .frame(width: size.px, height: size.px)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: size.icon, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }
}

#Preview("CircleButton — variants") {
    HStack(spacing: 14) {
        CircleButton(icon: "chevron.left") {}
        CircleButton(icon: "ellipsis") {}
        CircleButton(icon: "magnifyingglass") {}
        CircleButton(icon: "plus", size: .large) {}
        CircleButton(icon: "checkmark", iconColor: .uplift.accent) {}
    }
    .padding(40)
    .background(Color.uplift.bgElev)
}
