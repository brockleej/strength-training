//
//  CloudKitErrorFormatting.swift
//  strength-training
//
//  CKError 2 is PartialFailure. Nested codes decide if Settings should
//  scream (auth/quota) or stay green (export conflict, iCloud will retry).
//

import CloudKit
import Foundation

struct CloudKitErrorSummary: Equatable {
    var message: String
    var codes: [Int]
    /// True when CloudKit will retry and local data is fine (conflicts, busy, empty partial).
    var isRetryable: Bool
}

enum CloudKitErrorFormatting {
    static func userFacingMessage(from error: Error?) -> String? {
        summarize(error)?.message
    }

    static func summarize(_ error: Error?) -> CloudKitErrorSummary? {
        guard let error else { return nil }
        let leaves = leafCloudKitErrors(in: error as NSError)
        let codes = leaves.map(\.code)
        let isRetryable = leaves.isEmpty
            || leaves.allSatisfy { isRetryableCode($0.code) }
            || (leaves.count == 1 && leaves[0].code == CKError.Code.partialFailure.rawValue)

        let message: String
        if leaves.isEmpty {
            message = (error as NSError).localizedDescription
        } else if leaves.allSatisfy({ $0.code == CKError.Code.partialFailure.rawValue }) {
            message = "A later iCloud pass skipped some items. Workouts stay on this phone; iCloud retries on its own."
        } else {
            let texts = Array(Set(leaves.map { cloudKitMessage($0) })).sorted()
            message = texts.joined(separator: " ")
        }
        return CloudKitErrorSummary(message: message, codes: codes, isRetryable: isRetryable)
    }

    static func message(for ns: NSError) -> String {
        summarize(ns)?.message ?? ns.localizedDescription
    }

    // MARK: - Unwrap

    private static func leafCloudKitErrors(in ns: NSError) -> [NSError] {
        if ns.domain == CKError.errorDomain {
            let nested = (ns.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error])?
                .values
                .flatMap { leafCloudKitErrors(in: $0 as NSError) } ?? []
            if !nested.isEmpty { return nested }
            if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
                let deeper = leafCloudKitErrors(in: underlying)
                if !deeper.isEmpty { return deeper }
            }
            return [ns]
        }
        var collected: [NSError] = []
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
            collected.append(contentsOf: leafCloudKitErrors(in: underlying))
        }
        if let multiple = ns.userInfo[NSUnderlyingErrorKey] as? [Error] {
            collected.append(contentsOf: multiple.flatMap { leafCloudKitErrors(in: $0 as NSError) })
        }
        return collected
    }

    private static func isRetryableCode(_ code: Int) -> Bool {
        switch CKError.Code(rawValue: code) {
        case .partialFailure,
             .networkUnavailable, .networkFailure,
             .serviceUnavailable, .zoneBusy, .requestRateLimited,
             .accountTemporarilyUnavailable,
             .serverRecordChanged,
             .operationCancelled,
             .batchRequestFailed,
             .changeTokenExpired,
             .serverResponseLost:
            return true
        default:
            return false
        }
    }

    private static func cloudKitMessage(_ ns: NSError) -> String {
        switch CKError.Code(rawValue: ns.code) {
        case .partialFailure:
            return "A later iCloud pass skipped some items. Workouts stay on this phone; iCloud retries on its own."
        case .networkUnavailable, .networkFailure:
            return "No network for iCloud. Workouts are still saved on this phone."
        case .notAuthenticated:
            return "Sign in to iCloud in the iPhone Settings app."
        case .quotaExceeded:
            return "iCloud storage is full. Free space or upgrade storage, then tap Retry."
        case .serviceUnavailable, .zoneBusy, .requestRateLimited, .accountTemporarilyUnavailable:
            return "iCloud is busy and will retry on its own."
        case .serverRecordChanged:
            return "Another device changed the same item. Sync will retry."
        case .constraintViolation, .serverRejectedRequest:
            return "iCloud rejected a record (often a duplicate after two devices seeded). Export a backup if this persists."
        case .incompatibleVersion:
            return "This build’s iCloud schema doesn’t match another device. Update all devices to the same RockLog version."
        case .missingEntitlement, .badContainer, .badDatabase:
            return "This install isn’t allowed to use the RockLog iCloud container."
        case .changeTokenExpired:
            return "iCloud asked for a full re-import. Keep the app open on Wi‑Fi for a minute."
        default:
            let desc = ns.localizedDescription
            if desc.contains("CKErrorDomain") || desc.contains("error 2") {
                return "A later iCloud pass skipped some items. Workouts stay on this phone; iCloud retries on its own."
            }
            return desc
        }
    }
}
