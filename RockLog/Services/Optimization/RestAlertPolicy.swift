//
//  RestAlertPolicy.swift
//  RockLog
//
//  What the rest timer is allowed to do at 10 seconds and at zero.
//  The screen, the audio session, and the Live Activity apply the effects.
//

import Foundation

nonisolated struct RestAlertState: Equatable, Sendable {
    var endDate: Date
    var zeroFired: Bool
    var tenTapArmed: Bool
    var tenTapFired: Bool
    var chirpStarted: Bool
    /// Remaining seconds at the previous tick. A 10-second tap fires once per downward crossing.
    var previousRemaining: TimeInterval

    static func started(now: Date, duration: TimeInterval) -> RestAlertState {
        RestAlertState(
            endDate: now.addingTimeInterval(duration),
            zeroFired: false,
            tenTapArmed: duration > 10,
            tenTapFired: false,
            chirpStarted: false,
            previousRemaining: duration
        )
    }
}

nonisolated struct RestAlertEffects: Equatable, Sendable {
    var strongHaptic = false
    var lightTap = false
    var playChirp = false
    var stopChirp = false
    var duck = false
    var unduck = false
    var updateActivityEnd: Date?
    var endActivity = false
    var scheduleBackupAt: Date?
    var cancelBackup = false
    var activityEnded = false
    /// Whole seconds left (5…1) for a countdown beep. Nil means no beep this tick.
    var countdownBeep: Int?
}

nonisolated enum RestAlertPolicy {
    /// Chirp options. Spoken audio is ducked, not interrupted, and not stopped.
    static let chirpMixes = true
    static let chirpDucks = true
    static let chirpInterruptsSpokenAudio = false
    /// No silent audio loop. A keep-alive is an App Review risk, and the end notification covers the background.
    static let usesAudioKeepAlive = false
    static let keepAliveDucks = false
    static let categoryIsPlayback = true
    static let endAlertIsTimeSensitive = false
    /// Seconds that get a countdown beep when End alert is "5-second countdown beeps".
    static let countdownWindow = 5

    struct Tick: Sendable {
        var now: Date
        var soundEnabled: Bool
        var tapAtTenEnabled: Bool
        var callConnected: Bool
        var liveActivitiesAvailable: Bool
        var notificationPermissionDenied: Bool
        var appIsActive: Bool
        /// Defaults to the chirp so callers that predate End alert keep their behavior.
        var endAlert: RestEndAlert = .chirp
    }

    static func onStart(_ state: RestAlertState, tick: Tick) -> RestAlertEffects {
        var effects = RestAlertEffects()
        effects.updateActivityEnd = state.endDate
        effects.scheduleBackupAt = state.endDate
        return effects
    }

    static func onTick(_ state: inout RestAlertState, tick: Tick) -> RestAlertEffects {
        var effects = RestAlertEffects()
        let remaining = state.endDate.timeIntervalSince(tick.now)
        // One beep per whole second crossed in the last five, on screen only, never on a call.
        if tick.endAlert.beepsLastFive, tick.appIsActive, !tick.callConnected, remaining > 0 {
            let before = Int(state.previousRemaining.rounded(.up))
            let now = Int(remaining.rounded(.up))
            if now < before, (1...countdownWindow).contains(now) {
                effects.countdownBeep = now
                effects.duck = true
            }
        }
        if tick.tapAtTenEnabled, state.previousRemaining > 10, remaining <= 10, remaining > 0 {
            state.tenTapFired = true
            effects.lightTap = true
        }
        state.previousRemaining = remaining

        if remaining <= 0 {
            guard !state.zeroFired else { return effects }
            state.zeroFired = true
            effects.strongHaptic = tick.endAlert.buzzes
            effects.endActivity = true
            effects.activityEnded = true
            // The app is on screen and plays the alert, so the backup notification must not also fire.
            if tick.appIsActive {
                effects.cancelBackup = true
                if tick.soundEnabled && tick.endAlert.playsSound && !tick.callConnected {
                    effects.playChirp = true
                    effects.duck = true
                    state.chirpStarted = true
                }
            }
            return effects
        }
        return effects
    }

    /// ±15. Adding time back above 10 seconds arms the tap once more.
    static func onNudge(_ state: inout RestAlertState, seconds: TimeInterval, now: Date) -> RestAlertEffects {
        state.endDate = state.endDate.addingTimeInterval(seconds)
        state.zeroFired = false
        let remaining = state.endDate.timeIntervalSince(now)
        state.previousRemaining = remaining
        if remaining > 10 {
            state.tenTapFired = false
            state.tenTapArmed = true
        }
        var effects = RestAlertEffects()
        effects.updateActivityEnd = state.endDate
        effects.scheduleBackupAt = state.endDate
        return effects
    }

    static func onSkip(_ state: inout RestAlertState) -> RestAlertEffects {
        state.zeroFired = true
        state.tenTapArmed = false
        var effects = RestAlertEffects()
        effects.endActivity = true
        effects.cancelBackup = true
        effects.activityEnded = true
        if state.chirpStarted {
            effects.stopChirp = true
            effects.unduck = true
        }
        return effects
    }

    static func onCallBegan(_ state: RestAlertState) -> RestAlertEffects {
        var effects = RestAlertEffects()
        if state.chirpStarted {
            effects.stopChirp = true
            effects.unduck = true
        }
        return effects
    }

    static func onChirpFinished() -> RestAlertEffects {
        var effects = RestAlertEffects()
        effects.unduck = true
        return effects
    }
}
