//
//  GymAccessSettingsView.swift
//  RockLog
//
//  Settings → Gym Access. The Today button stays the one control that opens
//  whichever place this list resolves.
//

import SwiftUI
import MapKit
import VisionKit

struct GymAccessSettingsView: View {
    @Bindable private var store = GymAccessStore.shared
    @State private var editing: GymAccessEntry?
    @State private var pendingDelete: GymAccessEntry?

    var body: some View {
        List {
            if store.entries.isEmpty {
                Text("Add a gym to put a barcode, an app, or a link on the Today button.")
                    .font(.uplift.text(14, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
                    .listRowBackground(Color.uplift.surface1)
            }
            ForEach(store.entries) { entry in
                Button {
                    editing = entry
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.trimmedName)
                            .font(.uplift.text(16, weight: .semibold))
                            .foregroundStyle(Color.uplift.fg)
                        Text(subtitle(entry))
                            .font(.uplift.text(12, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .accessibilityIdentifier(AccessibilityID.gymAccessRow(entry.trimmedName))
                .listRowBackground(Color.uplift.surface1)
                .contextMenu {
                    Button("Delete", role: .destructive) { pendingDelete = entry }
                }
            }
            Button {
                editing = GymAccessEntry(
                    id: UUID(),
                    name: "",
                    latitude: nil,
                    longitude: nil,
                    isDefault: store.entries.isEmpty,
                    method: .barcode,
                    barcodePayload: "",
                    symbology: .code128,
                    appPreset: .kisi,
                    appOpenURL: "",
                    appStoreURL: "",
                    linkURL: ""
                )
            } label: {
                Label("Add gym", systemImage: "plus")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .accessibilityIdentifier(AccessibilityID.gymAccessAdd)
            .listRowBackground(Color.uplift.surface1)
        }
        .scrollContentBackground(.hidden)
        .background(Color.uplift.bgElev)
        .navigationTitle("Gym Access")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { entry in
            GymAccessEditor(entry: entry) { saved in
                store.save(saved)
            }
        }
        .confirmationDialog(
            "Delete \(pendingDelete?.trimmedName ?? "this gym")?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let pendingDelete { store.delete(pendingDelete.id) }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("The Today button will stop offering this check-in.")
        }
    }

    private func subtitle(_ entry: GymAccessEntry) -> String {
        var parts = [entry.method.title]
        if entry.isDefault { parts.append("Default") }
        if entry.coordinate != nil { parts.append("Location saved") }
        return parts.joined(separator: " · ")
    }
}

private struct GymAccessEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var entry: GymAccessEntry
    var onSave: (GymAccessEntry) -> Void
    @State private var showMap = false
    @State private var showScanner = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $entry.name)
                        .accessibilityIdentifier(AccessibilityID.gymAccessName)
                    Toggle("Default gym", isOn: $entry.isDefault)
                        .accessibilityIdentifier(AccessibilityID.gymAccessDefault)
                }
                .listRowBackground(Color.uplift.surface1)

                Section {
                    Button("Use current location") { Task { await useCurrentLocation() } }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier(AccessibilityID.gymAccessUseLocation)
                    Button("Pick on the map") { showMap = true }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier(AccessibilityID.gymAccessPickMap)
                    if entry.coordinate != nil {
                        Button("Clear location") {
                            entry.latitude = nil
                            entry.longitude = nil
                        }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier(AccessibilityID.gymAccessClearLocation)
                    }
                } header: {
                    Text("Location")
                } footer: {
                    Text("Optional. Used only to choose the nearest gym within 150 m when you tap Gym pass or start a workout.")
                }
                .listRowBackground(Color.uplift.surface1)

                Section {
                    Picker("Method", selection: $entry.method) {
                        ForEach(GymAccessMethod.allCases) { method in
                            Text(method.title).tag(method)
                        }
                    }
                    .accessibilityIdentifier(AccessibilityID.gymAccessMethod)
                }
                .listRowBackground(Color.uplift.surface1)

                methodFields
            }
            .scrollContentBackground(.hidden)
            .background(Color.uplift.bgElev)
            .navigationTitle(entry.trimmedName.isEmpty ? "New gym" : entry.trimmedName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(entry)
                        dismiss()
                    }
                    .disabled(entry.trimmedName.isEmpty)
                    .accessibilityIdentifier(AccessibilityID.gymAccessSave)
                }
            }
            .sheet(isPresented: $showMap) {
                GymAccessMapSheet(latitude: $entry.latitude, longitude: $entry.longitude)
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScanSheet { code in
                    entry.barcodePayload = code
                    showScanner = false
                }
            }
        }
    }

    @ViewBuilder
    private var methodFields: some View {
        switch entry.method {
        case .barcode:
            Section {
                TextField("Number or payload", text: $entry.barcodePayload)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier(AccessibilityID.gymAccessBarcode)
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    Button("Scan barcode") { showScanner = true }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier(AccessibilityID.gymAccessScan)
                }
                Picker("Type", selection: $entry.symbology) {
                    ForEach(BarcodeSymbology.allCases) { symbology in
                        Text(symbology.title).tag(symbology)
                    }
                }
                .accessibilityIdentifier(AccessibilityID.gymAccessSymbology)
            }
            .listRowBackground(Color.uplift.surface1)
        case .openApp:
            Section {
                Picker("App", selection: $entry.appPreset) {
                    ForEach(GymAppPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .accessibilityIdentifier(AccessibilityID.gymAccessKisi)
                if entry.appPreset == .custom {
                    TextField("App link", text: $entry.appOpenURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .accessibilityIdentifier(AccessibilityID.gymAccessAppURL)
                    TextField("App Store link", text: $entry.appStoreURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .accessibilityIdentifier(AccessibilityID.gymAccessAppStore)
                } else {
                    Text("Opens Kisi. If it is not installed, RockLog opens the App Store page.")
                        .font(.uplift.text(13, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                }
            }
            .listRowBackground(Color.uplift.surface1)
        case .link:
            Section {
                TextField("https://", text: $entry.linkURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .accessibilityIdentifier(AccessibilityID.gymAccessLink)
            }
            .listRowBackground(Color.uplift.surface1)
        }
    }

    private func useCurrentLocation() async {
        guard let fix = await WhenInUseLocation.shared.requestOnce() else { return }
        entry.latitude = fix.coordinate.latitude
        entry.longitude = fix.coordinate.longitude
    }
}

private struct GymAccessMapSheet: View {
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                Map(position: $position) {
                    if let latitude, let longitude {
                        Marker("Gym", coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                    }
                }
                .onTapGesture { point in
                    guard let coordinate = proxy.convert(point, from: .local) else { return }
                    latitude = coordinate.latitude
                    longitude = coordinate.longitude
                }
            }
            .navigationTitle("Gym location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier(AccessibilityID.gymAccessPickMap)
                }
            }
        }
    }
}

private struct BarcodeScanSheet: UIViewControllerRepresentable {
    var onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        nonisolated func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item, let value = barcode.payloadStringValue, !value.isEmpty {
                    let deliver = onCode
                    Task { @MainActor in deliver(value) }
                    return
                }
            }
        }
    }
}
