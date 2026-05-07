//
//  HistoryListView.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI
import SwiftData

struct HistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<WorkoutSession> { $0.isCompleted == true },
           sort: \WorkoutSession.date, order: .reverse)
    private var sessions: [WorkoutSession]

    @State private var viewModel: HistoryViewModel?
    @State private var navigationPath = NavigationPath()
    @Binding var reviewSession: WorkoutSession?

    var body: some View {
        // KEEP path binding — Today's Yesterday card and post-finish Summary
        // deep-link via navigationPath.append(session). Removing the binding
        // silently breaks both routes.
        NavigationStack(path: $navigationPath) {
            Group {
                if let vm = viewModel {
                    HistoryContent(
                        viewModel: vm,
                        sessions: sessions,
                        navigationPath: $navigationPath
                    )
                } else {
                    ProgressView()
                }
            }
            .background(Color.uplift.bgElev)
            .toolbar(.hidden, for: .navigationBar) // hide system bar; we own the chrome via NavBar
            .navigationDestination(for: WorkoutSession.self) { session in
                SessionDetailView(session: session)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = HistoryViewModel(modelContext: modelContext)
            }
            navigateToReviewSession()
        }
        .onChange(of: reviewSession) { _, _ in
            navigateToReviewSession()
        }
    }

    /// Defer the navigation push so the NavigationStack is laid out and
    /// active after a tab switch before we modify its path.
    private func navigateToReviewSession() {
        guard let session = reviewSession else { return }
        reviewSession = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            navigationPath.append(session)
        }
    }
}

private struct HistoryContent: View {
    @Bindable var viewModel: HistoryViewModel
    let sessions: [WorkoutSession]
    @Binding var navigationPath: NavigationPath

    var body: some View {
        let grouped = viewModel.groupedSessions(from: sessions)

        VStack(spacing: 0) {
            NavBar(
                title: "History",
                style: .large(size: 38),
                leading: { CircleButton(icon: "magnifyingglass") {} },     // no-op for now
                trailing: { CircleButton(icon: "ellipsis") {} }            // no-op for now
            )

            List {
                Section { summaryStripCard }
                    .listRowBackground(Color.uplift.bgElev)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))

                Section { filterChipRow }
                    .listRowBackground(Color.uplift.bgElev)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 0, trailing: 0))

                if grouped.isEmpty {
                    Section { emptyState }
                        .listRowBackground(Color.uplift.bgElev)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(grouped, id: \.0) { (monthLabel, sessions) in
                        Section {
                            ForEach(sessions) { session in
                                // Tap-via-onTapGesture pattern (NOT NavigationLink) — embedding
                                // NavigationLink in a List with custom chevron produces a
                                // double-chevron in iOS 17/18+. We drive the path manually instead.
                                SessionRow(session: session)
                                    .contentShape(Rectangle())
                                    .onTapGesture { navigationPath.append(session) }
                                    .listRowBackground(Color.uplift.bgElev)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                            }
                            .onDelete { indexSet in
                                for index in indexSet { viewModel.deleteSession(sessions[index]) }
                            }
                        } header: {
                            sectionHeaderRow(monthLabel)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.uplift.bgElev)
        }
        .background(Color.uplift.bgElev)
    }

    // MARK: - Subviews

    private var summaryStripCard: some View {
        let stats = HistorySummaryStats.thisMonth(allCompletedSessions: Array(sessions))
        return HStack(spacing: 12) {
            SummaryStat(
                label: "This month",
                value: "\(stats.sessionCount)",
                unit: stats.sessionCount == 1 ? "session" : "sessions"
            )
            Divider().frame(height: 36).background(Color.uplift.hairline)
            SummaryStat(
                label: "Volume",
                value: HistorySummaryStats.formatVolume(stats.totalVolumeLb),
                unit: "lb"
            )
            Divider().frame(height: 36).background(Color.uplift.hairline)
            SummaryStat(
                label: "PRs",
                value: "\(stats.prCount)",
                tone: stats.prCount > 0 ? .pr : .neutral
            )
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.uplift.surface1))
        .padding(.top, 4)
    }

    private var filterChipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All", isSelected: viewModel.filterDayType == nil) {
                    viewModel.filterDayType = nil
                }
                ForEach(DayType.allCases) { dt in
                    FilterChip(label: dt.rawValue, isSelected: viewModel.filterDayType == dt) {
                        viewModel.filterDayType = dt
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func sectionHeaderRow(_ label: String) -> some View {
        SectionHeader(label) {
            EmptyView()
        }
        .padding(.horizontal, 20)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.uplift.bgElev)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No workouts yet",
            systemImage: "dumbbell",
            description: Text("Complete a workout to see it here.")
        )
        .padding(.vertical, 40)
    }
}

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.uplift.text(13, weight: .semibold))
                .foregroundStyle(isSelected ? Color.uplift.onAccent : Color.uplift.fg)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? Color.uplift.accent : Color.uplift.surface1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct SessionRow: View {
    let session: WorkoutSession

    private var prCount: Int { SessionDetailLiftStats.prCount(for: session) }
    private var durationMin: Int { WorkoutSummaryStats.formatDurationMin(WorkoutSummaryStats.durationSeconds(for: session)) }
    private var volumeLb: Int { WorkoutSummaryStats.totalVolume(for: session) }

    var body: some View {
        HStack(spacing: 12) {
            DayChip(dayType: session.dayType, size: .sm)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(session.dayType.rawValue)
                        .font(.uplift.text(15, weight: .semibold))
                        .kerning(-0.2)
                        .foregroundStyle(Color.uplift.fg)
                    if prCount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.uplift.pr)
                            Text("\(prCount)")
                                .font(.uplift.mono(11, weight: .semibold))
                                .foregroundStyle(Color.uplift.pr)
                        }
                    }
                }
                metaRow
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.uplift.fgDim)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.uplift.surface1))
    }

    private var metaRow: some View {
        HStack(spacing: 10) {
            Text(formattedDate(session.date))
                .font(.uplift.text(12, weight: .medium))
                .foregroundStyle(Color.uplift.fgMuted)
            dot
            Text("\(durationMin) min")
                .font(.uplift.mono(12, weight: .medium))
                .foregroundStyle(Color.uplift.fgMuted)
            dot
            Text(formattedVolume(volumeLb))
                .font(.uplift.mono(12, weight: .medium))
                .foregroundStyle(Color.uplift.fgMuted)
        }
    }

    private var dot: some View {
        Text("·").font(.uplift.text(12, weight: .medium)).foregroundStyle(Color.uplift.fgMuted)
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: date)
    }

    private func formattedVolume(_ lb: Int) -> String {
        if lb == 0 { return "—" }
        if lb >= 100_000 { return "\(Int((Double(lb) / 1000.0).rounded()))k lb" }
        return "\(lb.formatted(.number)) lb"
    }
}
