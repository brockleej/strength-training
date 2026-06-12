//
//  DayChip.swift
//  strength-training
//

import SwiftUI

/// Day-type icon chip: washed rounded square + ink-colored SF symbol.
struct DayChip: View {
    enum Size {
        case sm, md, lg

        var px: CGFloat {
            switch self {
            case .sm: 36
            case .md: 44
            case .lg: 56
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .sm: 18
            case .md: 22
            case .lg: 28
            }
        }
    }

    let dayType: DayType
    var size: Size = .md

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size.px * 0.32, style: .continuous)
                .fill(dayType.upliftWash)
            Image(systemName: dayType.systemImage)
                .font(.system(size: size.iconSize, weight: .medium))
                .foregroundStyle(dayType.upliftInk)
        }
        .frame(width: size.px, height: size.px)
        .accessibilityLabel(dayType.rawValue)
    }
}

#Preview("DayChip") {
    HStack(spacing: 16) {
        ForEach([DayChip.Size.sm, .md, .lg], id: \.self) { size in
            VStack(spacing: 12) {
                DayChip(dayType: .arms, size: size)
                DayChip(dayType: .legs, size: size)
                DayChip(dayType: .fullBody, size: size)
            }
        }
    }
    .padding(24)
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
}
