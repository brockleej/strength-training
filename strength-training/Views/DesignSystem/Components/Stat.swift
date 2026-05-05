import SwiftUI

/// Compact stat — used inside cards (Today's hero stat strip, Session Detail's stats card).
/// 11pt uppercase muted label + 20pt mono value + optional 12pt muted unit.
struct Stat: View {
    let label: String
    let value: String
    var unit: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.uplift.text(11, weight: .semibold))
                .tracking(0.2)
                .foregroundStyle(Color.uplift.fgMuted)
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Num(value, size: 20)
                if let unit {
                    Text(unit)
                        .font(.uplift.text(12, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Medium stat — used on the History tab's summary strip card.
/// 11pt uppercase label + 22pt value (color tinted via `tone`) + optional unit.
struct SummaryStat: View {
    enum Tone { case neutral, pr }

    let label: String
    let value: String
    var unit: String? = nil
    var tone: Tone = .neutral

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.uplift.text(11, weight: .semibold))
                .tracking(0.3)
                .foregroundStyle(Color.uplift.fgMuted)
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Num(value, size: 22, weight: .bold, color: tintColor)
                if let unit {
                    Text(unit)
                        .font(.uplift.text(11, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tintColor: Color {
        switch tone {
        case .neutral: .uplift.fg
        case .pr:      .uplift.pr
        }
    }
}

/// Large stat — used in the Workout Summary 2x2 stats grid post-workout.
/// 11pt uppercase label + 28pt value (color tinted via `tone`) + optional 13pt unit.
struct BigStat: View {
    enum Tone { case neutral, pr }

    let label: String
    let value: String
    var unit: String? = nil
    var tone: Tone = .neutral

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.uplift.text(11, weight: .semibold))
                .tracking(0.3)
                .foregroundStyle(Color.uplift.fgMuted)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Num(value, size: 28, weight: .bold, color: tintColor)
                if let unit {
                    Text(unit)
                        .font(.uplift.text(13, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tintColor: Color {
        switch tone {
        case .neutral: .uplift.fg
        case .pr:      .uplift.pr
        }
    }
}

#Preview("Stat trio") {
    VStack(spacing: 24) {
        // Stat row (Today hero card)
        HStack(spacing: 14) {
            Stat(label: "Lifts", value: "6")
            Stat(label: "Volume", value: "~14k", unit: "lb")
            Stat(label: "Time", value: "52", unit: "min")
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.uplift.surface1))

        // SummaryStat row (History summary)
        HStack(spacing: 14) {
            SummaryStat(label: "This month", value: "14", unit: "sessions")
            Divider().frame(height: 36)
            SummaryStat(label: "Volume", value: "187k", unit: "lb")
            Divider().frame(height: 36)
            SummaryStat(label: "PRs", value: "6", tone: .pr)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.uplift.surface1))

        // BigStat 2x2 grid (Workout Summary)
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
            BigStat(label: "Duration", value: "52", unit: "min")
            BigStat(label: "Volume", value: "14,820", unit: "lb")
            BigStat(label: "Sets", value: "18")
            BigStat(label: "PRs", value: "1", tone: .pr)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.uplift.surface1))
    }
    .padding(20)
    .background(Color.uplift.bgElev)
}
