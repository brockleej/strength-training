//
//  SplitProgressionSection.swift
//  RockLog Progress — same split-day spreadsheet as RockCoach.
//

import SwiftUI
import SwiftData

struct SplitProgressionSection: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<WorkoutSession> { $0.isCompleted == true },
        sort: \WorkoutSession.date,
        order: .reverse
    )
    private var sessions: [WorkoutSession]

    @Query private var exercises: [Exercise]

    @State private var dayType = ""
    @State private var columnCount = 4
    @State private var selectedExerciseID: UUID?
    @State private var grid = CoachProgression.CompareGrid(columns: [], rows: [])

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if dayTypes.count > 1 {
                dayChips
            }

            HStack {
                Text(caption)
                    .font(.uplift.text(12, weight: .medium))
                    .foregroundStyle(Color.uplift.fgDim)
                Spacer()
                Picker("Columns", selection: $columnCount) {
                    Text("3").tag(3)
                    Text("4").tag(4)
                    Text("6").tag(6)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            if grid.columns.isEmpty {
                Text(dayType.isEmpty
                     ? "Log workouts to compare sessions"
                     : "Need at least one \(dayType) session to compare.")
                    .font(.uplift.text(13, weight: .medium))
                    .foregroundStyle(Color.uplift.fgDim)
                    .padding(.vertical, 8)
            } else {
                CompareGridTable(grid: grid, palette: .uplift) { name in
                    selectedExerciseID = exercise(named: name)?.id
                }
            }
        }
        .onAppear {
            ensureDayType()
            rebuild()
        }
        .onChange(of: dayTypes) { _, _ in
            ensureDayType()
            rebuild()
        }
        .onChange(of: dayType) { _, _ in rebuild() }
        .onChange(of: columnCount) { _, _ in rebuild() }
        .onChange(of: sessions.count) { _, _ in rebuild() }
        .navigationDestination(item: $selectedExerciseID) { id in
            if let exercise = exercises.first(where: { $0.id == id }) {
                ExerciseDrillDownView(exercise: exercise, modelContext: modelContext)
            }
        }
    }

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

    private var caption: String {
        let shown = min(columnCount, max(grid.columns.count, 1))
        if dayType.isEmpty { return "Last \(shown) sessions" }
        return "Last \(shown) \(dayType)"
    }

    private func rebuild() {
        let athlete = CoachAthlete(id: UUID(), displayName: "")
        let docs = sessions
            .filter { $0.dayType == dayType }
            .compactMap { try? CoachExportService.document(from: $0, athlete: athlete) }
        grid = CoachProgression.compareGrid(from: docs, limit: columnCount)
    }

    private var dayChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(dayTypes, id: \.self) { day in
                    let selected = day == dayType
                    let ink = DayType(rawValue: day).upliftInk
                    Button {
                        dayType = day
                    } label: {
                        Text(day)
                            .font(.uplift.text(13, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(selected ? ink.opacity(0.22) : Color.uplift.surface1)
                            )
                            .foregroundStyle(selected ? ink : Color.uplift.fgMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func ensureDayType() {
        if dayType.isEmpty || !dayTypes.contains(dayType) {
            dayType = dayTypes.first ?? ""
        }
    }

    private func exercise(named name: String) -> Exercise? {
        exercises.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }
}

extension CompareGridPalette {
    static let uplift = CompareGridPalette(
        background: Color.uplift.bgElev,
        surface: Color.uplift.surface1,
        foreground: Color.uplift.fg,
        muted: Color.uplift.fgMuted,
        dim: Color.uplift.fgDim,
        accent: Color.uplift.accent,
        up: Color.uplift.up,
        down: Color.uplift.down,
        hairline: Color.uplift.hairline
    )
}
