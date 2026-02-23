//
//  WorkoutDayPickerView.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI

struct WorkoutDayPickerView: View {
    @Bindable var viewModel: WorkoutViewModel
    @State private var confirmingDayType: DayType?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Text("Start Workout")
                    .font(.largeTitle.bold())

                Text("What are you training today?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(spacing: 16) {
                    ForEach(DayType.allCases) { dayType in
                        let isActive = viewModel.suspendedSession?.dayType == dayType

                        Button {
                            if viewModel.suspendedHasSets && !isActive {
                                confirmingDayType = dayType
                            } else {
                                viewModel.startSession(dayType: dayType)
                            }
                        } label: {
                            DayTypeCard(
                                dayType: dayType,
                                isActive: isActive,
                                inProgressCount: isActive ? viewModel.suspendedInProgressExerciseCount : 0
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                Spacer()
                Spacer()
            }
            .navigationTitle("Strength Training")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "Replace Current Workout?",
                isPresented: Binding(
                    get: { confirmingDayType != nil },
                    set: { if !$0 { confirmingDayType = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let dayType = confirmingDayType {
                    Button("Start \(dayType.rawValue) Day", role: .destructive) {
                        viewModel.abandonSuspendedAndStart(dayType: dayType)
                        confirmingDayType = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    confirmingDayType = nil
                }
            } message: {
                let count = viewModel.suspendedInProgressExerciseCount
                let dayName = viewModel.suspendedSession?.dayType.rawValue ?? "current"
                Text("Your \(dayName) Day workout has \(count) exercise\(count == 1 ? "" : "s") in progress. Starting a new workout will discard it.")
            }
        }
    }
}

private struct DayTypeCard: View {
    let dayType: DayType
    var isActive: Bool = false
    var inProgressCount: Int = 0

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: dayType.systemImage)
                .font(.system(size: 36))
                .frame(width: 56, height: 56)
                .foregroundStyle(dayType.color)
                .background(dayType.color.opacity(isActive ? 0.2 : 0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text("\(dayType.rawValue) Day")
                    .font(.title3.bold())

                Text(dayType.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if isActive && inProgressCount > 0 {
                    Text("\(inProgressCount) exercise\(inProgressCount == 1 ? "" : "s") in progress · tap to resume")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(dayType.color)
                }
            }

            Spacer()

            Image(systemName: isActive ? "arrow.counterclockwise.circle.fill" : "chevron.right")
                .font(isActive ? .title3 : .body)
                .foregroundStyle(isActive ? AnyShapeStyle(dayType.color) : AnyShapeStyle(.tertiary))
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isActive ? AnyShapeStyle(dayType.color) : AnyShapeStyle(.quaternary), lineWidth: isActive ? 2 : 1)
        )
    }
}
