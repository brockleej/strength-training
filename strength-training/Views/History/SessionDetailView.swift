//
//  SessionDetailView.swift
//  strength-training
//

import SwiftUI
import SwiftData

struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let session: WorkoutSession

    @State private var healthStats: HealthKitWorkoutStats?
    @State private var loadedStats = false

    @Query(filter: #Predicate<WorkoutSession> { $0.isCompleted == true },
           sort: \WorkoutSession.date, order: .reverse)
    private var completedSessions: [WorkoutSession]

    private var sortedRecords: [ExerciseRecord] {
        session.exerciseRecordsArray
            .filter { !$0.setsArray.isEmpty }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var prNames: [String] {
        SessionMath.e1RMPRExerciseNames(for: session, allSessions: completedSessions)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                statsCard
                if !prNames.isEmpty {
                    prCallout
                        .padding(.top, 8)
                }
                SectionHeader("Lifts")
                VStack(spacing: 8) {
                    ForEach(sortedRecords) { record in
                        LiftCard(record: record, sessionDate: session.date, modelContext: modelContext)
                    }
                }
                if healthStats != nil || session.healthKitWorkoutUUID != nil {
                    SectionHeader("Apple Health")
                    healthCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color.uplift.bgElev)
        .scrollIndicators(.hidden)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !loadedStats, let uuid = session.healthKitWorkoutUUID else { return }
            loadedStats = true
            let service = HealthKitWorkoutService()
            healthStats = await service.fetchWorkoutStats(for: uuid)
        }
    }

    // MARK: - Sections

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                DayChip(dayType: session.dayType, size: .sm)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(session.dayType.rawValue) day")
                        .textCase(.uppercase)
                        .font(.uplift.text(11, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(session.dayType.upliftInk)
                    Text(session.date.formatted(.dateTime.weekday(.wide).month(.wide).day().hour().minute()))
                        .font(.uplift.text(12, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                }
            }
            Text(session.dayType.rawValue)
                .font(.uplift.display(30, weight: .bold))
                .kerning(-0.7)
                .foregroundStyle(Color.uplift.fg)
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var statsCard: some View {
        HStack(spacing: 14) {
            Stat(label: "Duration",
                 value: healthStats.map { "\(max(1, Int(($0.duration / 60).rounded())))" } ?? "—",
                 unit: healthStats == nil ? nil : "min")
            Stat(label: "Volume", value: TodayStats.formatVolume(SessionMath.volume(of: session)), unit: "lb")
            Stat(label: "Sets", value: "\(SessionMath.setCount(of: session))")
            Stat(label: "PRs", value: "\(prNames.count)", tone: prNames.isEmpty ? .uplift.fg : .uplift.pr)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.uplift.surface1)
        }
    }

    private var prCallout: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.uplift.pr.opacity(0.18))
                Image(systemName: "trophy.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.uplift.pr)
            }
            .frame(width: 36, height: 36)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(prNames.count) personal record\(prNames.count == 1 ? "" : "s")")
                    .font(.uplift.text(14, weight: .semibold))
                    .foregroundStyle(Color.uplift.fg)
                Text(prNames.joined(separator: " · "))
                    .font(.uplift.text(12, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.uplift.pr.opacity(0.10))
        }
    }

    private var healthCard: some View {
        VStack(spacing: 0) {
            if let stats = healthStats {
                healthRow(icon: "timer", tint: .uplift.ahGreen, label: "Duration",
                          value: WorkoutFormat.elapsed(stats.duration))
                divider
                healthRow(icon: "flame.fill", tint: .uplift.kcalFlame, label: "Active Calories",
                          value: "\(Int(stats.activeCalories)) kcal")
                if let avg = stats.avgHeartRate {
                    divider
                    healthRow(icon: "heart.fill", tint: .uplift.ahRed, label: "Avg Heart Rate",
                              value: "\(Int(avg)) bpm")
                }
                if let max = stats.maxHeartRate {
                    divider
                    healthRow(icon: "heart.fill", tint: .uplift.ahRed, label: "Max Heart Rate",
                              value: "\(Int(max)) bpm")
                }
                if let effort = stats.effortRating ?? session.effortRating {
                    divider
                    healthRow(icon: "figure.strengthtraining.functional", tint: EffortScale.color(for: effort),
                              label: "Effort", value: "\(effort)/10 · \(EffortScale.label(for: effort))")
                }
            } else {
                Text("Loading Apple Health data…")
                    .font(.uplift.text(13, weight: .medium))
                    .foregroundStyle(Color.uplift.fgDim)
                    .padding(.vertical, 14)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.uplift.ahGreen.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.uplift.ahGreen.opacity(0.25), lineWidth: 0.5)
        }
    }

    private func healthRow(icon: String, tint: Color, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(tint)
                .frame(width: 22)
                .accessibilityHidden(true)
            Text(label)
                .font(.uplift.text(14, weight: .medium))
                .foregroundStyle(Color.uplift.fg)
            Spacer()
            Text(value)
                .font(.uplift.mono(14, weight: .semibold))
                .foregroundStyle(Color.uplift.fg)
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }

    private var divider: some View {
        Rectangle().fill(Color.uplift.hairline).frame(height: 0.5)
    }
}

