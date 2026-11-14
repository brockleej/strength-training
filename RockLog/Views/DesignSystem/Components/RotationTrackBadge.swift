//
//  RotationTrackBadge.swift
//  RockLog
//
//  Small A/B pill next to a session’s day and date. Every / All has no pill.
//

import SwiftUI

struct RotationTrackBadge: View {
    let track: RotationTrack

    var body: some View {
        if let badge = track.badge {
            Text(badge)
                .font(.uplift.text(11, weight: .bold))
                .foregroundStyle(Color.uplift.accent)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.uplift.accent.opacity(0.16)))
                .accessibilityLabel("\(badge) week")
        }
    }
}

#Preview {
    HStack(spacing: 8) {
        RotationTrackBadge(track: .a)
        RotationTrackBadge(track: .b)
        RotationTrackBadge(track: .every)
    }
    .padding()
    .background(Color.uplift.bgElev)
}
