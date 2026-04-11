//
//  HealthKitWorkoutService.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-26.
//

import Foundation
internal import HealthKit

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

    private let kIsHKSessionActive = "hk_isSessionActive"
    private let kHKWorkoutStartDate = "hk_workoutStartDate"

    // MARK: - Data Types

    private var typesToWrite: Set<HKSampleType> {
        [
            HKObjectType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate),
            HKQuantityType(.workoutEffortScore),
        ]
    }

    private var typesToRead: Set<HKObjectType> {
        [
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate),
            HKQuantityType(.workoutEffortScore),
        ]
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

        if workoutSession != nil {
            await endWorkout()
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .functionalStrengthTraining
        configuration.locationType = .indoor

        let session = try HKWorkoutSession(
            healthStore: healthStore,
            configuration: configuration
        )
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )

        self.workoutSession = session
        self.workoutBuilder = builder

        let startDate = Date()
        self.sessionStartDate = startDate

        session.prepare()
        session.startActivity(with: startDate)
        try await builder.beginCollection(at: startDate)

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
        guard let session = workoutSession, let builder = workoutBuilder else {
            clearState()
            return nil
        }

        let endDate = Date()
        session.end()

        do {
            try await builder.endCollection(at: endDate)
            let finishedWorkout = try await builder.finishWorkout()
            clearState()
            return finishedWorkout?.uuid
        } catch {
            print("HealthKit workout finish error: \(error)")
            clearState()
            return nil
        }
    }

    func cleanUpOrphanedState() {
        let wasActive = UserDefaults.standard.bool(forKey: kIsHKSessionActive)
        if wasActive && workoutSession == nil {
            UserDefaults.standard.set(false, forKey: kIsHKSessionActive)
            UserDefaults.standard.removeObject(forKey: kHKWorkoutStartDate)
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

    private func startElapsedTimer() {
        stopElapsedTimer()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let start = self.sessionStartDate else { return }
            self.elapsedSeconds = Date().timeIntervalSince(start)
            self.updateStatistics()
        }
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