// MARK: - Lift card (header summary + always-visible sets)

private struct LiftCard: View {
    let record: ExerciseRecord
    let sessionDate: Date
    let modelContext: ModelContext

    private var sortedSets: [SetRecord] {
        record.setsArray.sorted { $0.setNumber < $1.setNumber }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let exercise = record.exercise {
                NavigationLink {
                    ExerciseDrillDownView(exercise: exercise, modelContext: modelContext)
                } label: {
                    header(exercise)
                }
                .buttonStyle(.plain)
            }

            Rectangle().fill(Color.uplift.hairline).frame(height: 0.5)

            ForEach(Array(sortedSets.enumerated()), id: \.element.id) { index, set in
                setRow(set)
                if index < sortedSets.count - 1 {
                    Rectangle().fill(Color.uplift.hairline).frame(height: 0.5)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.uplift.surface1)
        }
    }

    private func header(_ exercise: Exercise) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.uplift.text(15, weight: .semibold))
                        .kerning(-0.2)
                        .foregroundStyle(Color.uplift.fg)
                    if isPR {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.uplift.pr)
                            .accessibilityLabel("Personal record")
                    }
                }
                HStack(spacing: 6) {
                    modePill
                    Text("\(sortedSets.count) set\(sortedSets.count == 1 ? "" : "s")")
                        .font(.uplift.text(12, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(StepperLogic.format(topWeight)) lb")
                    .font(.uplift.mono(14, weight: .semibold))
                    .foregroundStyle(Color.uplift.weightTint)
                trendLine
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.uplift.fgDim)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var modePill: some View {
        HStack(spacing: 3) {
            Image(systemName: record.trainingMode.systemImage)
                .font(.system(size: 9, weight: .semibold))
                .accessibilityHidden(true)
            Text(record.trainingMode.rawValue)
                .font(.uplift.text(10, weight: .semibold))
        }
        .foregroundStyle(record.trainingMode == .lowWeightHighReps ? Color.uplift.endurance : Color.uplift.fgMuted)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(Capsule().fill(Color.uplift.surface2))
    }

    @ViewBuilder
    private var trendLine: some View {
        if let d = delta {
            HStack(spacing: 3) {
                Image(systemName: d > 0 ? "arrow.up.right" : (d < 0 ? "arrow.down.right" : "arrow.right"))
                    .font(.system(size: 9, weight: .bold))
                Text("\(d >= 0 ? "+" : "")\(String(format: "%.0f", d)) e1RM")
                    .font(.uplift.mono(11, weight: .semibold))
            }
            .foregroundStyle(d > 0 ? Color.uplift.up : (d < 0 ? Color.uplift.down : Color.uplift.flat))
        }
    }

    private func setRow(_ set: SetRecord) -> some View {
        HStack {
            Text("Set \(set.setNumber)")
                .font(.uplift.text(13, weight: .medium))
                .foregroundStyle(Color.uplift.fgMuted)
            if set.isWarmup {
                Text("Warmup")
                    .font(.uplift.text(10, weight: .semibold))
                    .foregroundStyle(Color.uplift.customBadge)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.uplift.customBadge.opacity(0.16)))
            }
            Spacer()
            PairText.pair(weight: set.weightLbs, reps: set.reps, font: .uplift.mono(13, weight: .semibold))
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Set \(set.setNumber)\(set.isWarmup ? ", warmup" : ""), \(StepperLogic.format(set.weightLbs)) pounds, \(set.reps) reps")
    }

    // MARK: - Computations (ported verbatim from the old ExerciseHeaderRow)

    private var topWeight: Double {
        sortedSets.filter { !$0.isWarmup }.map(\.weightLbs).max() ?? 0
    }

    private var currentE1RM: Double {
        record.setsArray
            .filter { !$0.isWarmup }
            .map { E1RM.estimate(weightLbs: $0.weightLbs, reps: $0.reps) }
            .max() ?? 0
    }

    private var previousRecord: ExerciseRecord? {
        record.exercise?.recordsArray
            .filter { rec in
                rec.id != record.id &&
                rec.session?.isCompleted == true &&
                (rec.session?.date ?? .distantFuture) < sessionDate
            }
            .sorted { ($0.session?.date ?? .distantPast) > ($1.session?.date ?? .distantPast) }
            .first
    }

    private var previousE1RM: Double? {
        guard let prev = previousRecord else { return nil }
        return prev.setsArray
            .filter { !$0.isWarmup }
            .map { E1RM.estimate(weightLbs: $0.weightLbs, reps: $0.reps) }
            .max()
    }

    private var allTimeE1RM: Double {
        let completedRecords = record.exercise?.recordsArray.filter { $0.session?.isCompleted == true } ?? []
        return completedRecords
            .flatMap { $0.setsArray.filter { !$0.isWarmup } }
            .map { E1RM.estimate(weightLbs: $0.weightLbs, reps: $0.reps) }
            .max() ?? 0
    }

    private var isPR: Bool {
        currentE1RM > 0 && currentE1RM >= allTimeE1RM
    }

    private var delta: Double? {
        guard let prev = previousE1RM, prev > 0 else { return nil }
        return currentE1RM - prev
    }
}
