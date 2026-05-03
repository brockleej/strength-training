//
//  ParameterPanel.swift
//  ProgressionLab
//

import SwiftUI

struct ParameterPanel: View {
    @Bindable var slot: ConfigSlot
    let accent: Color
    let onParametersChanged: () -> Void
    let onSave: () -> Void
    let onLoad: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(accent).frame(width: 10, height: 10)
                TextField("Name", text: $slot.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                Spacer()
                Menu("Reset to…") {
                    Button("Production (moderate)") {
                        slot.parameters = .productionModerate
                        onParametersChanged()
                    }
                    Button("Production (conservative)") {
                        slot.parameters = .productionConservative
                        onParametersChanged()
                    }
                }
                Button("Save…", action: onSave)
                Button("Load…", action: onLoad)
            }
            Divider()
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                row("Average window (sessions)", value: $slot.parameters.averageWindow, range: 1...20)
                row("Consistency threshold", value: $slot.parameters.consistencyThreshold, range: 1...10)
                row("Strength rep cap", value: $slot.parameters.strengthRepCap, range: 5...50)
                row("Endurance ceiling offset", value: $slot.parameters.enduranceCeilingOffset, range: 0...50)
                doubleRow("Weight increment (lbs)", value: $slot.parameters.weightIncrement, range: 1...50, step: 0.5)
                row("Rep increment", value: $slot.parameters.repIncrement, range: 1...10)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
    }

    @ViewBuilder
    private func row(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        GridRow {
            Text(label)
            HStack(spacing: 8) {
                Stepper(value: value, in: range) {
                    Text("\(value.wrappedValue)").monospacedDigit().frame(minWidth: 30, alignment: .trailing)
                }
                .onChange(of: value.wrappedValue) { _, _ in onParametersChanged() }
            }
        }
    }

    @ViewBuilder
    private func doubleRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        GridRow {
            Text(label)
            HStack(spacing: 8) {
                Stepper(value: value, in: range, step: step) {
                    Text(value.wrappedValue.formatted(.number.precision(.fractionLength(0...2))))
                        .monospacedDigit()
                        .frame(minWidth: 40, alignment: .trailing)
                }
                .onChange(of: value.wrappedValue) { _, _ in onParametersChanged() }
            }
        }
    }
}
