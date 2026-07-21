//
//  GymPassView.swift
//  strength-training
//
//  Full-screen bright pass for scanner entry. Keep phone brightness up.
//

import SwiftUI
import UIKit

struct GymPassView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(GymMembershipPreferences.codeKey) private var code: String = ""
    @AppStorage(GymMembershipPreferences.labelKey) private var label: String = ""
    @AppStorage(GymMembershipPreferences.formatKey) private var formatRaw: String =
        GymMembershipPreferences.Format.code128.rawValue

    @State private var previousBrightness: CGFloat?

    private var format: GymMembershipPreferences.Format {
        GymMembershipPreferences.Format(rawValue: formatRaw) ?? .code128
    }

    private var displayLabel: String {
        let t = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? GymMembershipPreferences.defaultLabel : t
    }

    private var barcodeImage: UIImage? {
        BarcodeImageGenerator.image(from: code, format: format)
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
                    .accessibilityLabel("Close")
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
                        .frame(maxWidth: format == .qr ? 260 : .infinity)
                        .frame(height: format == .qr ? 260 : 140)
                        .padding(.horizontal, format == .qr ? 40 : 20)
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

                if !code.isEmpty {
                    Text(code)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.55))
                        .padding(.top, 16)
                        .textSelection(.enabled)
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
        .onAppear { boostBrightness() }
        .onDisappear { restoreBrightness() }
    }

    private func boostBrightness() {
        let screen = UIScreen.main
        previousBrightness = screen.brightness
        screen.brightness = 1.0
    }

    private func restoreBrightness() {
        if let previousBrightness {
            UIScreen.main.brightness = previousBrightness
        }
    }
}

#Preview("GymPass") {
    GymPassView()
}
