//
//  TrainingModePickerView.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI

struct TrainingModePickerView: View {
    @Binding var selectedMode: TrainingMode

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TrainingMode.allCases) { mode in
                Button {
                    selectedMode = mode
                } label: {
                    Label(mode.rawValue, systemImage: mode.systemImage)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background {
                            if selectedMode == mode {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
                            }
                        }
                        .foregroundStyle(selectedMode == mode ? .primary : .secondary)
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.15), value: selectedMode)
            }
        }
        .padding(4)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 11))
    }
}
