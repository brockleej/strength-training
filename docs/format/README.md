# RockLog interchange

One JSON envelope for backups, coach files, program files, and split files.

```json
{
  "format": "rocklog.interchange",
  "formatVersion": 1,
  "weightUnit": "lb",
  "exportedAt": "2026-01-01T00:00:00Z",
  "kind": "backup",
  "payload": {}
}
```

- `formatVersion` is 1 for files this build writes. Version 2 is the same document plus `unitSystem`, copied from `weightUnit`. Stepping back to 1 keeps `unitSystem`. Version 0 and anything above 2 are refused.
- `weightUnit` is `lb` or `kg`. It names the display unit. Every weight number in the payload is still pounds, at full stored precision. Nothing is rounded to a display step on the way into the file.
- The backup payload's own `version` is 2 when the V2 fields ship. Version 1 is still accepted and promoted by `BackupMigration.promoteToCurrent` in `Shared/Algorithm/BackupMigration.swift`. That function only writes `version: 2`. It does not invent gyms, blocks, or measurements, and it does not drop keys. Version 0 and anything above 2 are refused.
- `kind` is `backup`, `coach.session`, `coach.batch`, `program`, or `split`.
- Stable `id` values are UUID strings. Restore keeps the same id. It does not mint a new one. Two rows in the same list with the same id, including ids that differ only by letter case, are refused.
- Keys and enum strings this version does not know are counted and shown on the restore prompt. They are not applied and they are not dropped without that count.
- Stack pin numbers are in `pinUnitRaw` (`lb` or `kg`). They are not converted to pounds in the file. `stepPounds` stays pounds.

Older files that are not envelopes (a backup with `version` and `exercises`, a `rocklog.coach.session`, a `rocklog.program`, or a `rocklog.split`) are lifted into this envelope. The original object becomes `payload`.

The JSON Schema is `rocklog.interchange.schema.json`. Templates and synthetic samples, rebuilt from the shapes in git history, are in `samples/`. They are not anyone's training log. `samples/backup-v2.json` is a version 2 backup with a training block, a body-weight row, and a kilogram pin list.

## Backup payload fields

`version` 2. Weights are pounds unless the unit column says otherwise. "Missing" means an older file may omit the key. A missing list (`gyms`, `stackProfiles`, `trainingBlocks`, `bodyMetrics`, `splitDays`, `dayPlans`) leaves the phone's rows alone. An empty list replaces them.

### Backup

| Field | Type | Unit | Optional / default |
| --- | --- | --- | --- |
| version | integer | — | Required. 1 is promoted to 2. 0 and 3+ are refused. |
| exportedAt | string, ISO-8601 | — | Required. |
| exercises | array | — | Required. May be empty. |
| sessions | array | — | Required. May be empty. |
| splitDays | array | — | Missing on older files. Empty means no days. |
| dayPlans | array | — | Missing on older files. |
| trainingBlocks | array | — | Missing leaves programs alone. Empty clears them. |
| bodyMetrics | array | — | Missing leaves measurements alone. Empty clears them. |
| gyms | array | — | Missing leaves gyms alone. V2. |
| stackProfiles | array | — | Missing leaves profiles alone. V2. |

### Exercise

| Field | Type | Unit | Optional / default |
| --- | --- | --- | --- |
| id | UUID string | — | Required. Kept as-is. |
| name | string | — | Required. |
| dayType | string | — | Required. Empty means unassigned. |
| muscleGroup | string | — | Required. |
| sortOrder | integer | — | Required. |
| isCustom | bool | — | Required. |
| notes | string | — | Required. Empty string if none. |
| rotationTrack | string | — | Missing means every week. `""`, `A`, or `B`. |
| extraDayTypes | string | — | Missing means none. Comma-separated day names. |
| daySortOrdersRaw | string | — | Missing means `sortOrder`. `Push:0,Legs:3`. |
| defaultRestSeconds | integer | seconds | Missing or 0 uses the seed or Settings. V2. |
| autoRestEnabled | bool | — | Missing means the lift still follows the global switch until the one-time copy. V2. |
| loadModeRaw | string | — | Missing means bar, or assist when a set is assisted. `bar`, `assist`, `added`. V2. |
| suggestWarmupRamp | bool | — | Missing means off. V2. |

### Session

| Field | Type | Unit | Optional / default |
| --- | --- | --- | --- |
| id | UUID string | — | Required. |
| date | string, ISO-8601 | — | Required. |
| dayType | string | — | Required. |
| notes | string | — | Required. |
| isCompleted | bool | — | Required. |
| exerciseRecords | array | — | Required. |
| rotationTrack | string | — | Missing means A. |
| durationSeconds | number | seconds | Missing or 0 means unknown. |
| planState | string | — | Missing means a normal log. `planned` or `skipped`. |
| followsSessionRoster | bool | — | Missing means false. |
| planOrder | integer | — | Missing means 0. Index inside an imported block. |

