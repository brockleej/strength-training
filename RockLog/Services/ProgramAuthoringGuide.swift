//
//  ProgramAuthoringGuide.swift
//  RockLog
//
//  Plain instructions an AI (or a person) can follow to write a
//  rocklog.program file. Planned-workout structure only.
//

import Foundation

enum ProgramAuthoringGuide {
    static let fileName = "RockLog-planned-workout-instructions.md"

    static let markdown = """
    # RockLog planned-workout file

    Paste this whole note into Grok, ChatGPT, Claude, or another assistant. Ask it to write a training block as a **rocklog.program** JSON file. Import that file in RockLog: Settings → Add planned workouts.

    This format is **planned workouts only**. Do not invent extra keys. Do not write a backup. Do not write a coach-export file.

    ## What the file is

    - JSON object.
    - `"format"` must be exactly `rocklog.program`.
    - `"schemaVersion"` must be `1`.
    - `block.sessions` is an **ordered queue**. First session is next up. Missed calendar days are not skipped.
    - Same `dayType` may appear more than once (e.g. two Lowers in one week with different lifts).
    - Each `id` must be a unique UUID string.
    - Weights are pounds (`weightLbs`).
    - Save as `.json` or `.rocklogprogram`.

    ## Required shape

    ```json
    {
      "format": "rocklog.program",
      "schemaVersion": 1,
      "exportedAt": "2026-09-13T00:00:00Z",
      "block": {
        "id": "11111111-1111-4111-8111-111111111111",
        "name": "4-Week PPL",
        "notes": "Optional.",
        "startDate": "2026-09-15",
        "sessions": []
      }
    }
    ```

    `exportedAt` is ISO-8601 date-time. `startDate` and each session `date` may be `YYYY-MM-DD` or a full ISO-8601 date-time.

    ## Session

    Required: `id`, `date`, `dayType`, `exercises`.

    | Field | Rules |
    | --- | --- |
    | `id` | New UUID per session |
    | `date` | Metadata only. Queue order is file order, not this date |
    | `dayType` | Display name: `Lower`, `Push`, `Pull`, `Legs`, `Upper`, `Arms`, or any custom day name |
    | `rotationTrack` | Optional. `"A"`, `"B"`, or omit |
    | `notes` | Optional |
    | `exercises` | Ordered list of lifts for that day |

    ## Exercise

    Required: `id`, `name`, `sets`.

    | Field | Rules |
    | --- | --- |
    | `id` | New UUID per exercise row. Reuse the same UUID if the lift already exists in RockLog |
    | `name` | Exact lift name (e.g. `Barbell Bench Press`) |
    | `muscleGroup` | Optional. Comma-separated is fine |
    | `trainingMode` | Optional. `"Strength"` or `"Endurance"` |
    | `notes` | Optional |
    | `sets` | Warmups and work sets, in order |

    ## Set

    Required: `setNumber`, `weightLbs`, `reps`.

    | Field | Rules |
    | --- | --- |
    | `setNumber` | Integer starting at 1, unique in that exercise |
    | `weightLbs` | Number, pounds. For assisted work, put the assist load here and set `isAssisted` true |
    | `reps` | Integer, 0 or more |
    | `isWarmup` | Optional boolean, default false |
    | `isEachSide` | Optional boolean (e.g. lunges, curls) |
    | `isAssisted` | Optional boolean |

    Extra JSON keys are not allowed.

    ## Tiny example (one day)

    ```json
    {
      "format": "rocklog.program",
      "schemaVersion": 1,
      "exportedAt": "2026-09-13T12:00:00Z",
      "block": {
        "id": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
        "name": "Sample Push Day",
        "startDate": "2026-09-15",
        "sessions": [
          {
            "id": "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
            "date": "2026-09-15",
            "dayType": "Push",
            "rotationTrack": "A",
            "exercises": [
              {
                "id": "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
                "name": "Barbell Bench Press",
                "muscleGroup": "Chest, Triceps, Shoulders",
                "trainingMode": "Strength",
                "sets": [
                  { "setNumber": 1, "weightLbs": 95, "reps": 8, "isWarmup": true },
                  { "setNumber": 2, "weightLbs": 135, "reps": 5, "isWarmup": true },
                  { "setNumber": 3, "weightLbs": 185, "reps": 5 },
                  { "setNumber": 4, "weightLbs": 185, "reps": 5 },
                  { "setNumber": 5, "weightLbs": 185, "reps": 5 }
                ]
              },
              {
                "id": "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
                "name": "Overhead Press",
                "muscleGroup": "Shoulders, Triceps",
                "trainingMode": "Strength",
                "sets": [
                  { "setNumber": 1, "weightLbs": 75, "reps": 8, "isWarmup": true },
                  { "setNumber": 2, "weightLbs": 95, "reps": 8 },
                  { "setNumber": 3, "weightLbs": 95, "reps": 8 }
                ]
              }
            ]
          }
        ]
      }
    }
    ```

    ## Prompt you can add

    Write a complete rocklog.program JSON file for my training. Follow the rules in this note exactly. Output only valid JSON (no markdown fences unless I ask). Use new UUIDs. Put sessions in the order I should train them.

    Then describe the days, lifts, sets, and any constraints (equipment, days per week, injuries).
    """

    static func writeFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try Data(markdown.utf8).write(to: url, options: .atomic)
        return url
    }
}
