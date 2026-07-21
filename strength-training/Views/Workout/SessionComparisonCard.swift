//
//  SessionComparisonCard.swift
//  strength-training
//
//  “vs last [day · A/B]” volume/set deltas + PR milestones.
//

import SwiftUI

struct SessionComparisonCard: View {
    let comparison: SessionMath.SessionComparison

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.uplift.accent)
                Text(headerTitle)
                    .font(.uplift.text(13, weight: .semibold))
                    .foregroundStyle(Color.uplift.fg)
                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                deltaChip(
                    label: "Volume",
                    value: "\(SessionMath.formatSignedVolume(comparison.volumeDelta)) lb",
                    tone: tone(for: comparison.volumeDelta)
                )
                deltaChip(
                    label: "Sets",
                    value: SessionMath.formatSignedCount(comparison.setDelta),
                    tone: tone(for: Double(comparison.setDelta))
                )
                if let pct = comparison.volumeDeltaPercent {
                    deltaChip(
                        label: "Volume %",
                        value: "\(pct >= 0 ? "+" : "−")\(abs(Int(pct.rounded())))%",
                        tone: tone(for: pct)
                    )
                }
            }

            Text(baselineCaption)
                .font(.uplift.text(12, weight: .medium))
                .foregroundStyle(Color.uplift.fgDim)

            if !comparison.prNames.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.uplift.pr)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(comparison.prNames.count == 1
                             ? "PR this session"
                             : "\(comparison.prNames.count) PRs this session")
                            .font(.uplift.text(13, weight: .semibold))
                            .foregroundStyle(Color.uplift.pr)
                        Text(comparison.prNames.joined(separator: " · "))
                            .font(.uplift.text(12, weight: .medium))
                            .foregroundStyle(Color.uplift.fgMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.uplift.pr.opacity(0.10))
                }
            } else if comparison.volumeDelta > 0 {
                milestoneRow(
                    icon: "arrow.up.right",
                    tint: .uplift.up,
                    text: "Volume up vs last comparable session"
                )
            } else if comparison.volumeDelta < 0 {
                milestoneRow(
                    icon: "arrow.down.right",
                    tint: .uplift.down,
                    text: "Lower volume than last time — recovery or lighter day"
                )
            } else {
                milestoneRow(
                    icon: "equal",
                    tint: .uplift.fgMuted,
                    text: "Matched last session volume"
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.uplift.surface1)
        }
        .accessibilityElement(children: .combine)
    }

    private var headerTitle: String {
        let day = comparison.previous.day.rawValue
        if comparison.matchedRotation, let badge = comparison.previous.track.badge {
            return "vs last \(day) · \(badge)"
        }
        return "vs last \(day)"
    }

    private var baselineCaption: String {
        let date = comparison.previous.date.formatted(.dateTime.month(.abbreviated).day())
        let vol = TodayStats.formatVolume(SessionMath.volume(of: comparison.previous))
        let sets = SessionMath.setCount(of: comparison.previous)
        return "Last: \(date) · \(vol) lb · \(sets) sets"
    }

    private func tone(for delta: Double) -> Color {
        if delta > 0 { return .uplift.up }
        if delta < 0 { return .uplift.down }
        return .uplift.fg
    }

    private func deltaChip(label: String, value: String, tone: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.uplift.text(10, weight: .bold))
                .tracking(0.3)
                .foregroundStyle(Color.uplift.fgMuted)
            Text(value)
                .font(.uplift.mono(15, weight: .bold))
                .foregroundStyle(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.uplift.surface2)
        }
    }

    private func milestoneRow(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.uplift.text(12, weight: .medium))
                .foregroundStyle(Color.uplift.fgMuted)
        }
    }
}
