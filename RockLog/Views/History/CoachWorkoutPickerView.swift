//
//  CoachWorkoutPickerView.swift
//  RockLog
//
//  Multi-select completed workouts to send to RockCoach.
//

import SwiftUI
import SwiftData

struct CoachWorkoutPickerView: View {
    var initiallySelected: Set<UUID> = []

    @Environment(\.dismiss) private var dismiss
    @Query(
        filter: #Predicate<WorkoutSession> { $0.isCompleted == true },
        sort: \WorkoutSession.date,
        order: .reverse
    )
    private var sessions: [WorkoutSession]

    @State private var selected: Set<UUID> = []
    @State private var sendError: String?
    @State private var didApplyInitial = false

    private var grouped: [(String, [WorkoutSession])] {
        let filtered = sessions.filter { $0.isCompleted && !$0.isPlanned && !$0.isSkippedPlan }
        let dict = Dictionary(grouping: filtered) {
            $0.date.formatted(.dateTime.month(.wide).year())
        }
        return dict.sorted { ($0.value.first?.date ?? .distantPast) > ($1.value.first?.date ?? .distantPast) }
    }

    private var selectedSessions: [WorkoutSession] {
        sessions
            .filter { selected.contains($0.id) }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        List {
            if grouped.isEmpty {
                EmptyListState(
                    title: "No workouts to send",
                    systemImage: "paperplane",
                    description: "Finish a workout first, then pick it here."
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(grouped, id: \.0) { monthLabel, monthSessions in
                    Section {
                        ForEach(monthSessions) { session in
                            Button {
                                toggle(session.id)
                            } label: {
                                pickerRow(session)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.uplift.surface1)
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
        .navigationTitle("Choose workouts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Last week") { selectLastWeek() }
                    .disabled(sessions.isEmpty)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: sendSelected) {
                Text(sendTitle)
                    .font(.uplift.text(16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Color.uplift.accent.opacity(selected.isEmpty ? 0.4 : 1),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .foregroundStyle(Color.uplift.onAccent)
            }
            .buttonStyle(.plain)
            .disabled(selected.isEmpty)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(Color.uplift.bgElev.opacity(0.92))
            .accessibilityLabel(sendTitle)
        }
        .alert("Couldn’t send", isPresented: Binding(
            get: { sendError != nil },
            set: { if !$0 { sendError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(sendError ?? "")
        }
        .onAppear {
            guard !didApplyInitial else { return }
            didApplyInitial = true
            selected = initiallySelected.intersection(Set(sessions.map(\.id)))
        }
    }

    private var sendTitle: String {
        let n = selected.count
        if n == 0 { return "Send workouts" }
        if n == 1 { return "Send 1 workout" }
        return "Send \(n) workouts"
    }

    private func pickerRow(_ session: WorkoutSession) -> some View {
        HStack(spacing: 12) {
            Image(systemName: selected.contains(session.id) ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(selected.contains(session.id) ? Color.uplift.accent : Color.uplift.fgFaint)
                .accessibilityHidden(true)
            DayChip(dayType: session.day, size: .sm)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.day.rawValue)
                    .font(.uplift.text(15, weight: .semibold))
                    .foregroundStyle(Color.uplift.fg)
                Text(session.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.uplift.text(12, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(session.day.rawValue), \(session.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))")
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(selected.contains(session.id) ? "Selected" : "Not selected")
    }

    private func toggle(_ id: UUID) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }

    private func selectLastWeek() {
        let week = SplitScheduleLogic.completedSessions(inPreviousWeekOf: .now, from: sessions)
        selected = Set(week.map(\.id))
    }

    private func sendSelected() {
        let chosen = selectedSessions
        guard !chosen.isEmpty else { return }
        do {
            CoachExportService.present(try CoachExportService.writePackage(for: chosen))
            dismiss()
        } catch {
            sendError = error.localizedDescription
        }
    }
}
