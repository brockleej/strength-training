//
//  ImportNameSheet.swift
//  RockCoach
//

import SwiftUI

struct ImportNameSheet: View {
    let defaultName: String
    @Binding var name: String
    var sessionCount: Int = 1
    var onImport: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Client name", text: $name)
                        .textInputAutocapitalization(.words)
                } footer: {
                    Text(sessionCount == 1
                         ? "RockCoach keeps this name on your phone. It does not have to match the athlete’s Apple ID."
                         : "This file has \(sessionCount) workouts. RockCoach keeps this name on your phone.")
                }
            }
            .navigationTitle("Save session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            name = defaultName
                        }
                        onImport()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
