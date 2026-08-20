//
//  HealthKitWorkoutService.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-26.
//

import Foundation
internal import HealthKit
#if canImport(UIKit)
import UIKit
#endif

struct HealthKitWorkoutStats {
    let duration: TimeInterval
    let activeCalories: Double
    let avgHeartRate: Double?
    let maxHeartRate: Double?
    let effortRating: Int?
}

@Observable
final class HealthKitWorkoutService {
    // MARK: - Public State

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    /// nil = never asked, true = authorized, false = denied
    private(set) var authorizationStatus: Bool?
    private(set) var isSessionActive = false
    private(set) var activeCalories: Double = 0
    private(set) var heartRate: Double?
    private(set) var elapsedSeconds: TimeInterval = 0

    // MARK: - Private State

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKWorkoutBuilder?
    private var sessionStartDate: Date?
    private var elapsedTimer: Timer?
    private var sessionDelegate = HKSessionDelegateProxy()
    private var foregroundObserver: NSObjectProtocol?

    private let kIsHKSessionActive = "hk_isSessionActive"
    private let kHKWorkoutStartDate = "hk_workoutStartDate"

    /// Wall clock from the original start, even if the live builder died (lock / kill).
    var wallClockElapsed: TimeInterval {
        if let start = sessionStartDate ?? persistedStartDate {
            return max(0, Date().timeIntervalSince(start))
        }
        return max(0, elapsedSeconds)
    }

    private var persistedStartDate: Date? {
        UserDefaults.standard.object(forKey: kHKWorkoutStartDate) as? Date
    }

