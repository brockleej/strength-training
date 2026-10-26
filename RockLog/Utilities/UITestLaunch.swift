//
//  UITestLaunch.swift
//  RockLog
//
//  Debug-only launch arguments for XCUITest. Release builds ignore every
//  flag here (`isEnabled` is constant false), so TestFlight never opens an
//  in-memory store or reads an injected file.
//
//  Presets are synthetic (names prefixed "UI "). They are not a user log,
//  a CSV, or a backup taken from a phone.
//

import Foundation
import SwiftData
import SwiftUI

enum UITestPreset: String {
    case empty
    case typical
    case longHistory
    case planWaiting
}

enum UITestLaunch {
    static let testingArgument = "-RockLogUITesting"
    static let presetArgument = "-RockLogPreset"
    static let relaunchStoreArgument = "-RockLogRelaunchStore"
    static let relaunchKeepArgument = "-RockLogRelaunchKeep"
    static let dynamicTypeArgument = "-RockLogDynamicType"
    static let injectEnvironmentKey = "ROCKLOG_INJECT_FILE_B64"

    /// Stashed when a UI test injects a backup. Settings presents the
    /// restore confirm so Cancel can be tapped without the Files picker.
    static var pendingBackupData: Data?

    static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains(testingArgument)
        #else
        false
        #endif
    }

    static var preset: UITestPreset {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: presetArgument),
              index + 1 < args.count,
              let preset = UITestPreset(rawValue: args[index + 1]) else {
            return .empty
        }
        return preset
        #else
        return .empty
        #endif
    }

    /// Process-death relaunch cannot survive an in-memory store. This flag
    /// uses a temp file under Application Support that is deleted unless
    /// `-RockLogRelaunchKeep` is also set. Still synthetic, still debug-only.
    static var usesRelaunchDisk: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains(relaunchStoreArgument)
        #else
        false
        #endif
    }

    static var keepsRelaunchStore: Bool {
        #if DEBUG
        usesRelaunchDisk && ProcessInfo.processInfo.arguments.contains(relaunchKeepArgument)
        #else
        false
        #endif
    }

    static var dynamicTypeSize: DynamicTypeSize? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: dynamicTypeArgument),
              index + 1 < args.count else { return nil }
        switch args[index + 1] {
        case "xSmall": return .xSmall
        case "small": return .small
        case "medium": return .medium
        case "large": return .large
        case "xLarge": return .xLarge
        case "xxLarge": return .xxLarge
        case "xxxLarge": return .xxxLarge
        case "accessibility1": return .accessibility1
        case "accessibility2": return .accessibility2
        case "accessibility3": return .accessibility3
        case "accessibility4": return .accessibility4
        case "accessibility5": return .accessibility5
        default: return nil
        }
        #else
        return nil
        #endif
    }

    static func injectedFileData() -> Data? {
        #if DEBUG
        guard let raw = ProcessInfo.processInfo.environment[injectEnvironmentKey],
              let data = Data(base64Encoded: raw) else { return nil }
        return data
        #else
        return nil
        #endif
    }

    static func consumePendingBackup() -> Data? {
        let data = pendingBackupData
        pendingBackupData = nil
        return data
    }

    #if DEBUG
    /// UserDefaults only. Does not write iCloud KVS — a UI test must not
    /// publish a split into the signed-in tester's account.
    static func prepareDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: RestTimerPreferences.enabledKey)
        defaults.set(false, forKey: RestTimerPreferences.soundEnabledKey)
        defaults.set(false, forKey: CoachAthletePreferences.shareAfterFinishKey)
        defaults.set(false, forKey: CoachAthletePreferences.enabledKey)
        defaults.set(SplitScheduleMode.rolling.rawValue, forKey: SplitSchedulePreferences.modeKey)
        defaults.removeObject(forKey: SeedData.splitSnapshotKey)
        defaults.removeObject(forKey: SeedData.dayPlanSnapshotKey)

        switch preset {
        case .empty:
            defaults.set(false, forKey: FirstRunPreferences.completedKey)
            defaults.set(false, forKey: SeedData.hasConfiguredSplitKey)
            defaults.removeObject(forKey: SeedData.preferredSplitPresetKey)
            // A prior typical/longHistory launch leaves the catalog marked
            // seeded. The empty preset is a first launch and must insert it
            // so starter plans have Dumbbell Bench Press to pin.
            // resetExerciseCatalogSeed itself no-ops for every other launch.
            SeedData.resetExerciseCatalogSeed()
        case .typical, .longHistory, .planWaiting:
            defaults.set(true, forKey: FirstRunPreferences.completedKey)
            defaults.set(true, forKey: SeedData.hasConfiguredSplitKey)
            defaults.set(SplitPreset.pushPullLegs.rawValue, forKey: SeedData.preferredSplitPresetKey)
            defaults.set(true, forKey: SeedData.hasSeededExercisesKey)
            defaults.set(true, forKey: SeedData.strippedUnusedStarterExtrasKey)
            // Matches SeedData.catalogVersion so a stray top-up does not
            // insert the stock catalog next to the synthetic lifts.
            defaults.set(2, forKey: "exerciseCatalogVersion")
        }
    }

    static func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Exercise.self,
            WorkoutSession.self,
            ExerciseRecord.self,
            SetRecord.self,
            SplitDay.self,
            BodyMetricEntry.self,
            TrainingBlock.self,
            Gym.self,
            MachineStackProfile.self,
        ])
        let configuration: ModelConfiguration
        if usesRelaunchDisk {
            let url = relaunchStoreURL
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if !keepsRelaunchStore {
                resetRelaunchStore(at: url)
            }
            configuration = ModelConfiguration(
                "RockLogUITestRelaunch",
                schema: schema,
                url: url,
                cloudKitDatabase: .none
            )
        } else {
            configuration = ModelConfiguration(
                "RockLogUITestMemory-\(UUID().uuidString)",
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static var relaunchStoreURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("RockLogUITests", isDirectory: true)
            .appendingPathComponent("Relaunch.store")
    }

    static func resetRelaunchStore(at url: URL) {
        let fm = FileManager.default
        let extras = [
            url,
            URL(fileURLWithPath: url.path + "-wal"),
            URL(fileURLWithPath: url.path + "-shm"),
        ]
        for item in extras where fm.fileExists(atPath: item.path) {
            try? fm.removeItem(at: item)
        }
    }
    #endif
}
