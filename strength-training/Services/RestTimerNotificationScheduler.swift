//
//  RestTimerNotificationScheduler.swift
//  strength-training
//
//  Rest countdown is **audio only** (RestTimerSoundService + background keep-alive).
//  We intentionally do **not** schedule local notifications for ticks or “done” —
//  those produced five banners when the app was inactive.
//
//  This type only clears any legacy rest-timer notifications still pending/delivered.
//

import Foundation
import UserNotifications
import UIKit

enum RestTimerNotificationScheduler {
    static let idPrefix = "rest-timer-"

    private static let knownIDs: [String] = {
        var ids = (1...RestTimerSoundService.tickWindow).map { "\(idPrefix)tick-\($0)" }
        ids.append("\(idPrefix)done")
        return ids
    }()

    /// No-op: rest timer does not use notification permission (audio path only).
    static func requestAuthorizationIfNeeded(completion: (() -> Void)? = nil) {
        DispatchQueue.main.async { completion?() }
    }

    /// Remove pending/delivered rest-timer notifications (including leftovers from older builds).
    static func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: knownIDs)
        center.removeDeliveredNotifications(withIdentifiers: knownIDs)
        // Also sweep any other rest-timer-* ids if tick window ever changed.
        center.getPendingNotificationRequests { pending in
            let extra = pending
                .map(\.identifier)
                .filter { $0.hasPrefix(idPrefix) && !knownIDs.contains($0) }
            if !extra.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: extra)
            }
        }
        center.getDeliveredNotifications { delivered in
            let extra = delivered
                .map(\.request.identifier)
                .filter { $0.hasPrefix(idPrefix) }
            if !extra.isEmpty {
                center.removeDeliveredNotifications(withIdentifiers: extra)
            }
        }
    }

    /// Called when rest end date changes. Clears notifications only — does not schedule.
    static func reschedule(endDate: Date?) {
        _ = endDate
        cancelAll()
    }
}

/// Suppresses any leftover rest-timer notifications if one still fires (old build / race).
final class RestTimerNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = RestTimerNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        if notification.request.identifier.hasPrefix(RestTimerNotificationScheduler.idPrefix) {
            return []
        }
        return [.banner, .sound, .list]
    }
}
