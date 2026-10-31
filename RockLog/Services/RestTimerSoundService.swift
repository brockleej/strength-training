//
//  RestTimerSoundService.swift
//  RockLog
//
//  The end chirp plays while the app is on screen. There is no silent
//  keep-alive loop: that pattern is an App Review risk. When the app is
//  not on screen, the end-time local notification is the alert.
//

import AVFoundation
import AudioToolbox
import UIKit

enum RestTimerSoundService {

    /// Seconds remaining that receive a countdown tick (inclusive).
    static let tickWindow = 5

    private static let sampleRate = 44_100.0
    private static var engine: AVAudioEngine?
    private static var player: AVAudioPlayerNode?
    private static var monoFormat: AVAudioFormat?
    private static var didConfigureSession = false

    // MARK: - Public

    /// Warm audio session when rest starts (works with ringer off; mixes with music).
    static func prepareIfNeeded() {
        guard RestTimerPreferences.isSoundEnabled else { return }
        configureSessionIfNeeded()
        _ = sharedPlayer()
    }

    /// One short beep for 5…1 when End alert is "5-second countdown beeps".
    /// On screen only (the policy checks), ducks other audio, then lets it back up.
    /// There is still no background keep-alive (ab12c88 / c0ffab3).
    static func playCountdownTick(remainingWholeSeconds: Int) {
        guard (1...tickWindow).contains(remainingWholeSeconds) else { return }
        configureSession(duck: true)
        // Rising pitch toward zero, like the 1.0 build.
        let pitches: [Double] = [740, 830, 932, 1047, 1175]
        let index = max(0, min(tickWindow - 1, tickWindow - remainingWholeSeconds))
        playTone(frequency: pitches[index], duration: 0.08, volume: 0.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { endDuck() }
    }

    /// One chirp at zero. The caller decides whether a call or the sound switch forbids it.
    static func playChirp(duck: Bool) {
        if duck { configureSession(duck: true) } else { configureSessionIfNeeded() }
        playTone(frequency: 880, duration: 0.12, volume: 0.55)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            playTone(frequency: 1175, duration: 0.35, volume: 0.65)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                if duck { endDuck() }
            }
        }
    }

    static func stopChirp() {
        player?.stop()
        endDuck()
    }

    /// Fired once when the timer hits zero. Kept for callers that still want the old bundle.
    static func playComplete() {
        if RestTimerPreferences.isSoundEnabled {
            playChirp(duck: true)
        }
        HapticService.restFinished()
    }

    // MARK: - Session / engine

    /// Ducking is only for the chirp, then it comes off. There is no keep-alive.
    static func configureSession(duck: Bool) {
        let session = AVAudioSession.sharedInstance()
        var options: AVAudioSession.CategoryOptions = [.mixWithOthers]
        if duck { options.insert(.duckOthers) }
        do {
            try session.setCategory(.playback, mode: .default, options: options)
            didConfigureSession = true
            try session.setActive(true, options: [])
        } catch {
            // Tone path may still work; otherwise we fall back to system sound.
        }
    }

    static func endDuck() {
        configureSession(duck: false)
    }

    private static func configureSessionIfNeeded() {
        if !didConfigureSession { configureSession(duck: false) }
    }

    private static func sharedPlayer() -> (AVAudioEngine, AVAudioPlayerNode, AVAudioFormat)? {
        if let engine, let player, let monoFormat {
            return (engine, player, monoFormat)
        }
        let mono = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: mono)
        do {
            try engine.start()
            player.play()
            self.engine = engine
            self.player = player
            self.monoFormat = mono
            return (engine, player, mono)
        } catch {
            self.engine = nil
            self.player = nil
            self.monoFormat = nil
            return nil
        }
    }

    private static func playTone(frequency: Double, duration: TimeInterval, volume: Float) {
        guard let (engine, player, format) = sharedPlayer() else {
            AudioServicesPlaySystemSound(1104)
            return
        }
        if !engine.isRunning {
            try? engine.start()
            player.play()
        }

        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0]
        else {
            AudioServicesPlaySystemSound(1104)
            return
        }
        buffer.frameLength = frameCount

        let twoPi = 2.0 * Double.pi
        let attack = min(0.008, duration * 0.2)
        let release = min(0.02, duration * 0.35)
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let envelope: Double
            if t < attack {
                envelope = t / attack
            } else if t > duration - release {
                envelope = max(0, (duration - t) / release)
            } else {
                envelope = 1
            }
            data[i] = Float(sin(twoPi * frequency * t) * envelope) * volume
        }

        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !player.isPlaying { player.play() }
    }
}
