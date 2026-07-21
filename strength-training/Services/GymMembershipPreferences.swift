//
//  GymMembershipPreferences.swift
//  strength-training
//
//  UserDefaults-backed gym check-in code for the barcode pass.
//

import Foundation

enum GymMembershipPreferences {
    static let codeKey = "gymMembershipCode"
    static let labelKey = "gymMembershipLabel"
    static let formatKey = "gymMembershipFormat"

    static let defaultLabel = "Gym membership"

    enum Format: String, CaseIterable, Identifiable {
        case code128 = "code128"
        case qr = "qr"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .code128: "Barcode (Code 128)"
            case .qr: "QR code"
            }
        }

        var detail: String {
            switch self {
            case .code128: "Horizontal barcode most scanners expect"
            case .qr: "Square QR — some apps / kiosks use this"
            }
        }
    }

    static var code: String {
        UserDefaults.standard.string(forKey: codeKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var label: String {
        let value = UserDefaults.standard.string(forKey: labelKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? defaultLabel : value
    }

    static var format: Format {
        Format(rawValue: UserDefaults.standard.string(forKey: formatKey) ?? "") ?? .code128
    }

    static var isConfigured: Bool { !code.isEmpty }
}
