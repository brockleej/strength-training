//
//  YesterdayCard.swift
//  strength-training
//

import SwiftUI

/// Row for the most recent completed session. Used as a NavigationLink label —
/// purely presentational.
struct YesterdayCard: View {
    let dayType: DayType
    let volumeText: String   // "12,840"
    let setCount: Int
    let prCount: Int

    var body: some View {
        HStack(spacing: 12) {
            DayChip(dayType: dayType, size: .sm)

            VStack(alignment: .leading, spacing: 2) {
                Text(dayType.rawValue)
                    .font(.uplift.text(15, weight: .semibold))
                    .kerning(-0.2)
                    .foregroundStyle(Color.uplift.fg)
                (
                    Text("\(volumeText) lb").font(.uplift.mono(12, weight: .medium))
                    + Text(" · ").font(.uplift.text(12, weight: .medium))
                    + Text("\(setCount) sets").font(.uplift.text(12, weight: .medium))
                )
                .foregroundStyle(Color.uplift.fgMuted)
            }

            Spacer(minLength: 8)

            if prCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.uplift.pr)
                        .accessibilityHidden(true)
                    Text("\(prCount)")
                        .font(.uplift.mono(12, weight: .semibold))
                        .foregroundStyle(Color.uplift.pr)
                }
                .accessibilityLabel("\(prCount) personal record\(prCount == 1 ? "" : "s")")
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.uplift.fgDim)
                .accessibilityHidden(true)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.uplift.surface1)
        }
    }
}

#Preview("YesterdayCard") {
    VStack(spacing: 8) {
        YesterdayCard(dayType: .arms, volumeText: "12,840", setCount: 19, prCount: 2)
        YesterdayCard(dayType: .legs, volumeText: "15,420", setCount: 21, prCount: 0)
    }
    .padding(20)
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
}
