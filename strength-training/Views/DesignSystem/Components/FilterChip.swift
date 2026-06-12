//
//  FilterChip.swift
//  strength-training
//

import SwiftUI

/// Capsule filter chip (History day-type filters).
struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.uplift.text(13, weight: .semibold))
                .foregroundStyle(isSelected ? Color.uplift.onAccent : Color.uplift.fgMuted)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background {
                    Capsule().fill(isSelected ? Color.uplift.accent : Color.uplift.surface1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview("FilterChip") {
    HStack(spacing: 8) {
        FilterChip(label: "All", isSelected: true) {}
        FilterChip(label: "Arms", isSelected: false) {}
        FilterChip(label: "Legs", isSelected: false) {}
        FilterChip(label: "Full Body", isSelected: false) {}
    }
    .padding(20)
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
}
