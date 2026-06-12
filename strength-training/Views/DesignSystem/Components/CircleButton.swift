//
//  CircleButton.swift
//  strength-training
//

import SwiftUI

/// Circular icon button used in glass headers and large-title bars.
/// The visual circle can be smaller than 44pt; the tap target never is.
struct CircleButton: View {
    let icon: String
    var size: CGFloat = 36
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Color.uplift.surface1)
                Image(systemName: icon)
                    .font(.system(size: size * 0.5 - 2, weight: .semibold))
                    .foregroundStyle(Color.uplift.fg)
            }
            .frame(width: size, height: size)
            .frame(minWidth: 44, minHeight: 44)   // HIG-safe tap target
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview("CircleButton") {
    HStack(spacing: 16) {
        CircleButton(icon: "chevron.left", accessibilityLabel: "Back") {}
        CircleButton(icon: "chevron.down", accessibilityLabel: "Minimize") {}
        CircleButton(icon: "ellipsis", accessibilityLabel: "More") {}
        CircleButton(icon: "plus", size: 44, accessibilityLabel: "Add") {}
    }
    .padding(24)
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
}
