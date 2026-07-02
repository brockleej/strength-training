//
//  PrevSessionsStrip.swift
//  strength-training
//

import SwiftUI

/// Horizontal strip of an exercise's prior sessions. Right-most = most recent
/// (entries arrive oldest-first); initial scroll anchored trailing. Narrow
/// cards; sets wrap to one line per same-weight run.
struct PrevSessionsStrip: View {
    let entries: [PrevSessionsStripData.Entry]

    var body: some View {
        if entries.isEmpty {
            emptyState
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(entries) { entry in
                        card(entry)
                    }
                }
                .padding(.horizontal, 20)
            }
            .defaultScrollAnchor(.trailing)
        }
    }

    private func card(_ entry: PrevSessionsStripData.Entry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.dateLabel)
                .textCase(.uppercase)
                .font(.uplift.text(10, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(Color.uplift.fgMuted)
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(entry.lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.uplift.mono(12, weight: .semibold))
                        .kerning(-0.2)
                        .foregroundStyle(Color.uplift.fg)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 112, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.uplift.surface1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.dateLabel): \(entry.lines.joined(separator: ", "))")
    }

    private var emptyState: some View {
        Text("First time logging this lift")
            .font(.uplift.text(12, weight: .medium))
            .foregroundStyle(Color.uplift.fgDim)
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.uplift.surface1)
            }
            .padding(.horizontal, 20)
    }
}

#Preview("PrevSessionsStrip") {
    VStack(spacing: 16) {
        PrevSessionsStrip(entries: [
            .init(id: UUID(), dateLabel: "9 wk ago", lines: ["210 × 5 · 5 · 5"]),
            .init(id: UUID(), dateLabel: "7 wk ago", lines: ["215 × 5 · 5"]),
            .init(id: UUID(), dateLabel: "5 wk ago", lines: ["220 × 5 · 5", "225 × 3"]),
            .init(id: UUID(), dateLabel: "3 wk ago", lines: ["225 × 5 · 5 · 5"]),
            .init(id: UUID(), dateLabel: "Yesterday", lines: ["225 × 5 · 5", "230 × 3", "235 × 1"]),
        ])
        PrevSessionsStrip(entries: [])
    }
    .padding(.vertical, 16)
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
}
