//
//  RestTimerNotificationScheduler.swift
//  strength-training
//
//  Backup alerts if the process is still suspended (Focus, low power, etc.).
//  Primary path is background audio keep-alive + in-app tones.
//  Foreground presentation is suppressed to avoid double sounds.
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

    /// Ask once when the user starts a sounding rest.
    static func requestAuthorizationIfNeeded(completion: (() -> Void)? = nil) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { _, _ in
                    DispatchQueue.main.async { completion?() }
                }
            default:
                DispatchQueue.main.async { completion?() }
            }
        }
    }

    static func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: knownIDs)
        center.removeDeliveredNotifications(withIdentifiers: knownIDs)
    }

    /// Schedule immediately (no async Task) so lock-screen suspension can’t cancel mid-setup.
    static func reschedule(endDate: Date?) {
        cancelAll()

        guard RestTimerPreferences.isSoundEnabled, let end = endDate else { return }
        let now = Date()
        guard end > now else { return }

        // Extend suspension briefly so adds complete even if the user locked mid-rest.
        var bgTask = UIBackgroundTaskIdentifier.invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "rest-timer-schedule") {
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }

        let finishBG: () -> Void = {
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }

        requestAuthorizationIfNeeded {
            let center = UNUserNotificationCenter.current()
            center.getNotificationSettings { settings in
                let ok: Set<UNAuthorizationStatus> = [.authorized, .provisional, .ephemeral]
                guard ok.contains(settings.authorizationStatus) else {
                    DispatchQueue.main.async { finishBG() }
                    return
                }

                let calendar = Calendar.current

                for whole in 1...RestTimerSoundService.tickWindow {
                    let fireAt = end.addingTimeInterval(-TimeInterval(whole))
                    guard fireAt.timeIntervalSince(now) > 0.15 else { continue }

                    let content = UNMutableNotificationContent()
                    content.title = "Rest"
                    content.body = whole == 1 ? "1 second" : "\(whole) seconds"
                    content.sound = .default

                    let comps = calendar.dateComponents(
                        [.year, .month, .day, .hour, .minute, .second],
                        from: fireAt
                    )
                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    let request = UNNotificationRequest(
                        identifier: "\(idPrefix)tick-\(whole)",
                        content: content,
                        trigger: trigger
                    )
                    center.add(request, withCompletionHandler: nil)
                }

                if end.timeIntervalSince(now) > 0.15 {
                    let content = UNMutableNotificationContent()
                    content.title = "Rest done"
                    content.body = "Start your set"
                    content.sound = .default

                    let comps = calendar.dateComponents(
                        [.year, .month, .day, .hour, .minute, .second],
                        from: end
                    )
                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    let request = UNNotificationRequest(
                        identifier: "\(idPrefix)done",
                        content: content,
                        trigger: trigger
                    )
                    center.add(request, withCompletionHandler: nil)
                }

                DispatchQueue.main.async { finishBG() }
            }
        }
    }
}

/// Suppresses rest-timer banners/sounds while RockLog is in the foreground.
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
