//
//  CloudKitErrorFormatting.swift
//  strength-training
//
//  CKError 2 is PartialFailure — Settings was showing the raw domain/code.
//

import CloudKit
import Foundation

enum CloudKitErrorFormatting {
    /// Short copy for Settings. Unwraps PartialFailure (code 2) and nested errors.
    static func userFacingMessage(from error: Error?) -> String? {
        guard let error else { return nil }
        return message(for: error as NSError)
    }

    static func message(for ns: NSError) -> String {
        if ns.domain == CKError.errorDomain {
            return cloudKitMessage(ns)
        }
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
            return message(for: underlying)
        }
        return ns.localizedDescription
    }

    private static func cloudKitMessage(_ ns: NSError) -> String {
        switch CKError.Code(rawValue: ns.code) {
        case .partialFailure:
            let nested = (ns.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error])?
                .values
                .compactMap { userFacingMessage(from: $0) } ?? []
            let unique = Array(Set(nested)).sorted()
            if unique.isEmpty {
                return "Some items didn’t sync this pass. Workouts are still on this phone — pull to refresh."
            }
            return unique.joined(separator: " ")
        case .networkUnavailable, .networkFailure:
            return "No network for iCloud. Workouts are still saved on this phone."
        case .notAuthenticated:
            return "Sign in to iCloud in the iPhone Settings app."
        case .quotaExceeded:
            return "iCloud storage is full. Free space or upgrade storage, then pull to refresh."
        case .serviceUnavailable, .zoneBusy, .requestRateLimited, .accountTemporarilyUnavailable:
            return "iCloud is busy and will retry on its own."
        case .serverRecordChanged:
            return "Another device changed the same item. Sync will retry."
        case .constraintViolation, .serverRejectedRequest:
            return "iCloud rejected a record (often a duplicate after two devices seeded). Pull to refresh; export a backup if it persists."
        case .incompatibleVersion:
            return "This build’s iCloud schema doesn’t match another device. Update all devices to the same RockLog version."
        case .missingEntitlement, .badContainer, .badDatabase:
            return "This install isn’t allowed to use the RockLog iCloud container."
        case .changeTokenExpired:
            return "iCloud asked for a full re-import. Keep the app open on Wi‑Fi for a minute."
        default:
            let desc = ns.localizedDescription
            if desc.contains("CKErrorDomain") || desc.contains("error 2") {
                return "Some items didn’t sync this pass. Workouts are still on this phone — pull to refresh."
            }
            return desc
        }
    }
}
