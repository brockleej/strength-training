//
//  ClientDetailView.swift
//  RockCoach
//

import SwiftUI
import SwiftData

struct ClientDetailView: View {
    @Bindable var client: CoachClient
    @Environment(\.modelContext) private var modelContext
    @State private var snapshots: [CoachProgression.Snapshot] = []
    @State private var monthly = MonthlyOverload.Review(
        thisMonthLabel: "",
        lastMonthLabel: "",
        thisMonthWorkoutCount: 0,
        lastMonthWorkoutCount: 0,
        groups: []
    )
    @State private var compareDayType: String?

    private var sessions: [CoachStoredSession] { client.sortedSessions }

    private var dayTypes: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for session in sessions {
            if seen.insert(session.dayType).inserted {
                ordered.append(session.dayType)
            }
        }
        return ordered
    }

    private func sessionCount(for day: String) -> Int {
        sessions.filter { $0.dayType == day }.count
    }

    var body: some View {
        List {
            Section {
                TextField("Name", text: $client.displayName)
                    .textInputAutocapitalization(.words)
                TextField("Notes", text: $client.notes, axis: .vertical)
                    .lineLimit(2...4)
            } header: {
                Text("Client")
            }

            if !dayTypes.isEmpty {
                Section("Split") {
                    ForEach(dayTypes, id: \.self) { day in
                        NavigationLink {
                            LiftCompareView(client: client, initialDayType: day)
                        } label: {
                            HStack {
                                Text(day)
                                Spacer()
                                Text("\(sessionCount(for: day))")
                                    .foregroundStyle(Color.coach.dim)
                                    .font(.subheadline.monospacedDigit())
                            }
                        }
                    }
                }
            }

            if !sessions.isEmpty {
                Section {
                    MonthlyOverloadTable(
                        review: monthly,
                        palette: .coach,
                        emptyMessage: "Import sessions from this month or last to compare each lift’s best set.",
                        onSelect: { compareDayType = $0.dayTypeName },
                        selectionHint: "Opens side-by-side compare"
                    )
                    .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.coach.surface)
                }
            }

            if !snapshots.isEmpty {
                Section {
                    ForEach(snapshots.prefix(6)) { snap in
                        progressionRow(snap)
                    }
                    NavigationLink {
                        LiftCompareView(client: client, initialDayType: sessions.first?.dayType)
                    } label: {
                        Text("Compare side by side")
                            .foregroundStyle(Color.coach.accent)
                    }
                } header: {
                    Text("Latest vs last time")
                }
            }

            Section("Sessions") {
                if sessions.isEmpty {
                    Text("Import a RockLog file to fill this folder.")
                        .foregroundStyle(Color.coach.dim)
                } else {
                    ForEach(sessions) { session in
                        NavigationLink {
                            CoachSessionDetailView(session: session, client: client)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.dayType)
                                    .font(.headline)
                                HStack(spacing: 8) {
                                    Text(session.startedAt.formatted(date: .abbreviated, time: .omitted))
                                    if !session.rotationTrack.isEmpty {
                                        Text("Track \(session.rotationTrack)")
                                    }
                                    if let effort = session.effortRating {
                                        Text("Effort \(effort)")
                                    }
                                }
                                .font(.subheadline)
                                .foregroundStyle(Color.coach.muted)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .onDelete(perform: deleteSessions)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Color.coach.bg.ignoresSafeArea())
        .navigationTitle(client.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            CoachImportService.refreshSummary(client)
            refreshProgression()
            refreshMonthly()
        }
        .onChange(of: sessions.count) { _, _ in
            CoachImportService.refreshSummary(client)
            refreshProgression()
            refreshMonthly()
        }
        .navigationDestination(item: $compareDayType) { day in
            LiftCompareView(client: client, initialDayType: day)
        }
    }

    private func refreshMonthly() {
        monthly = MonthlyOverload.review(
            documents: client.sortedSessions.compactMap(\.document),
            now: .now,
            calendar: .current
        )
    }

    private func refreshProgression() {
        let rows = client.sortedSessions
        guard let latest = rows.first, let current = latest.document else {
            snapshots = []
            return
        }
        snapshots = CoachProgression.snapshots(
            current: current,
            history: rows.compactMap(\.document)
        )
    }

    private func progressionRow(_ snap: CoachProgression.Snapshot) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(snap.name)
                    .font(.subheadline.weight(.semibold))
                if let previous = snap.previous {
                    Text("was \(CoachProgression.setLabel(previous))")
                        .font(.caption)
                        .foregroundStyle(Color.coach.dim)
                }
            }
            Spacer()
            if let current = snap.current {
                Text(CoachProgression.setLabel(current))
                    .font(.body.monospacedDigit().weight(.semibold))
            }
            Image(systemName: symbol(for: snap.direction))
                .foregroundStyle(color(for: snap.direction))
                .frame(width: 20)
        }
    }

    private func symbol(for direction: CoachProgression.Direction) -> String {
        switch direction {
        case .up: "arrow.up"
        case .down: "arrow.down"
        case .same: "equal"
        case .new: "sparkle"
        }
    }

    private func color(for direction: CoachProgression.Direction) -> Color {
        switch direction {
        case .up: Color.coach.up
        case .down: Color.coach.down
        case .same, .new: Color.coach.muted
        }
    }

    private func deleteSessions(at offsets: IndexSet) {
        let rows = client.sortedSessions
        for index in offsets {
            modelContext.delete(rows[index])
        }
        CoachImportService.refreshSummary(client)
        try? modelContext.save()
    }
}

extension MonthlyOverloadPalette {
    static let coach = MonthlyOverloadPalette(
        nest: Color.coach.surface2,
        foreground: Color.coach.fg,
        muted: Color.coach.muted,
        dim: Color.coach.dim,
        faint: Color.coach.faint,
        accent: Color.coach.accent,
        up: Color.coach.up,
        down: Color.coach.down,
        flat: Color.coach.flat,
        hairline: Color.white.opacity(0.06),
        dayInk: { _ in Color.coach.accent }
    )
}
