//
//  RestTimerSoundService.swift
//  strength-training
//
//  Gym-friendly rest countdown audio:
//  • Last 5 seconds → short tick each second (rising pitch)
//  • Zero → longer two-tone “go” chirp + success haptic
//
//  Screen lock: a near-silent looping player + UIBackgroundModes audio keeps
//  the process awake so the countdown Task can still fire real tones.
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

    /// Keeps AVAudioSession active across screen lock (requires Info.plist `audio` mode).
    private static var keepAlivePlayer: AVAudioPlayer?
    private static var keepAliveFileURL: URL?

    // MARK: - Public

    /// Warm audio session when rest starts (works with ringer off; mixes with music).
    static func prepareIfNeeded() {
        guard RestTimerPreferences.isSoundEnabled else { return }
        configureSessionIfNeeded()
        _ = sharedPlayer()
    }

    /// Call when a rest countdown is active so tones still work after the screen locks.
    static func startBackgroundKeepAlive() {
        guard RestTimerPreferences.isSoundEnabled else {
            stopBackgroundKeepAlive()
            return
        }
        configureSessionIfNeeded()
        if keepAlivePlayer == nil {
            keepAlivePlayer = makeKeepAlivePlayer()
        }
        guard let keepAlivePlayer else { return }
        if !keepAlivePlayer.isPlaying {
            keepAlivePlayer.volume = 0.02 // must be audible to OS (near-silent to user)
            keepAlivePlayer.play()
        }
    }

    static func stopBackgroundKeepAlive() {
        keepAlivePlayer?.stop()
        keepAlivePlayer = nil
        // Leave session active briefly so the final “go” chirp can finish.
    }

    /// `remainingWholeSeconds` is 5…1 when each second band is first entered.
    static func playCountdownTick(remainingWholeSeconds: Int) {
        guard RestTimerPreferences.isSoundEnabled else { return }
        guard remainingWholeSeconds >= 1, remainingWholeSeconds <= tickWindow else { return }
        configureSessionIfNeeded()
        startBackgroundKeepAlive()

        // Rising pitch as you approach zero.
        let pitches: [Double] = [740, 830, 932, 1047, 1175] // for 5…1
        let index = max(0, min(tickWindow - 1, tickWindow - remainingWholeSeconds))
        playTone(frequency: pitches[index], duration: 0.07, volume: 0.45)

        // Haptics only work while the device is unlocked / app is interactive.
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
            startBackgroundKeepAlive()
            // Two-tone “go” — easy to hear over gym noise.
            playTone(frequency: 880, duration: 0.12, volume: 0.55)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                playTone(frequency: 1175, duration: 0.35, volume: 0.65)
                // Drop keep-alive after the chirp finishes.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    stopBackgroundKeepAlive()
                }
            }
        } else {
            stopBackgroundKeepAlive()
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
        let session = AVAudioSession.sharedInstance()
        do {
            // playback + mixWithOthers: gym music can keep playing; we still get
            // background execution with UIBackgroundModes audio.
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            didConfigureSession = true
            try session.setActive(true, options: [])
        } catch {
            // Tone path may still work; otherwise we fall back to system sound.
        }
    }

    private static func makeKeepAlivePlayer() -> AVAudioPlayer? {
        do {
            let url = try silentLoopFileURL()
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0.02
            player.prepareToPlay()
            return player
        } catch {
            return nil
        }
    }

    /// Tiny looping WAV of near-silence (not absolute zero — iOS may ignore volume 0).
    private static func silentLoopFileURL() throws -> URL {
        if let keepAliveFileURL, FileManager.default.fileExists(atPath: keepAliveFileURL.path) {
            return keepAliveFileURL
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rocklog-rest-keepalive.wav")
        let seconds = 1.0
        let rate = 22_050
        let frames = Int(seconds * Double(rate))
        var data = Data()
        // PCM 16-bit mono WAV header
        let dataSize = frames * 2
        let fileSize = 36 + dataSize
        func appendUInt32(_ v: UInt32) {
            var le = v.littleEndian
            data.append(Data(bytes: &le, count: 4))
        }
        func appendUInt16(_ v: UInt16) {
            var le = v.littleEndian
            data.append(Data(bytes: &le, count: 2))
        }
        data.append(contentsOf: Array("RIFF".utf8))
        appendUInt32(UInt32(fileSize))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        appendUInt32(16)
        appendUInt16(1) // PCM
        appendUInt16(1) // mono
        appendUInt32(UInt32(rate))
        appendUInt32(UInt32(rate * 2))
        appendUInt16(2)
        appendUInt16(16)
        data.append(contentsOf: Array("data".utf8))
        appendUInt32(UInt32(dataSize))
        // Near-silence (not all zeros — some devices drop zero-volume streams).
        for i in 0..<frames {
            let sample = Int16((i % 256) == 0 ? 8 : 0)
            var le = sample.littleEndian
            data.append(Data(bytes: &le, count: 2))
        }
        try data.write(to: url, options: .atomic)
        keepAliveFileURL = url
        return url
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
