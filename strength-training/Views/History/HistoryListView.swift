//
//  HistoryListView.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI

struct HistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HistoryViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    HistoryContent(viewModel: vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("History")
            .onAppear {
                if viewModel == nil {
                    viewModel = HistoryViewModel(modelContext: modelContext)
                }
            }
        }
    }
}

private struct HistoryContent: View {
    @Bindable var viewModel: HistoryViewModel

    var body: some View {
        let grouped = viewModel.groupedSessions()

        List {
            // Filter chips
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(label: "All", isSelected: viewModel.filterDayType == nil) {
                            viewModel.filterDayType = nil
                        }
                        ForEach(DayType.allCases) { dayType in
                            FilterChip(
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
                            NavigationLink {
                                SessionDetailView(session: session)
                            } label: {
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

private struct FilterChip: View {
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

            let exerciseCount = session.exerciseRecords.filter { !$0.sets.isEmpty }.count
            Text("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
