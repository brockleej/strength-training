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
        NavigationStack(path: $navigationPath) {
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

    var body: some View {
        let grouped = viewModel.groupedSessions(from: sessions)

        List {
            // Filter chips
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        LegacyFilterChip(label: "All", isSelected: viewModel.filterDayType == nil) {
                            viewModel.filterDayType = nil
                        }
                        ForEach(DayType.allCases) { dayType in
                            LegacyFilterChip(
                                label: dayType.rawValue,
                                isSelected: viewModel.filterDayType == dayType
                            ) {
                                viewModel.filterDayType = dayType
                            }
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if grouped.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Workouts Yet",
                        systemImage: "dumbbell",
                        description: Text("Complete a workout to see it here.")
                    )
                }
            } else {
                ForEach(grouped, id: \.0) { monthLabel, sessions in
                    Section(monthLabel) {
                        ForEach(sessions) { session in
                            NavigationLink(value: session) {
                                SessionRow(session: session)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                viewModel.deleteSession(sessions[index])
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct LegacyFilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct SessionRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack {
            Image(systemName: session.dayType.systemImage)
                .font(.title3)
                .frame(width: 36, height: 36)
                .foregroundStyle(session.dayType.color)
                .background(session.dayType.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(session.dayType.rawValue) Day")
                    .font(.headline)
                Text(session.date.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            let exerciseCount = session.exerciseRecordsArray.filter { !$0.setsArray.isEmpty }.count
            Text("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
