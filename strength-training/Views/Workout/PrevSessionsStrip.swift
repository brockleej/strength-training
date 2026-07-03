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
            .mask {
                // Long leading fade: older cards stay mostly hidden — full
                // opacity only over the trailing (most recent) quarter.
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.75),
                        .init(color: .black, location: 1),
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            }
        }
    }

    private func card(_ entry: PrevSessionsStripData.Entry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.dateLabel)
                .textCase(.uppercase)
                .font(.uplift.text(10, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(Color.uplift.fgDim)
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(entry.runs.enumerated()), id: \.offset) { _, run in
                    PairText.pair(weight: run.weight, reps: run.reps, font: .uplift.mono(12, weight: .semibold))
                        .kerning(-0.2)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 112, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.uplift.surface1.opacity(0.45))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.uplift.hairline, lineWidth: 0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.dateLabel): \(entry.linesAccessibility)")
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
            .init(id: UUID(), dateLabel: "9 wk ago", runs: [.init(weight: 210, reps: [5, 5, 5])]),
            .init(id: UUID(), dateLabel: "7 wk ago", runs: [.init(weight: 215, reps: [5, 5])]),
            .init(id: UUID(), dateLabel: "5 wk ago", runs: [.init(weight: 220, reps: [5, 5]), .init(weight: 225, reps: [3])]),
            .init(id: UUID(), dateLabel: "3 wk ago", runs: [.init(weight: 225, reps: [5, 5, 5])]),
            .init(id: UUID(), dateLabel: "Yesterday", runs: [
                .init(weight: 225, reps: [5, 5]), .init(weight: 230, reps: [3]), .init(weight: 235, reps: [1]),
            ]),
        ])
        PrevSessionsStrip(entries: [])
    }
    .padding(.vertical, 16)
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
}
