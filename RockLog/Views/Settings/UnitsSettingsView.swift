//
//  UnitsSettingsView.swift
//  RockLog
//
//  Settings → Units. Pounds are the default. Kilograms change entry,
//  steppers, plates, and labels. Stored sets keep the number that was entered.
//

import SwiftUI

struct UnitsSettingsView: View {
    @AppStorage(MassUnitPreferences.key)
    private var massUnitRaw: String = MassUnit.pounds.rawValue

    var body: some View {
        List {
            Section {
                UpliftSegmentedControl(
                    segments: MassUnit.allCases.map { UpliftSegment(id: $0.rawValue, label: $0.title) },
                    selection: $massUnitRaw
                )
                .accessibilityIdentifier(AccessibilityID.settingsMassUnit)
                .onChange(of: massUnitRaw) { _, raw in
                    if let unit = MassUnit(rawValue: raw) { MassUnitPreferences.unit = unit }
                }
            } header: {
                Text("Weight")
            } footer: {
                Text("Default is pounds. 5 lb and 2.5 kg are the progression steps. A 20 kg bar uses 25, 20, 15, 10, 5, 2.5, and 1.25 kg plates.")
            }
            .listRowBackground(Color.uplift.surface1)
        }
        .scrollContentBackground(.hidden)
        .background(Color.uplift.bgElev)
        .navigationTitle("Units")
        .navigationBarTitleDisplayMode(.inline)
    }
}
