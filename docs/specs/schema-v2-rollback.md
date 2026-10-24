# Rolling RockLogSchemaV2 back

`RockLogSchemaV2` is a lightweight step after `RockLogSchemaV1`. It adds fields with defaults and two new models, `Gym` and `MachineStackProfile`. It does not rename or delete a V1 field.

## What a V2 phone has that a V1 build cannot read

SwiftData will not open a store that has already moved to version 2.0.0 in a build whose migration plan stops at version 1.0.0. Installing an older TestFlight build on a phone that already opened this one fails at launch with a store error. CloudKit has the same limit: there is no heavy migration that walks the store backward.

New rows (gyms, stack profiles, offered weights, load mode, rest seconds, circuit groups) are simply absent from a V1 model. They are not required to open a V1 store that has never been migrated.

## How to roll back

1. In this build, export a backup from Settings. The file is an interchange envelope. The payload is still a version-1 backup, so a V1 importer that ignores unknown keys can read the exercises, sessions, and sets.
2. Delete the app. That drops the local V2 store. iCloud may still have the V2 schema; if the old build then fails to sync, turn iCloud off for RockLog on that phone or use a device that has not synced this build.
3. Install the previous build.
4. Restore the backup. Unknown V2 keys are dropped by the old decoder. History, the split, and body metrics that the old file understood come back. Learned stack steps, gyms, offered weights, and circuit groups do not.
5. Do not copy the V2 store file onto the old build. That is the path that will not open.

There is no in-place downgrade. The safe direction is backup, delete, install the old build, restore.

## CloudKit

V2 does not rename a field. Every new stored value is optional or has a default: rest seconds, the rest switch, the warm-up ramp switch, load mode, offered weight, the body weight used on a set, circuit group id and position, gyms, and stack profiles. Relationships stay optional. The pin list is one string (`pinsRaw`), not a related row per pin. There is no unique constraint, so two devices can each insert a profile for the same gym and lift. The reader picks one. It does not delete the other.

`updatedAt` ships in this first V2. It is not a later schema. Do not add `RockLogSchemaV3` for it.

Do not promote the production CloudKit schema from this branch. The app does not call a schema-deploy API. Deploying development schema to production is a console step, and it waits until Lee asks for it. A test that opens a V1 store under V2 uses a synthetic on-disk store with `cloudKitDatabase: .none`.
