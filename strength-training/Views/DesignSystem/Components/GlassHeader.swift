//
//  GlassHeader.swift
//  strength-training
//

import SwiftUI

/// Frosted top header for in-workout screens: content row over a blur +
/// bgElev gradient that fades to transparent. Place in a ZStack(alignment: .top)
/// over the scroll content; scroll content should reserve ~56pt of clearance.
struct GlassHeader<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) { content }
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity)
            .background(alignment: .top) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        LinearGradient(
                            stops: [
                                .init(color: Color.uplift.bgElev.opacity(0.85), location: 0),
                                .init(color: Color.uplift.bgElev.opacity(0.55), location: 0.7),
                                .init(color: .clear, location: 1),
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    }
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: 0.7),
                                .init(color: .clear, location: 1),
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    }
                    .ignoresSafeArea(edges: .top)
            }
    }
}

#Preview("GlassHeader") {
    ZStack(alignment: .top) {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(0..<20) { i in
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.uplift.surface1)
                        .frame(height: 64)
                        .overlay(Text("Row \(i)").foregroundStyle(Color.uplift.fgMuted))
                }
            }
            .padding(.top, 56)
            .padding(.horizontal, 20)
        }
        .background(Color.uplift.bgElev)

        GlassHeader {
            CircleButton(icon: "chevron.down", accessibilityLabel: "Minimize") {}
            Spacer()
            Text("LEG DAY")
                .font(.uplift.text(11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Color.uplift.fgMuted)
            Spacer()
            CircleButton(icon: "ellipsis", accessibilityLabel: "More") {}
        }
    }
    .preferredColorScheme(.dark)
}
