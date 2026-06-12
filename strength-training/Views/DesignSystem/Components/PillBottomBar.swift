//
//  PillBottomBar.swift
//  strength-training
//

import SwiftUI

/// Floating bottom action bar: blurred dark pill, hairline border, drop shadow.
/// Place via .safeAreaInset(edge: .bottom) or at the bottom of a ZStack.
/// Children lay out in an HStack(spacing: 8); primary buttons should use
/// 22pt-radius accent fills, secondary buttons transparent backgrounds.
struct PillBottomBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 8) { content }
            .padding(8)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.uplift.pillBg)
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.uplift.hairlineStrong, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.5), radius: 15, y: 8)
            .padding(.horizontal, 12)
    }
}

#Preview("PillBottomBar") {
    VStack {
        Spacer()
        // Rest chip + primary (Focus pattern)
        PillBottomBar {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.uplift.fgMuted)
                Text("2:00")
                    .font(.uplift.mono(14, weight: .semibold))
                    .foregroundStyle(Color.uplift.fg)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)

            Button {} label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark").font(.system(size: 16, weight: .semibold))
                    Text("Log set").font(.uplift.text(15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.uplift.accent, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .foregroundStyle(Color.uplift.onAccent)
            }
            .buttonStyle(.plain)
        }

        // Single full-width primary (Exercise List pattern)
        PillBottomBar {
            Button {} label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark").font(.system(size: 16, weight: .semibold))
                    Text("Finish Workout").font(.uplift.text(15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.uplift.accent, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .foregroundStyle(Color.uplift.onAccent)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 12)
    }
    .padding(.bottom, 24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
}
