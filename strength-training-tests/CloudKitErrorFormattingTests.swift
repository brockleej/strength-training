//
//  CloudKitErrorFormattingTests.swift
//  strength-training-tests
//

import CloudKit
import XCTest
@testable import strength_training

final class CloudKitErrorFormattingTests: XCTestCase {
    func test_partialFailure_code2_isHumanReadable() {
        let err = NSError(domain: CKError.errorDomain, code: CKError.Code.partialFailure.rawValue)
        let message = CloudKitErrorFormatting.userFacingMessage(from: err) ?? ""
        XCTAssertFalse(message.contains("CKErrorDomain"))
        XCTAssertFalse(message.contains("error 2"))
        XCTAssertTrue(message.localizedCaseInsensitiveContains("phone") || message.localizedCaseInsensitiveContains("sync"))
    }

    func test_quota_mentionsStorage() {
        let err = NSError(domain: CKError.errorDomain, code: CKError.Code.quotaExceeded.rawValue)
        let message = CloudKitErrorFormatting.userFacingMessage(from: err) ?? ""
        XCTAssertTrue(message.localizedCaseInsensitiveContains("storage"))
    }

    func test_wrappedUnderlying_unwraps() {
        let inner = NSError(domain: CKError.errorDomain, code: CKError.Code.networkUnavailable.rawValue)
        let outer = NSError(
            domain: NSCocoaErrorDomain,
            code: 134400,
            userInfo: [NSUnderlyingErrorKey: inner]
        )
        let message = CloudKitErrorFormatting.userFacingMessage(from: outer) ?? ""
        XCTAssertTrue(message.localizedCaseInsensitiveContains("network"))
    }

    func test_emptyPartialFailure_isRetryable() {
        let err = NSError(domain: CKError.errorDomain, code: CKError.Code.partialFailure.rawValue)
        let summary = CloudKitErrorFormatting.summarize(err)
        XCTAssertEqual(summary?.isRetryable, true)
    }

    func test_quota_isNotRetryable() {
        let err = NSError(domain: CKError.errorDomain, code: CKError.Code.quotaExceeded.rawValue)
        let summary = CloudKitErrorFormatting.summarize(err)
        XCTAssertEqual(summary?.isRetryable, false)
    }

    func test_serverRecordChanged_isRetryable() {
        let err = NSError(domain: CKError.errorDomain, code: CKError.Code.serverRecordChanged.rawValue)
        let summary = CloudKitErrorFormatting.summarize(err)
        XCTAssertEqual(summary?.isRetryable, true)
    }
}