    init() {
        if let start = persistedStartDate {
            sessionStartDate = start
            elapsedSeconds = Date().timeIntervalSince(start)
        }
        sessionDelegate.onFail = { error in
            print("[HealthKit] session failed: \(error)")
        }
        #if canImport(UIKit)
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.restartElapsedTimerIfNeeded()
        }
        #endif
    }

    deinit {
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
    }

    // MARK: - Data Types

    private var typesToWrite: Set<HKSampleType> {
        var types: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate),
        ]
        if #available(iOS 18.0, *) {
            types.insert(HKQuantityType(.workoutEffortScore))
        }
        return types
    }

    private var typesToRead: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate),
        ]
        if #available(iOS 18.0, *) {
            types.insert(HKQuantityType(.workoutEffortScore))
        }
        return types
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }

        do {
            try await healthStore.requestAuthorization(
                toShare: typesToWrite,
                read: typesToRead
            )
            let status = healthStore.authorizationStatus(for: HKObjectType.workoutType())
            authorizationStatus = (status == .sharingAuthorized)
            return authorizationStatus ?? false
        } catch {
            authorizationStatus = false
            return false
        }
    }

    func checkAuthorization() {
        guard isAvailable else {
            authorizationStatus = false
            return
        }
        let status = healthStore.authorizationStatus(for: HKObjectType.workoutType())
        switch status {
        case .sharingAuthorized:
            authorizationStatus = true
        case .sharingDenied:
            authorizationStatus = false
        case .notDetermined:
            authorizationStatus = nil
        @unknown default:
            authorizationStatus = nil
        }
    }

    // MARK: - Workout Session Lifecycle

    func startWorkout() async throws {
        guard isAvailable, authorizationStatus == true else { return }

        if workoutSession != nil || workoutBuilder != nil {
            await endWorkout()
        } else {
            // Stale start from a killed session belongs to that workout's Finish,
            // not a brand-new Start (which would write a multi-hour Health ghost).
            UserDefaults.standard.removeObject(forKey: kHKWorkoutStartDate)
            sessionStartDate = nil
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .functionalStrengthTraining
        configuration.locationType = .indoor

        let startDate = Date()
        self.sessionStartDate = startDate

        // Live HKWorkoutSession + HKLiveWorkoutDataSource on iPhone requires iOS 26+.
        // On iOS 17–25 use a plain HKWorkoutBuilder so sessions still save to Health.
        // Don't call prepare() then startActivity immediately — startActivity prepares.
        if #available(iOS 26.0, *) {
            let session = try HKWorkoutSession(
                healthStore: healthStore,
                configuration: configuration
            )
            session.delegate = sessionDelegate
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            self.workoutSession = session
            self.workoutBuilder = builder
            session.startActivity(with: startDate)
            try await builder.beginCollection(at: startDate)
        } else {
            let builder = HKWorkoutBuilder(
                healthStore: healthStore,
                configuration: configuration,
                device: .local()
            )
            self.workoutSession = nil
            self.workoutBuilder = builder
            try await builder.beginCollection(at: startDate)
        }

        isSessionActive = true

        UserDefaults.standard.set(true, forKey: kIsHKSessionActive)
        UserDefaults.standard.set(startDate, forKey: kHKWorkoutStartDate)

        startElapsedTimer()
    }

    func pauseWorkout() {
        workoutSession?.pause()
        isSessionActive = false
        stopElapsedTimer()
    }

    func resumeWorkout() {
        workoutSession?.resume()
        isSessionActive = true
        startElapsedTimer()
    }

    @discardableResult
    func endWorkout() async -> UUID? {
        let start = sessionStartDate ?? persistedStartDate
        let endDate = Date()
        let builder = workoutBuilder

        if let builder {
            workoutSession?.end()
            do {
                try await builder.endCollection(at: endDate)
                let finishedWorkout = try await builder.finishWorkout()
                clearState()
                return finishedWorkout?.uuid
            } catch {
                print("HealthKit workout finish error: \(error)")
            }
        }

        clearState()

        // Live session often dies when the phone locks (no workout-processing)
        // or the app is killed. Write the full window so Health duration matches gym time.
        if let start, endDate.timeIntervalSince(start) >= 30 {
            return await saveHistoricalWorkout(start: start, end: endDate)
        }
        return nil
    }

    /// Start a live HK session unless we already have a start date to finish historically.
    func recoverOrStartIfNeeded() async {
        if workoutBuilder != nil { return }
        if persistedStartDate != nil {
            sessionStartDate = persistedStartDate
            restartElapsedTimerIfNeeded()
            return
        }
        do {
            try await startWorkout()
        } catch {
            print("HealthKit recover/start error: \(error)")
        }
    }

    /// End the current HealthKit workout session WITHOUT saving data to Apple Health.
    func discardWorkout() async {
        guard let builder = workoutBuilder else {
            clearState()
            return
        }

        workoutSession?.end()

        do {
            try await builder.endCollection(at: Date())
        } catch {
            print("HealthKit endCollection error: \(error)")
        }
        builder.discardWorkout()
        clearState()
    }

    func cleanUpOrphanedState() {
        let wasActive = UserDefaults.standard.bool(forKey: kIsHKSessionActive)
        // After a kill, workoutSession is nil even if the gym session continues.
        // Keep the start date so finish can write a full-length Health workout.
        if wasActive && workoutSession == nil && workoutBuilder == nil {
            isSessionActive = false
            UserDefaults.standard.set(false, forKey: kIsHKSessionActive)
        }
    }

    // MARK: - Post-Workout Queries

    func fetchWorkoutStats(for workoutUUID: UUID) async -> HealthKitWorkoutStats? {
        guard isAvailable else { return nil }

        let predicate = HKQuery.predicateForObject(with: workoutUUID)

        let workout: HKWorkout? = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: samples?.first as? HKWorkout)
            }
            healthStore.execute(query)
        }

        guard let workout else { return nil }

        let duration = workout.duration
        let calories = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?
            .doubleValue(for: .kilocalorie()) ?? 0

        let hrStats = await fetchHeartRateStats(for: workout)
        let effort = await fetchEffortRating(for: workout)

        return HealthKitWorkoutStats(
            duration: duration,
            activeCalories: calories,
            avgHeartRate: hrStats?.avg,
            maxHeartRate: hrStats?.max,
            effortRating: effort
        )
    }

    func saveEffortRating(_ rating: Int, workoutUUID: UUID) async {
        guard isAvailable else {
            print("[HealthKit Effort] Not available")
            return
        }
        guard #available(iOS 18.0, *) else {
            print("[HealthKit Effort] workoutEffortScore requires iOS 18+")
            return
        }

        // Re-request authorization to ensure effort score type is included
        // (handles case where user authorized before this type was added)
        _ = await requestAuthorization()

        let predicate = HKQuery.predicateForObject(with: workoutUUID)

        let workout: HKWorkout? = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: samples?.first as? HKWorkout)
            }
            healthStore.execute(query)
        }

        guard let workout else {
            print("[HealthKit Effort] Could not find workout with UUID: \(workoutUUID)")
            return
        }

        let effortSample = HKQuantitySample(
            type: HKQuantityType(.workoutEffortScore),
            quantity: HKQuantity(unit: .appleEffortScore(), doubleValue: Double(rating)),
            start: workout.startDate,
            end: workout.endDate
        )

        do {
            try await healthStore.relateWorkoutEffortSample(effortSample, with: workout, activity: nil)
            print("[HealthKit Effort] Saved effort \(rating) for workout \(workoutUUID)")
        } catch {
            print("[HealthKit Effort] Save error: \(error)")
        }
    }

    // MARK: - Private

    private func fetchHeartRateStats(for workout: HKWorkout) async -> (avg: Double, max: Double)? {
        let heartRateType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForObjects(from: workout)
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: heartRateType,
                quantitySamplePredicate: predicate,
                options: [.discreteAverage, .discreteMax]
            ) { _, stats, _ in
                guard let stats,
                      let avg = stats.averageQuantity()?.doubleValue(for: bpmUnit),
                      let max = stats.maximumQuantity()?.doubleValue(for: bpmUnit)
                else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: (avg: avg, max: max))
            }
            healthStore.execute(query)
        }
    }

    private func fetchEffortRating(for workout: HKWorkout) async -> Int? {
        guard #available(iOS 18.0, *) else { return nil }

        let effortType = HKQuantityType(.workoutEffortScore)
        let predicate = HKQuery.predicateForWorkoutEffortSamplesRelated(workout: workout, activity: nil)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: effortType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let value = Int(sample.quantity.doubleValue(for: .appleEffortScore()))
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func saveHistoricalWorkout(start: Date, end: Date) async -> UUID? {
        guard isAvailable, authorizationStatus == true else { return nil }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .functionalStrengthTraining
        configuration.locationType = .indoor
        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: .local()
        )
        do {
            try await builder.beginCollection(at: start)
            try await builder.endCollection(at: end)
            let workout = try await builder.finishWorkout()
            return workout?.uuid
        } catch {
            print("HealthKit historical workout error: \(error)")
            return nil
        }
    }

    private func restartElapsedTimerIfNeeded() {
        if sessionStartDate == nil {
            sessionStartDate = persistedStartDate
        }
        guard sessionStartDate != nil else { return }
        elapsedSeconds = wallClockElapsed
        if isSessionActive || workoutBuilder != nil || persistedStartDate != nil {
            startElapsedTimer()
        }
    }

    private func startElapsedTimer() {
        stopElapsedTimer()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.elapsedSeconds = self.wallClockElapsed
            self.updateStatistics()
        }
        RunLoop.main.add(elapsedTimer!, forMode: .common)
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    private func updateStatistics() {
        guard let builder = workoutBuilder else { return }

        if let energyStats = builder.statistics(for: HKQuantityType(.activeEnergyBurned)) {
            activeCalories = energyStats.sumQuantity()?.doubleValue(
                for: .kilocalorie()
            ) ?? 0
        }

        if let hrStats = builder.statistics(for: HKQuantityType(.heartRate)) {
            heartRate = hrStats.mostRecentQuantity()?.doubleValue(
                for: HKUnit.count().unitDivided(by: .minute())
            )
        }
    }

    private func clearState() {
        stopElapsedTimer()
        workoutSession = nil
        workoutBuilder = nil
        sessionStartDate = nil
        isSessionActive = false
        activeCalories = 0
        heartRate = nil
        elapsedSeconds = 0

        UserDefaults.standard.set(false, forKey: kIsHKSessionActive)
        UserDefaults.standard.removeObject(forKey: kHKWorkoutStartDate)
    }
}

/// HKWorkoutSession.delegate is weak; keep this proxy alive on the service.
private final class HKSessionDelegateProxy: NSObject, HKWorkoutSessionDelegate {
    var onFail: ((Error) -> Void)?

    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {}

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        onFail?(error)
    }
}