### Exercise log

| Field | Type | Unit | Optional / default |
| --- | --- | --- | --- |
| id | UUID string | — | Required. |
| exerciseID | UUID string | — | Missing means the lift was not in the library. |
| trainingMode | string | — | Required. `Strength` or `Endurance`. Any other value is counted and the log is skipped. |
| sortOrder | integer | — | Required. |
| isCompleted | bool | — | Required. |
| notes | string | — | Required. |
| sets | array | — | Required. |
| groupID | UUID string | — | Missing means the lift is not in a circuit. V2. |
| groupPosition | integer | 1…4 | Missing means not in a circuit. V2. |

### Set

| Field | Type | Unit | Optional / default |
| --- | --- | --- | --- |
| id | UUID string | — | Required. |
| setNumber | integer | — | Required. |
| weightLbs | number | pounds, full precision | Required. Finite, 0 through 10000. |
| reps | integer | reps | Required. Zero or greater. |
| isWarmup | bool | — | Required. |
| isEachSide | bool | — | Missing means false. |
| isAssisted | bool | — | Missing means false. |
| completedAt | string, ISO-8601 | — | Required. |
| isTarget | bool | — | Missing means a logged set, not a plan target. |
| offeredWeightLbs | number | pounds, full precision | Missing means no stored offer. V2. |
| loadModeRaw | string | — | Missing uses `isAssisted`. V2. |
| bodyWeightUsedLbs | number | pounds, full precision | Missing or 0 means look the weigh-in up by date. V2. |
| plannedRestSeconds | integer | seconds | Missing means none stored. V2. |
| actualRestSeconds | integer | seconds | Missing means none stored. V2. |

### Split day

| Field | Type | Unit | Optional / default |
| --- | --- | --- | --- |
| id | UUID string | — | Required. |
| name | string | — | Required. |
| systemImage | string | — | Required. SF Symbol name. |
| subtitle | string | — | Required. |
| colorHex | integer | — | Required. |
| includesAllExercises | bool | — | Required. |
| sortOrder | integer | — | Required. |

### Day plan

| Field | Type | Unit | Optional / default |
| --- | --- | --- | --- |
| dayName | string | — | Required. |
| exerciseIDs | array of UUID strings | — | Required. Order is the roster. |

### Training block

| Field | Type | Unit | Optional / default |
| --- | --- | --- | --- |
| id | UUID string | — | Required. |
| name | string | — | Required. |
| notes | string | — | Required. |
| startDate | string, ISO-8601 | — | Required. |
| importedAt | string, ISO-8601 | — | Required. |
| sessionIDs | array of UUID strings | — | Required. Those sessions already have their own ids. |

### Body metric

| Field | Type | Unit | Optional / default |
| --- | --- | --- | --- |
| id | UUID string | — | Required. |
| date | string, ISO-8601 | — | Required. |
| kindRaw | string | — | Required. `weight`, `waist`, `neck`, `chest`, `arm`, `hips`. Anything else is counted and the row is skipped. |
| value | number | pounds for `weight`, inches for girths | Required. Finite, 0 through 10000. |
| note | string | — | Required. Empty if none. |

### Gym

| Field | Type | Unit | Optional / default |
| --- | --- | --- | --- |
| id | UUID string | — | Required. V2. |
| name | string | — | Required. |
| isHome | bool | — | Required. |
| createdAt | string, ISO-8601 | — | Required. |
| sortOrder | integer | — | Required. |

### Stack profile

| Field | Type | Unit | Optional / default |
| --- | --- | --- | --- |
| id | UUID string | — | Required. V2. |
| gymID | UUID string | — | Required. |
| exerciseID | UUID string | — | Required. |
| stepPounds | number | pounds | Required. 0 means no fixed step. |
| pinsRaw | string | numbers in `pinUnitRaw`, comma-separated, full precision | Required. Empty means no pin list. |
| pinUnitRaw | string | `lb` or `kg` | Required. The pin list is not rescaled to pounds. |
| addOnsRaw | string | same unit as the pins | Required. One add-on at a time. |
| policyRaw | string | — | Required. `nearest`, `down`, or `up`. |
| originRaw | string | — | Required. `learned`, `typed`, or empty. |
| learnedSessionIDsRaw | string | — | Required. Comma-separated UUID strings. |
| clearedAt | string, ISO-8601 | — | Missing means the learned step was never cleared. |
| learningEnabled | bool | — | Required. |
| rangeMin | number | pin unit | Required. |
| rangeMax | number | pin unit | Required. |
| updatedAt | string, ISO-8601 | — | Missing on older V2 drafts. Later time wins between two devices when the origin is the same. |

