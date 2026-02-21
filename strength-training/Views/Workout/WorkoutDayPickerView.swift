//
//  WorkoutDayPickerView.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI

struct WorkoutDayPickerView: View {
    @Bindable var viewModel: WorkoutViewModel

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
                        Button {
                            viewModel.startSession(dayType: dayType)
                        } label: {
                            DayTypeCard(dayType: dayType)
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
        }
    }
}

private struct DayTypeCard: View {
    let dayType: DayType

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: dayType.systemImage)
                .font(.system(size: 36))
                .frame(width: 56, height: 56)
                .background(.tint.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text("\(dayType.rawValue) Day")
                    .font(.title3.bold())

                Text(dayType.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }
}
