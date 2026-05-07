// strength-training/Views/Workout/WorkoutSummaryView.swift
import SwiftUI

/// Post-finish workout summary. Presented as a sheet from WorkoutTabView after
/// EffortRatingView dismisses.
///
/// Pure presentation: takes its data via parameters so it Preview-renders cleanly
/// without a WorkoutViewModel. Caller fetches HealthKit stats async and passes nil
/// while loading.
struct WorkoutSummaryView: View {
    let session: WorkoutSession
    let prCount: Int
    /// HealthKit stats for the session's HK workout, if available.
    /// Nil = either no HK workout was saved, or the async fetch is still in-flight.
    let healthKitStats: HealthKitWorkoutStats?
    let onDone: () -> Void
    let onDetail: () -> Void

    private var durationSec: TimeInterval { WorkoutSummaryStats.durationSeconds(for: session) }
    private var volumeLb: Int { WorkoutSummaryStats.totalVolume(for: session) }
    private var setCount: Int { WorkoutSummaryStats.totalSets(for: session) }
    private var durationMin: Int { WorkoutSummaryStats.formatDurationMin(durationSec) }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: 60)
                    completedEyebrow
                    title
                    subtitle
                    statsGrid
                        .padding(.top, 22)
                    if healthKitStats != nil {
                        appleHealthCard
                            .padding(.top, 12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 140)  // pill bar clearance
            }
            .background(Color.uplift.bgElev)
            .scrollIndicators(.hidden)

            actionBar
        }
    }

    // MARK: - Sections

    private var completedEyebrow: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.uplift.up)
            Text("WORKOUT COMPLETE")
                .font(.uplift.text(13, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Color.uplift.up)
        }
        .padding(.bottom, 12)
    }

    private var title: some View {
        Text("Strong session.")
            .font(.uplift.display(32, weight: .bold))
            .kerning(-0.7)
            .foregroundStyle(Color.uplift.fg)
            .lineLimit(2)
    }

    private var subtitle: some View {
        Text("\(session.dayType.rawValue) · \(formattedDate(session.date))")
            .font(.uplift.text(14, weight: .medium))
            .foregroundStyle(Color.uplift.fgMuted)
            .padding(.top, 6)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
            BigStat(label: "Duration", value: "\(durationMin)", unit: "min")
            BigStat(label: "Volume", value: volumeLb.formatted(.number), unit: "lb")
            BigStat(label: "Sets", value: "\(setCount)")
            BigStat(label: "PRs", value: "\(prCount)", tone: prCount > 0 ? .pr : .neutral)
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.uplift.surface1)
        }
    }

    @ViewBuilder
    private var appleHealthCard: some View {
        if let stats = healthKitStats {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.uplift.ahkitGreen)
                        .frame(width: 22, height: 22)
                        .overlay {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    Text("APPLE HEALTH")
                        .font(.uplift.text(11, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(Color.uplift.ahkitGreen)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 10) {
                    statsRow("Duration", value: "\(Int(stats.duration / 60))", unit: "min")
                    statsRow("Active calories", value: "\(Int(stats.activeCalories.rounded()))", unit: "kcal")
                    if let avg = stats.avgHeartRate {
                        statsRow("Avg heart rate", value: "\(Int(avg.rounded()))", unit: "bpm")
                    }
                    if let max = stats.maxHeartRate {
                        statsRow("Max heart rate", value: "\(Int(max.rounded()))", unit: "bpm")
                    }
                    if let effort = stats.effortRating {
                        statsRow("Effort rating", value: "\(effort)", unit: "/ 10")
                    }
                }
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.uplift.ahkitGreen.opacity(0.10))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.uplift.ahkitGreen.opacity(0.28), lineWidth: 0.5)
            }
        }
    }

    private func statsRow(_ label: String, value: String, unit: String) -> some View {
        HStack {
            Text(label)
                .font(.uplift.text(13, weight: .medium))
                .foregroundStyle(Color.uplift.fgMuted)
            Spacer()
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Num(value, size: 14, color: .uplift.fg)
                Text(unit)
                    .font(.uplift.text(11, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
            }
        }
    }

    private var actionBar: some View {
        PillBottomBar {
            Button {
                onDone()
            } label: {
                Text("Done")
                    .font(.uplift.text(15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .foregroundStyle(Color.uplift.fg)
            }
            .buttonStyle(.plain)

            Button {
                onDetail()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Detail")
                        .font(.uplift.text(15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(Color.uplift.accent, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .foregroundStyle(Color.uplift.onAccent)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }
}

// Preview omitted — WorkoutSession is a SwiftData model that requires a ModelContainer.
// Visual verification happens during integration smoke test in Task 5.
