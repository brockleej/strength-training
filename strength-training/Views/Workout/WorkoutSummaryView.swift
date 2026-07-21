//
//  WorkoutSummaryView.swift
//  strength-training
//
//  Post-finish summary (after the effort-rating sheet resolves).
//  Done → back to Today. View Details → SessionDetailView pushed in the
//  Workout tab's stack.
//

import SwiftUI
import SwiftData

struct WorkoutSummaryView: View {
    let session: WorkoutSession
    @Bindable var workoutVM: WorkoutViewModel

    @State private var hkStats: HealthKitWorkoutStats?

    @Query(
        filter: #Predicate<WorkoutSession> { $0.isCompleted == true },
        sort: \WorkoutSession.date,
        order: .reverse
    )
    private var completedSessions: [WorkoutSession]

    private var comparison: SessionMath.SessionComparison? {
        SessionMath.comparison(for: session, among: completedSessions)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.uplift.up)
                        .accessibilityHidden(true)
                    Text("Workout complete")
                        .textCase(.uppercase)
                        .font(.uplift.text(13, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(Color.uplift.up)
                }
                .padding(.top, 24)

                Text(headline)
                    .font(.uplift.display(32, weight: .bold))
                    .kerning(-0.7)
                    .foregroundStyle(Color.uplift.fg)
                    .padding(.top, 12)

                HStack(spacing: 8) {
                    Text("\(session.day.rawValue) · \(session.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))")
                        .font(.uplift.text(14, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                    if let badge = session.track.badge {
                        Text(badge)
                            .font(.uplift.text(11, weight: .bold))
                            .foregroundStyle(Color.uplift.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.uplift.accent.opacity(0.16)))
                    }
                    if let rating = session.effortRating {
                        Text("Effort \(rating) · \(EffortScale.label(for: rating))")
                            .font(.uplift.text(11, weight: .semibold))
                            .foregroundStyle(EffortScale.color(for: rating))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(EffortScale.color(for: rating).opacity(0.16)))
                    }
                }
                .padding(.top, 6)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    BigStat(label: "Duration", value: durationText, unit: durationText == "—" ? nil : "min")
                    BigStat(label: "Volume", value: TodayStats.formatVolume(SessionMath.volume(of: session)), unit: "lb")
                    BigStat(label: "Sets", value: "\(SessionMath.setCount(of: session))")
                    BigStat(label: "PRs", value: "\(prCount)", tone: prCount > 0 ? .uplift.pr : .uplift.fg)
                }
                .padding(18)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.uplift.surface1)
                }
                .padding(.top, 22)

                if let comparison {
                    SessionComparisonCard(comparison: comparison)
                        .padding(.top, 12)
                } else {
                    firstSessionNote
                        .padding(.top, 12)
                }

                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .background(Color.uplift.bgElev.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
        .task {
            if let uuid = session.healthKitWorkoutUUID {
                hkStats = await workoutVM.healthKitService.fetchWorkoutStats(for: uuid)
            }
        }
    }

    private var headline: String {
        if prCount > 0 { return prCount == 1 ? "New PR." : "New PRs." }
        if let comparison, comparison.volumeDelta > 0 { return "Volume up." }
        return "Strong session."
    }

    private var firstSessionNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "flag.fill")
                .foregroundStyle(Color.uplift.accent)
            Text("First logged \(session.day.rawValue) session — next time you’ll see volume and set deltas here.")
                .font(.uplift.text(13, weight: .medium))
                .foregroundStyle(Color.uplift.fgMuted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.uplift.surface1)
        }
    }

    private var actionBar: some View {
        PillBottomBar {
            Button {
                workoutVM.dismissSummaryToToday()
            } label: {
                Text("Done")
                    .font(.uplift.text(15, weight: .semibold))
                    .padding(.vertical, 14)
                    .padding(.horizontal, 22)
                    .foregroundStyle(Color.uplift.fg)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                workoutVM.dismissSummaryToDetail()
            } label: {
                Text("View Details")
                    .font(.uplift.text(15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.uplift.accent, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .foregroundStyle(Color.uplift.onAccent)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 12)
    }

    private var durationText: String {
        guard let stats = hkStats else { return "—" }
        return "\(max(1, Int((stats.duration / 60).rounded())))"
    }

    private var prCount: Int {
        SessionMath.e1RMPRCount(for: session, allSessions: completedSessions)
    }
}

#Preview {
    WorkoutSummaryView(
        session: {
            let descriptor = FetchDescriptor<WorkoutSession>()
            return (try? previewContainer.mainContext.fetch(descriptor))?.first
                ?? WorkoutSession(dayType: .arms)
        }(),
        workoutVM: WorkoutViewModel(
            modelContext: previewContainer.mainContext,
            healthKitService: HealthKitWorkoutService()
        )
    )
    .modelContainer(previewContainer)
    .preferredColorScheme(.dark)
}
