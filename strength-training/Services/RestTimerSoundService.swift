//
//  RestTimerSoundService.swift
//  strength-training
//
//  Gym-friendly rest countdown audio:
//  • Last 5 seconds → short tick each second (rising pitch)
//  • Zero → longer two-tone “go” chirp + success haptic
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

    /// `remainingWholeSeconds` is 5…1 when each second band is first entered.
    static func playCountdownTick(remainingWholeSeconds: Int) {
        guard RestTimerPreferences.isSoundEnabled else { return }
        guard remainingWholeSeconds >= 1, remainingWholeSeconds <= tickWindow else { return }
        configureSessionIfNeeded()

        // Rising pitch as you approach zero.
        let pitches: [Double] = [740, 830, 932, 1047, 1175] // for 5…1
        let index = max(0, min(tickWindow - 1, tickWindow - remainingWholeSeconds))
        playTone(frequency: pitches[index], duration: 0.07, volume: 0.35)

        let style: UIImpactFeedbackGenerator.FeedbackStyle =
            remainingWholeSeconds <= 2 ? .medium : .light
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.prepare()
        gen.impactOccurred(intensity: remainingWholeSeconds <= 2 ? 0.9 : 0.55)
    }

    /// Fired once when the timer hits zero.
    static func playComplete() {
        if RestTimerPreferences.isSoundEnabled {
            configureSessionIfNeeded()
            // Two-tone “go” — easy to hear over gym noise.
            playTone(frequency: 880, duration: 0.12, volume: 0.45)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                playTone(frequency: 1175, duration: 0.32, volume: 0.55)
            }
        }
        playCompleteHaptic()
    }

    // MARK: - Haptics

    private static func playCompleteHaptic() {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.success)
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            impact.impactOccurred(intensity: 1.0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            impact.impactOccurred(intensity: 1.0)
        }
    }

    // MARK: - Session / engine

    private static func configureSessionIfNeeded() {
        guard !didConfigureSession else { return }
        didConfigureSession = true
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Tone path may still work; otherwise we fall back to system sound.
        }
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
