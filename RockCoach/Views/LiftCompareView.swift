//
//  LiftCompareView.swift
//  RockCoach — same split day, several sessions side by side.
//

import SwiftUI

struct LiftCompareView: View {
    let client: CoachClient
    @State private var dayType: String
    @State private var columnCount = 4
    @State private var grid = CoachProgression.CompareGrid(columns: [], rows: [])

    init(client: CoachClient, initialDayType: String? = nil) {
        self.client = client
        let days = Self.dayTypes(in: client)
        _dayType = State(initialValue: initialDayType ?? days.first ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            pickerBar
            if grid.columns.isEmpty {
                emptyState
            } else {
                table
            }
        }
        .background(Color.coach.bg.ignoresSafeArea())
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: rebuild)
        .onChange(of: dayType) { _, _ in rebuild() }
        .onChange(of: columnCount) { _, _ in rebuild() }
    }

    private var dayTypes: [String] { Self.dayTypes(in: client) }

    private static func dayTypes(in client: CoachClient) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for session in client.sortedSessions {
            if seen.insert(session.dayType).inserted {
                ordered.append(session.dayType)
            }
        }
        return ordered
    }

    private var pickerBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            if dayTypes.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(dayTypes, id: \.self) { day in
                            Button {
                                dayType = day
                            } label: {
                                Text(day)
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule().fill(
                                            day == dayType
                                                ? Color.coach.accent.opacity(0.22)
                                                : Color.coach.surface
                                        )
                                    )
                                    .foregroundStyle(day == dayType ? Color.coach.accent : Color.coach.muted)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            HStack {
                Text("Last \(min(columnCount, max(grid.columns.count, 1))) \(dayType.isEmpty ? "sessions" : dayType)")
                    .font(.caption)
                    .foregroundStyle(Color.coach.dim)
                Spacer()
                Picker("Columns", selection: $columnCount) {
                    Text("3").tag(3)
                    Text("4").tag(4)
                    Text("6").tag(6)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(Color.coach.bg)
    }

    private var emptyState: some View {
        Text("Need at least one \(dayType) session to compare.")
            .font(.subheadline)
            .foregroundStyle(Color.coach.muted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var table: some View {
        ScrollView {
            CompareGridTable(grid: grid, palette: .coach)
                .padding(.leading, 16)
                .padding(.bottom, 24)
        }
    }

    private func rebuild() {
        let docs = client.sortedSessions
            .filter { $0.dayType == dayType }
            .compactMap(\.document)
        grid = CoachProgression.compareGrid(from: docs, limit: columnCount)
    }
}

extension CompareGridPalette {
    static let coach = CompareGridPalette(
        background: Color.coach.bg,
        surface: Color.coach.surface,
        foreground: Color.coach.fg,
        muted: Color.coach.muted,
        dim: Color.coach.dim,
        accent: Color.coach.accent,
        up: Color.coach.up,
        down: Color.coach.down,
        hairline: Color.white.opacity(0.06)
    )
}
