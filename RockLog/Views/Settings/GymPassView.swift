//
//  GymPassView.swift
//  RockLog
//
//  Full-screen bright pass for scanner entry. Keep phone brightness up.
//

import SwiftUI
import UIKit

struct GymPassView: View {
    var entry: GymAccessEntry?

    @Environment(\.dismiss) private var dismiss

    @State private var previousBrightness: CGFloat?
    /// Screen we adjusted — restore on the same instance (not UIScreen.main).
    @State private var brightnessScreen: UIScreen?
    @State private var previousIdleDisabled = false

    private var payload: String {
        entry?.barcodePayload ?? ""
    }

    private var symbology: BarcodeSymbology {
        entry?.symbology ?? .code128
    }

    private var displayLabel: String {
        let name = entry?.trimmedName ?? ""
        return name.isEmpty ? "Gym membership" : name
    }

    private var barcodeImage: UIImage? {
        BarcodeImageGenerator.image(from: payload, symbology: symbology)
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.black.opacity(0.45))
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier(AccessibilityID.gymPassClose)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer(minLength: 12)

                Text(displayLabel)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                if let barcodeImage {
                    Image(uiImage: barcodeImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: symbology == .qr || symbology == .aztec ? 260 : .infinity)
                        .frame(height: symbology == .qr || symbology == .aztec ? 260 : 140)
                        .padding(.horizontal, symbology == .qr || symbology == .aztec ? 40 : 20)
                        .padding(.top, 28)
                        .accessibilityLabel("Membership barcode")
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundStyle(.black.opacity(0.35))
                        Text("Add your membership number in Settings")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.black.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    .padding(.horizontal, 32)
                }

                if !payload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(payload)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.55))
                        .padding(.top, 16)
                        .textSelection(.enabled)
                        .accessibilityIdentifier(AccessibilityID.gymPassCode)
                }

                Text("Hold under the scanner")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.black.opacity(0.4))
                    .padding(.top, 24)

                Spacer()
                Spacer()
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            previousIdleDisabled = UIApplication.shared.isIdleTimerDisabled
            UIApplication.shared.isIdleTimerDisabled = true
            boostBrightness()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = previousIdleDisabled
            restoreBrightness()
        }
    }

    private func boostBrightness() {
        guard let screen = Self.foregroundScreen() else { return }
        brightnessScreen = screen
        previousBrightness = screen.brightness
        screen.brightness = 1.0
    }

    private func restoreBrightness() {
        if let screen = brightnessScreen, let previousBrightness {
            screen.brightness = previousBrightness
        }
        brightnessScreen = nil
        previousBrightness = nil
    }

    /// iOS 26+: avoid `UIScreen.main` — resolve screen from the active window scene.
    private static func foregroundScreen() -> UIScreen? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first(where: { $0.activationState == .foregroundActive })?.screen
            ?? scenes.first?.screen
    }
}

#Preview("GymPass") {
    GymPassView()
}
