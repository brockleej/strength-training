//
//  HistoryListView.swift
//  strength-training
//

import SwiftUI
import SwiftData

struct HistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<WorkoutSession> { $0.isCompleted == true },
           sort: \WorkoutSession.date, order: .reverse)
    private var sessions: [WorkoutSession]

    @State private var viewModel: HistoryViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    HistoryContent(viewModel: vm, sessions: sessions)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: WorkoutSession.self) { session in
                SessionDetailView(session: session)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = HistoryViewModel(modelContext: modelContext)
            }
        }
    }
}

private struct HistoryContent: View {
    @Bindable var viewModel: HistoryViewModel
    let sessions: [WorkoutSession]

    var body: some View {
        let grouped = viewModel.groupedSessions(from: sessions)

        List {
            if !sessions.isEmpty {
                summaryStrip
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))

                filterChips
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
            }

            if grouped.isEmpty {
                ContentUnavailableView(
                    "No Workouts Yet",
                    systemImage: "dumbbell",
                    description: Text("Complete a workout to see it here.")
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(grouped, id: \.0) { monthLabel, monthSessions in
                    Section {
                        ForEach(monthSessions) { session in
                            NavigationLink(value: session) {
                                HistorySessionRow(
                                    session: session,
                                    prCount: SessionMath.e1RMPRCount(for: session, allSessions: sessions)
                                )
                            }
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.uplift.surface1)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 20)
                            )
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 12, leading: 34, bottom: 12, trailing: 34))
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                viewModel.deleteSession(monthSessions[index])
                            }
                        }
                    } header: {
                        Text(monthLabel)
                            .textCase(.uppercase)
                            .font(.uplift.text(13, weight: .semibold))
                            .tracking(0.4)
                            .foregroundStyle(Color.uplift.fgMuted)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.uplift.bgElev)
    }

    // MARK: - Summary strip (current calendar month, unfiltered)

    private var summaryStrip: some View {
        let cal = Calendar.current
        let monthSessions = sessions.filter { cal.isDate($0.date, equalTo: .now, toGranularity: .month) }
        let monthVolume = monthSessions.reduce(0.0) { $0 + SessionMath.volume(of: $1) }
        let monthPRs = monthSessions.reduce(0) { $0 + SessionMath.e1RMPRCount(for: $1, allSessions: sessions) }

        return HStack(spacing: 12) {
            SummaryStat(label: "This month", value: "\(monthSessions.count)", unit: "sessions")
            Rectangle().fill(Color.uplift.hairline).frame(width: 1)
            SummaryStat(label: "Volume", value: TodayStats.formatCompactVolume(monthVolume), unit: "lb")
            Rectangle().fill(Color.uplift.hairline).frame(width: 1)
            SummaryStat(label: "PRs", value: "\(monthPRs)", tone: .uplift.pr)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.uplift.surface1)
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All", isSelected: viewModel.filterDayType == nil) {
                    viewModel.filterDayType = nil
                }
                ForEach(DayType.allCases) { dayType in
                    FilterChip(label: dayType.rawValue, isSelected: viewModel.filterDayType == dayType) {
                        viewModel.filterDayType = dayType
                    }
                }
            }
        }
    }
}

private struct HistorySessionRow: View {
    let session: WorkoutSession
    let prCount: Int

    var body: some View {
        HStack(spacing: 12) {
            DayChip(dayType: session.dayType, size: .sm)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(session.dayType.rawValue)
                        .font(.uplift.text(15, weight: .semibold))
                        .kerning(-0.2)
                        .foregroundStyle(Color.uplift.fg)
                    if prCount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 11))
                                .accessibilityHidden(true)
                            Text("\(prCount)")
                                .font(.uplift.mono(11, weight: .semibold))
                        }
                        .foregroundStyle(Color.uplift.pr)
                    }
                }
                (
                    Text(session.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.uplift.text(12, weight: .medium))
                    + Text(" · ").font(.uplift.text(12, weight: .medium))
                    + Text("\(TodayStats.formatVolume(SessionMath.volume(of: session))) lb")
                        .font(.uplift.mono(12, weight: .medium))
                    + Text(" · ").font(.uplift.text(12, weight: .medium))
                    + Text("\(SessionMath.setCount(of: session)) sets")
                        .font(.uplift.text(12, weight: .medium))
                )
                .foregroundStyle(Color.uplift.fgMuted)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowAccessibilityLabel)
    }

    private var rowAccessibilityLabel: String {
        var label = "\(session.dayType.rawValue), \(session.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))"
        label += ", \(TodayStats.formatVolume(SessionMath.volume(of: session))) pounds, \(SessionMath.setCount(of: session)) sets"
        if prCount > 0 {
            label += ", \(prCount) personal record\(prCount == 1 ? "" : "s")"
        }
        return label
    }
}
