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

    // MARK: - Lifts section

    private var liftsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Lifts")
            VStack(spacing: 6) {
                ForEach(liftRows) { row in
                    NavigationLink {
                        if let exercise = exercise(for: row.exerciseID) {
                            ExerciseDrillDownView(exercise: exercise, modelContext: modelContext)
                        }
                    } label: {
                        LiftRowCell(row: row)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func exercise(for id: UUID) -> Exercise? {
        session.exerciseRecordsArray.first { $0.exercise?.id == id }?.exercise
    }

    // MARK: - Apple Health card

    @ViewBuilder
    private var appleHealthCard: some View {
        if let stats = healthStats {
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
                    ahRow("Duration", value: "\(Int(stats.duration / 60))", unit: "min")
                    ahRow("Active calories", value: "\(Int(stats.activeCalories.rounded()))", unit: "kcal")
                    if let avg = stats.avgHeartRate {
                        ahRow("Avg heart rate", value: "\(Int(avg.rounded()))", unit: "bpm")
                    }
                    if let maxHR = stats.maxHeartRate {
                        ahRow("Max heart rate", value: "\(Int(maxHR.rounded()))", unit: "bpm")
                    }
                    if let effort = stats.effortRating ?? session.effortRating {
                        ahRow("Effort rating", value: "\(effort)", unit: effortLabel(effort))
                    }
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.uplift.ahkitGreen.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.uplift.ahkitGreen.opacity(0.28), lineWidth: 0.5))
        }
    }

    private func ahRow(_ label: String, value: String, unit: String) -> some View {
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

    private func effortLabel(_ rating: Int) -> String {
        switch rating {
        case 1...3: return "easy"
        case 4...6: return "moderate"
        case 7, 8: return "hard"
        case 9, 10: return "all out"
        default: return ""
        }
    }
}

// MARK: - Lift row cell

private struct LiftRowCell: View {
    let row: SessionDetailLiftStats.LiftRow

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.exerciseName)
                        .font(.uplift.text(15, weight: .semibold))
                        .kerning(-0.2)
                        .foregroundStyle(Color.uplift.fg)
                    if row.isPR {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.uplift.pr)
                    }
                }
                Text("\(row.setsCount) × \(row.topReps)")
                    .font(.uplift.text(12, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedWeight(row.topWeightLb) + " lb")
                    .font(.uplift.mono(14, weight: .semibold))
                    .foregroundStyle(Color.uplift.fg)
                deltaLabel
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.uplift.surface1))
    }

    @ViewBuilder
    private var deltaLabel: some View {
        if let d = row.deltaVsLastLb, d != 0 {
            let sign = d > 0 ? "+" : ""
            Text("\(sign)\(formattedWeight(d)) lb")
                .font(.uplift.mono(11, weight: .semibold))
                .foregroundStyle(d > 0 ? Color.uplift.up : Color.uplift.down)
        } else {
            Text("—")
                .font(.uplift.mono(11, weight: .semibold))
                .foregroundStyle(Color.uplift.fgDim)
        }
    }

    private func formattedWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", w)
            : String(format: "%.1f", w)
    }
}
