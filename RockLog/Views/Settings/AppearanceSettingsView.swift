//
//  AppearanceSettingsView.swift
//  RockLog
//
//  Settings → Appearance. Dark stays the default.
//

import SwiftUI

enum AppearanceChoice: String, CaseIterable, Identifiable {
    case system
    case dark
    case light

    static let key = "appearanceChoice"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .dark: "Dark"
        case .light: "Light"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }

    static func stored() -> AppearanceChoice {
        AppearanceChoice(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .dark
    }
}

struct AppearanceSettingsView: View {
    @AppStorage(AppearanceChoice.key) private var raw: String = AppearanceChoice.dark.rawValue

    var body: some View {
        List {
            Section {
                UpliftSegmentedControl(
                    segments: AppearanceChoice.allCases.map {
                        UpliftSegment(id: $0.rawValue, label: $0.title)
                    },
                    selection: $raw
                )
                .accessibilityIdentifier(AccessibilityID.settingsAppearanceChoice)
            } header: {
                Text("Theme")
            } footer: {
                Text("Dark is the default. System follows the iPhone.")
            }
            .listRowBackground(Color.uplift.surface1)
        }
        .settingsPage("Appearance")
    }
}

extension View {
    func settingsPage(_ title: String) -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color.uplift.bgElev)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}
