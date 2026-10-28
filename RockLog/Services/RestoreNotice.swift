//
//  RestoreNotice.swift
//  RockLog
//
//  Restore replaces the whole tab UI, which destroys Settings before its
//  success alert can appear. The root keeps this message and shows it after
//  the new tabs are up.
//

import Foundation
import Observation

@Observable
final class RestoreNotice {
    static let shared = RestoreNotice()

    var message: String?

    func present(_ message: String) {
        self.message = message
    }

    func dismiss() {
        message = nil
    }
}
