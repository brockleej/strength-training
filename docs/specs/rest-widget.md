# Rest Live Activity widget

The countdown on the Lock Screen and in the Dynamic Island is a Live Activity. The end-time local notification is the backup for when the app is not on screen. The app schedules that notification when rest starts and cancels it when the app itself plays the alert. There is no silent audio loop and no `audio` background mode.

## What the extension needs

The extension target is `RockLogWidget`. This build does not embed it. `FeatureFlags.liveActivity` is off, `NSSupportsLiveActivities` is false on the app, and the RockLog target has no dependency on the extension, so its signature is not part of the upload.

| | |
| --- | --- |
| Bundle ID | `com.lee.lift2026.restwidget` |
| Provisioning | Its own profile. The RockLog app profile does not sign the extension. |
| App Group | `group.com.lee.lift2026`, in `RockLogWidget/RockLogWidget.entitlements`. The app and the extension both belong to that group. |
| Live Activities | `NSSupportsLiveActivities` is set on the app `Info.plist` and on `RockLogWidget/Info.plist`. |
| Team | The same team as RockLog (`53AH938CUW` on the widget target). |

The activity content sets `staleDate` to the rest end. After that instant the system may show the activity as stale.

`Shared/RestActivity/RestActivityAttributes.swift` is compiled into the app. The widget file repeats those fields (`rangeStart`, `endDate`, `interval`) because an app extension does not share the app module. The two declarations have to stay the same.

This build does not ship an Apple Watch complication.
