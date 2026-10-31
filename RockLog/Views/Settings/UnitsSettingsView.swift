//
//  UnitsSettingsView.swift
//  RockLog
//
//  Settings → Units. Pounds are the default. Kilograms change entry,
//  steppers, plates, and labels. Stored sets keep the number that was entered.
//

import SwiftUI

enum UnitsSettingsCopy {
    static let footer = "Choose how weights show across the app. Suggestions go up by 5 lb or 2.5 kg at a time."
}

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
                Text(UnitsSettingsCopy.footer)
                    .accessibilityIdentifier(AccessibilityID.settingsUnitsFooter)
            }
            .listRowBackground(Color.uplift.surface1)
        }
        .scrollContentBackground(.hidden)
        .background(Color.uplift.bgElev)
        .navigationTitle("Units")
        .navigationBarTitleDisplayMode(.inline)
    }
}
