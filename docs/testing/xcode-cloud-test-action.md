# Xcode Cloud test action

RockLog’s shared scheme already runs the unit and UI tests. Xcode Cloud still only archives unless the workflow has a Test action in front of Archive. Add that in App Store Connect. This repo cannot turn it on by itself.

Pushes to `main` archive RockLog for TestFlight. Do not point the workflow at the RockCoach scheme. `ci_scripts/ci_pre_xcodebuild.sh` fails that scheme on purpose.

## Add the action

1. App Store Connect → your app → Xcode Cloud → the workflow that archives RockLog.
2. Edit workflow → Actions. Add **Test** and place it **before Archive**.
3. Scheme: **RockLog** (the shared scheme in `RockLog.xcodeproj`). Leave RockCoach out.
4. The scheme’s test plan is `RockLog.xcodeproj/xcshareddata/xctestplans/RockLogSuite.xctestplan`. It is named `RockLogSuite` so it does not collide with the RockLog scheme. It already includes `RockLogTests` and `RockLogUITests`. You do not need a second plan in App Store Connect.
5. Destinations: one small iPhone simulator and one large iPhone simulator. Names depend on the Xcode Cloud image. Locally this repo uses iPhone 17; also run an iPhone SE (or the smallest installed phone) and iPhone 17 Pro Max (or the largest installed phone). UI tests need a simulator. Unit tests are hosted in RockLog.app.
6. Save the workflow. The next build on that branch runs tests, then archives only if tests pass.

## Run the same plan locally

```bash
xcodebuild test -scheme RockLog -destination 'platform=iOS Simulator,name=iPhone 17'

xcodebuild test -scheme RockLog -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RockLogTests
xcodebuild test -scheme RockLog -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RockLogUITests

xcodebuild test -scheme RockLog -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' -only-testing:RockLogUITests
xcodebuild test -scheme RockLog -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:RockLogUITests
```

Use the simulator names from `xcrun simctl list devices available` when those exact names are not installed.

UI tests launch RockLog with `-RockLogUITesting` and a preset (`empty`, `typical`, `longHistory`, `planWaiting`). The data is synthetic and lives in an in-memory store, except the mid-workout relaunch test, which uses a temp file under Application Support and deletes it unless `-RockLogRelaunchKeep` is set. Release builds ignore these flags. The tests do not write the training split into iCloud.
