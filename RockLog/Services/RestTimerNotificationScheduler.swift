//
//  RestTimerNotificationScheduler.swift
//  RockLog
//
//  On screen, RestTimerSoundService plays the End alert (chirp, or countdown beeps
//  then the chirp). There is no background audio keep-alive.
//  Off screen, one local notification fires at the end time ("Rest is over",
//  default sound, not Time Sensitive). The app cancels it when it plays the alert
//  itself. End alert "Off" does not arm it. No per-second tick notifications are
//  scheduled (they once produced five banners); legacy ones are cleared here.
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
                .filter { $0.hasPrefix(idPrefix) && $0 != backupID && !knownIDs.contains($0) }
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

    static let backupID = "rest-timer-end"

    /// One notification at the end time. Not a tick, and not Time Sensitive.
    /// Denied permission is skipped. The app cancels this when it plays the end itself.
    static func armBackup(at date: Date, exerciseName: String) {
        let content = UNMutableNotificationContent()
        content.title = exerciseName.isEmpty ? "Rest" : exerciseName
        content.body = "Rest is over"
        content.sound = .default
        let interval = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: backupID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelBackup() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [backupID])
        center.removeDeliveredNotifications(withIdentifiers: [backupID])
    }

    /// Replaces any pending end notification. Nil clears it. Does not schedule ticks.
    static func reschedule(endDate: Date?, exerciseName: String = "Rest") {
        cancelAll()
        guard let endDate, endDate.timeIntervalSinceNow > 0.2 else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional
                    || settings.authorizationStatus == .ephemeral
            else { return }
            armBackup(at: endDate, exerciseName: exerciseName)
        }
    }

    /// Ask once, from the moment he leaves the app during a rest.
    static func requestAuthorizationIfLeavingDuringRest() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }
}

/// Suppresses any leftover rest-timer notifications if one still fires (old build / race).
final class RestTimerNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = RestTimerNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        if notification.request.identifier == RestTimerNotificationScheduler.backupID {
            return [.banner, .sound, .list]
        }
        if notification.request.identifier.hasPrefix(RestTimerNotificationScheduler.idPrefix) {
            return []
        }
        return [.banner, .sound, .list]
    }
}
