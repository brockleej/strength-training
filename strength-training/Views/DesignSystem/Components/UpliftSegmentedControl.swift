//
//  UpliftSegmentedControl.swift
//  strength-training
//

import SwiftUI

struct UpliftSegment: Identifiable, Equatable {
    let id: String
    var label: String
    var icon: String? = nil    // optional SF symbol before the label
    var ink: Color? = nil      // optional active tint (dot + label), e.g. day-type ink
}

/// Surface1 track + surface3 active thumb segmented control.
struct UpliftSegmentedControl: View {
    let segments: [UpliftSegment]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(segments) { segment in
                let isActive = segment.id == selection
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selection = segment.id }
                } label: {
                    HStack(spacing: 6) {
                        if let icon = segment.icon {
                            Image(systemName: icon)
                                .font(.system(size: 12, weight: .semibold))
                                .accessibilityHidden(true)   // decorative — label carries the name
                        }
                        if let ink = segment.ink {
                            Circle()
                                .fill(isActive ? ink : Color.uplift.fgDim)
                                .frame(width: 6, height: 6)
                        }
                        Text(segment.label)
                            .font(.uplift.text(13, weight: .semibold))
                            .kerning(-0.1)
                    }
                    .foregroundStyle(isActive ? (segment.ink ?? Color.uplift.fg) : Color.uplift.fgMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        // Persistent + opacity (not conditional insertion) so both the
                        // entering and leaving thumbs crossfade in the same transaction.
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.uplift.surface3)
                            .opacity(isActive ? 1 : 0)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isActive ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.uplift.surface1)
        }
    }
}

#Preview("UpliftSegmentedControl") {
    @Previewable @State var mode = "strength"
    @Previewable @State var range = "3mo"
    @Previewable @State var day = "arms"

    VStack(spacing: 20) {
        UpliftSegmentedControl(
            segments: [
                UpliftSegment(id: "strength", label: "Strength", icon: "bolt.fill"),
                UpliftSegment(id: "endurance", label: "Endurance", icon: "flame.fill"),
            ],
            selection: $mode
        )
        UpliftSegmentedControl(
            segments: ["Week", "Month", "3 mo", "Year", "All"].map {
                UpliftSegment(id: $0.lowercased().replacingOccurrences(of: " ", with: ""), label: $0)
            },
            selection: $range
        )
        UpliftSegmentedControl(
            segments: [
                UpliftSegment(id: "arms", label: "Arms", ink: .uplift.armsInk),
                UpliftSegment(id: "legs", label: "Legs", ink: .uplift.legsInk),
            ],
            selection: $day
        )
    }
    .padding(20)
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
}
