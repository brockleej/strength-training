// strength-training/Views/Workout/PrevSessionsStrip.swift
import SwiftUI

/// Horizontal scrollable strip of an exercise's prior sessions. Right-most = most recent.
/// Up to 10 entries. Empty state when there are no priors.
///
/// Card content: relative-date eyebrow + space-separated sets in mono.
struct PrevSessionsStrip: View {
    /// Pre-shaped data for the strip (chronological — oldest first, most recent last).
    /// Shaping is the call site's job (see `prevSessionData(for:mode:)` in FocusView).
    let entries: [Entry]

    struct Entry: Identifiable {
        let id: UUID  // ExerciseRecord.id
        let dateLabel: String   // "3 WK AGO" / "5 WK AGO" / "12 DAYS AGO"
        let setsLabel: String   // "225 × 5 · 5 · 5"
    }

    var body: some View {
        if entries.isEmpty {
            emptyState
        } else {
            scroll
        }
    }

    private var scroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Color.clear.frame(width: 8)  // leading inset
                ForEach(entries) { entry in
                    card(entry)
                }
                Color.clear.frame(width: 8)  // trailing inset
            }
        }
        .scrollClipDisabled()
        .defaultScrollAnchor(.trailing)  // start scrolled to the most-recent end
    }

    private func card(_ entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.dateLabel)
                .font(.uplift.text(10, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(Color.uplift.fgMuted)
            Text(entry.setsLabel)
                .font(.uplift.mono(12, weight: .semibold))
                .kerning(-0.2)
                .foregroundStyle(Color.uplift.fg)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 124, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.uplift.surface1)
        }
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
            .padding(.horizontal, 8)
    }
}

#Preview("PrevSessionsStrip") {
    VStack(spacing: 16) {
        PrevSessionsStrip(entries: [
            .init(id: UUID(), dateLabel: "9 WK AGO", setsLabel: "210 × 5 · 5 · 5"),
            .init(id: UUID(), dateLabel: "7 WK AGO", setsLabel: "215 × 5 · 5 · 5"),
            .init(id: UUID(), dateLabel: "5 WK AGO", setsLabel: "220 × 5 · 5 · 4"),
            .init(id: UUID(), dateLabel: "3 WK AGO", setsLabel: "225 × 5 · 5 · 5"),
        ])

        PrevSessionsStrip(entries: [])
            .padding(.horizontal, 16)
    }
    .padding(.vertical, 16)
    .background(Color.uplift.bgElev)
}
