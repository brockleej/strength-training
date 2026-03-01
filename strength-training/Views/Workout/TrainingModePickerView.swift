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
        GlassEffectContainer {
            HStack(spacing: 4) {
                ForEach(TrainingMode.allCases) { mode in
                    Button {
                        selectedMode = mode
                    } label: {
                        Label(mode.rawValue, systemImage: mode.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .foregroundStyle(selectedMode == mode ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(
                        selectedMode == mode ? .regular.interactive() : .clear,
                        in: .rect(cornerRadius: 8)
                    )
                    .animation(.easeInOut(duration: 0.15), value: selectedMode)
                }
            }
            .padding(4)
        }
    }
}
