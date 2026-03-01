//
//  HapticService.swift
//  strength-training
//

import UIKit
import CoreHaptics

enum HapticService {

    // MARK: - Standard Haptics

    static func setLogged() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    static func exerciseCompleted() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    static func stepperTick() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    static func swipeToDelete() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    // MARK: - Custom Pattern (Workout Completed)

    static func workoutCompleted() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            fallbackWorkoutCompleted()
            return
        }

        do {
            let engine = try CHHapticEngine()
            try engine.start()

            let events: [CHHapticEvent] = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                    ],
                    relativeTime: 0.12
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                    ],
                    relativeTime: 0.24
                ),
            ]

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)

            engine.notifyWhenPlayersFinished { _ in .stopEngine }
        } catch {
            fallbackWorkoutCompleted()
        }
    }

    private static func fallbackWorkoutCompleted() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                generator.notificationOccurred(.success)
            }
        }
    }
}
