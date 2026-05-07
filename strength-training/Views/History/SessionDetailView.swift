//
//  SessionDetailView.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI
import SwiftData

struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let session: WorkoutSession

    @State private var healthStats: HealthKitWorkoutStats?
    @State private var loadedStats = false
    @State private var showDeleteConfirm = false

    private var liftRows: [SessionDetailLiftStats.LiftRow] { SessionDetailLiftStats.rows(for: session) }
    private var prCount: Int { liftRows.filter(\.isPR).count }
    private var prNames: [String] { liftRows.filter(\.isPR).map(\.exerciseName) }

    var body: some View {
        VStack(spacing: 0) {
            NavBar(title: session.dayType.rawValue, style: .compact,
                leading: { CircleButton(icon: "chevron.left") { dismiss() } },
                trailing: {
                    Menu {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete session", systemImage: "trash")
                        }
                    } label: {
                        ZStack {
                            Circle().fill(Color.uplift.surface1).frame(width: 36, height: 36)
                            Image(systemName: "ellipsis")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.uplift.fg)
                        }
                    }
                }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heroBlock
                        .padding(.bottom, 16)
                    statsCard
                        .padding(.bottom, 8)
                    if prCount > 0 {
                        prCallout
                            .padding(.top, 6)
                            .padding(.bottom, 6)
                    }
                    liftsSection                  // Task 6
                        .padding(.top, 4)
                    if healthStats != nil {
                        appleHealthCard           // Task 6
                            .padding(.top, 12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.uplift.bgElev)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Delete this session?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(session)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the session and its lifts.")
        }
        .task {
            guard !loadedStats, let uuid = session.healthKitWorkoutUUID else { return }
            loadedStats = true
            let service = HealthKitWorkoutService()
            healthStats = await service.fetchWorkoutStats(for: uuid)
        }
    }

    // MARK: - Hero

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                DayChip(dayType: session.dayType, size: .sm)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(session.dayType.rawValue.uppercased()) DAY")
                        .font(.uplift.text(11, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(dayInk)
                    Text(formattedHeroSubtitle(session.date))
                        .font(.uplift.text(12, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                }
            }
            Text(session.dayType.rawValue)
                .font(.uplift.display(30, weight: .bold))
                .kerning(-0.8)
                .foregroundStyle(Color.uplift.fg)
        }
    }

    private var dayInk: Color {
        switch session.dayType {
        case .arms:     .uplift.armsInk
        case .legs:     .uplift.legsInk
        case .fullBody: .uplift.fullInk
        }
    }

    private func formattedHeroSubtitle(_ date: Date) -> String {
        let dateF = DateFormatter(); dateF.dateFormat = "EEEE, MMM d"
        let timeF = DateFormatter(); timeF.dateFormat = "h:mm a"
        return "\(dateF.string(from: date)) · \(timeF.string(from: date).lowercased())"
    }

    // MARK: - Stats card

    private var statsCard: some View {
        let durationMin = WorkoutSummaryStats.formatDurationMin(WorkoutSummaryStats.durationSeconds(for: session))
        let volumeLb = WorkoutSummaryStats.totalVolume(for: session)
        let setCount = WorkoutSummaryStats.totalSets(for: session)
        return HStack(spacing: 14) {
            Stat(label: "Duration", value: "\(durationMin)", unit: "min")
            Stat(label: "Volume", value: volumeLb.formatted(.number), unit: "lb")
            Stat(label: "Sets", value: "\(setCount)")
            statTinted(label: "PRs", value: "\(prCount)", tinted: prCount > 0)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.uplift.surface1))
    }

    /// Stat-shaped cell with optional amber tint for PR count.
    private func statTinted(label: String, value: String, tinted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.uplift.text(11, weight: .semibold))
                .tracking(0.2)
                .foregroundStyle(Color.uplift.fgMuted)
            Num(value, size: 20, weight: .bold, color: tinted ? .uplift.pr : .uplift.fg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - PR callout

    private var prCallout: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.uplift.pr.opacity(0.18)).frame(width: 36, height: 36)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.uplift.pr)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(prCount) personal record\(prCount == 1 ? "" : "s")")
                    .font(.uplift.text(14, weight: .semibold))
                    .foregroundStyle(Color.uplift.fg)
                Text(prNames.joined(separator: " · "))
                    .font(.uplift.text(12, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.uplift.pr.opacity(0.10)))
    }

    // Stubbed for this task — implemented in Task 6
    private var liftsSection: some View { EmptyView() }
    private var appleHealthCard: some View { EmptyView() }
}
