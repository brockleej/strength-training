//
//  RestAlertRuntime.swift
//  RockLog
//
//  Applies a rest-alert decision: haptic, ducked chirp, one Live Activity,
//  one backup notification. A failed Live Activity does not become a banner.
//

import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif
#if canImport(CallKit)
import CallKit
#endif

enum RestAlertRuntime {
    static func apply(_ effects: RestAlertEffects, exerciseName: String) {
        if effects.strongHaptic { HapticService.restFinished() }
        if effects.lightTap { HapticService.restWarningTap() }
        if effects.playChirp {
            RestTimerSoundService.playChirp(duck: effects.duck)
        }
        if effects.stopChirp { RestTimerSoundService.stopChirp() }
        if effects.unduck && !effects.playChirp { RestTimerSoundService.endDuck() }
        if let end = effects.updateActivityEnd {
            RestActivityController.upsert(name: exerciseName, end: end)
        }
        if effects.endActivity { RestActivityController.endAll() }
        if effects.cancelBackup { RestTimerNotificationScheduler.cancelBackup() }
        if let date = effects.scheduleBackupAt {
            RestTimerNotificationScheduler.armBackup(at: date, exerciseName: exerciseName)
        }
    }

    static func tickContext(now: Date) -> RestAlertPolicy.Tick {
        RestAlertPolicy.Tick(
            now: now,
            soundEnabled: RestTimerPreferences.isSoundEnabled,
            tapAtTenEnabled: RestAlertPreferences.tapAtTen,
            callConnected: RestCallMonitor.shared.hasConnectedCall,
            liveActivitiesAvailable: RestActivityController.areAvailable,
            notificationPermissionDenied: false,
            appIsActive: true
        )
    }
}

enum RestActivityController {
    static var areAvailable: Bool {
        guard FeatureFlags.liveActivity else { return false }
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) { return ActivityAuthorizationInfo().areActivitiesEnabled }
        #endif
        return false
    }

    static func upsert(name: String, end: Date) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }
        let state = RestActivityAttributes.ContentState(rangeStart: .now, endDate: end)
        if let current = Activity<RestActivityAttributes>.activities.first {
            if current.content.state.endDate == end, current.attributes.exerciseName == name { return }
            // staleDate is the rest end. Past that, the system may mark the activity stale.
            Task { await current.update(ActivityContent(state: state, staleDate: end)) }
            return
        }
        let attributes = RestActivityAttributes(exerciseName: name)
        do {
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: end),
                pushType: nil
            )
        } catch {
            // The in-app countdown stays. Do not post a per-second banner.
        }
        #endif
    }

    static func endAll() {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }
        for activity in Activity<RestActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        #endif
    }
}

#if canImport(CallKit)
nonisolated final class RestCallMonitor: NSObject, CXCallObserverDelegate {
    static let shared = RestCallMonitor()

    private let observer = CXCallObserver()
    nonisolated(unsafe) private(set) var hasConnectedCall = false
    nonisolated(unsafe) var onChange: (() -> Void)?

    func start() {
        observer.setDelegate(self, queue: .main)
        refresh(observer)
    }

    func callObserver(_ observer: CXCallObserver, callChanged call: CXCall) {
        refresh(observer)
        onChange?()
    }

    private func refresh(_ observer: CXCallObserver) {
        hasConnectedCall = observer.calls.contains { !$0.hasEnded && $0.hasConnected }
    }
}
#else
final class RestCallMonitor: NSObject {
    static let shared = RestCallMonitor()
    var hasConnectedCall = false
    var onChange: (() -> Void)?
    func start() {}
}
#endif
