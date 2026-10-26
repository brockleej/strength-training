//
//  SyntheticPayloads.swift
//  RockLogUITests
//
//  Hand-written JSON for injected files. Names are prefixed "UI ".
//  These are not exports of a real log.
//

import Foundation

enum SyntheticPayloads {
    static func programMysteryLift() -> String {
        """
        {
          "format": "rocklog.program",
          "schemaVersion": 1,
          "exportedAt": "2026-01-01T00:00:00Z",
          "block": {
            "id": "A1000000-0000-4000-8000-000000000001",
            "name": "UI Imported Block",
            "notes": "",
            "startDate": "2026-01-01T00:00:00Z",
            "sessions": [
              {
                "id": "A1000000-0000-4000-8000-000000000002",
                "date": "2026-01-02T00:00:00Z",
                "dayType": "Push",
                "rotationTrack": "A",
                "notes": "",
                "exercises": [
                  {
                    "id": "A1000000-0000-4000-8000-000000000003",
                    "name": "UI Mystery Lift",
                    "muscleGroup": "Chest",
                    "trainingMode": "Strength",
                    "notes": "",
                    "sets": [
                      {"setNumber": 1, "weightLbs": 0, "reps": 10, "isWarmup": false, "isEachSide": false, "isAssisted": false},
                      {"setNumber": 2, "weightLbs": 10000, "reps": 1, "isWarmup": false, "isEachSide": false, "isAssisted": false}
                    ]
                  }
                ]
              }
            ]
          }
        }
        """
    }

    static func splitAlphaBeta() -> String {
        """
        {
          "format": "rocklog.split",
          "schemaVersion": 1,
          "exportedAt": "2026-01-01T00:00:00Z",
          "block": {
            "id": "B2000000-0000-4000-8000-000000000001",
            "name": "UI Split File",
            "notes": "",
            "startDate": "2026-01-01T00:00:00Z",
            "sessions": [
              {
                "id": "B2000000-0000-4000-8000-000000000002",
                "date": "2026-01-02T00:00:00Z",
                "dayType": "UI Alpha",
                "notes": "",
                "exercises": [
                  {
                    "id": "B2000000-0000-4000-8000-000000000003",
                    "name": "UI Alpha Lift",
                    "muscleGroup": "Chest",
                    "trainingMode": "Strength",
                    "notes": "",
                    "sets": [
                      {"setNumber": 1, "weightLbs": 45, "reps": 8, "isWarmup": false}
                    ]
                  }
                ]
              },
              {
                "id": "B2000000-0000-4000-8000-000000000004",
                "date": "2026-01-03T00:00:00Z",
                "dayType": "UI Beta",
                "notes": "",
                "exercises": [
                  {
                    "id": "B2000000-0000-4000-8000-000000000005",
                    "name": "UI Beta Lift",
                    "muscleGroup": "Back",
                    "trainingMode": "Strength",
                    "notes": "",
                    "sets": [
                      {"setNumber": 1, "weightLbs": 65, "reps": 8, "isWarmup": false}
                    ]
                  }
                ]
              }
            ]
          }
        }
        """
    }

    static func backupRestoredLift() -> String {
        """
        {
          "version": 1,
          "exportedAt": "2026-01-15T12:00:00Z",
          "exercises": [
            {
              "id": "C3000000-0000-4000-8000-000000000001",
              "name": "UI Restored Lift",
              "dayType": "UI Day",
              "muscleGroup": "Chest",
              "sortOrder": 0,
              "isCustom": true,
              "notes": "",
              "rotationTrack": "",
              "extraDayTypes": "",
              "daySortOrdersRaw": ""
            }
          ],
          "sessions": [
            {
              "id": "C3000000-0000-4000-8000-000000000002",
              "date": "2026-01-15T12:00:00Z",
              "dayType": "UI Day",
              "notes": "",
              "isCompleted": true,
              "rotationTrack": "A",
              "durationSeconds": 2400,
              "planState": "",
              "followsSessionRoster": false,
              "planOrder": 0,
              "exerciseRecords": [
                {
                  "id": "C3000000-0000-4000-8000-000000000003",
                  "exerciseID": "C3000000-0000-4000-8000-000000000001",
                  "trainingMode": "Strength",
                  "sortOrder": 0,
                  "isCompleted": true,
                  "notes": "",
                  "sets": [
                    {
                      "id": "C3000000-0000-4000-8000-000000000004",
                      "setNumber": 1,
                      "weightLbs": 135,
                      "reps": 5,
                      "isWarmup": false,
                      "isEachSide": false,
                      "isAssisted": false,
                      "completedAt": "2026-01-15T12:10:00Z",
                      "isTarget": false
                    }
                  ]
                }
              ]
            }
          ],
          "splitDays": [
            {
              "id": "C3000000-0000-4000-8000-000000000005",
              "name": "UI Day",
              "systemImage": "dumbbell.fill",
              "subtitle": "Synthetic",
              "colorHex": 4169983,
              "includesAllExercises": false,
              "sortOrder": 0
            }
          ],
          "dayPlans": [
            {
              "dayName": "UI Day",
              "exerciseIDs": ["C3000000-0000-4000-8000-000000000001"]
            }
          ]
        }
        """
    }

    /// Week-A-only lift plus a completed A session. The next start is week B,
    /// which hides this lift until the week control is switched back to A.
    static func backupRestoredWeekALift() -> String {
        """
        {
          "version": 1,
          "exportedAt": "2026-01-15T12:00:00Z",
          "exercises": [
            {
              "id": "D4000000-0000-4000-8000-000000000001",
              "name": "UI A Week Lift",
              "dayType": "UI Day",
              "muscleGroup": "Chest",
              "sortOrder": 0,
              "isCustom": true,
              "notes": "",
              "rotationTrack": "A",
              "extraDayTypes": "",
              "daySortOrdersRaw": ""
            }
          ],
          "sessions": [
            {
              "id": "D4000000-0000-4000-8000-000000000002",
              "date": "2026-01-15T12:00:00Z",
              "dayType": "UI Day",
              "notes": "",
              "isCompleted": true,
              "rotationTrack": "A",
              "durationSeconds": 2400,
              "planState": "",
              "followsSessionRoster": false,
              "planOrder": 0,
              "exerciseRecords": [
                {
                  "id": "D4000000-0000-4000-8000-000000000003",
                  "exerciseID": "D4000000-0000-4000-8000-000000000001",
                  "trainingMode": "Strength",
                  "sortOrder": 0,
                  "isCompleted": true,
                  "notes": "",
                  "sets": [
                    {
                      "id": "D4000000-0000-4000-8000-000000000004",
                      "setNumber": 1,
                      "weightLbs": 95,
                      "reps": 8,
                      "isWarmup": false,
                      "isEachSide": false,
                      "isAssisted": false,
                      "completedAt": "2026-01-15T12:10:00Z",
                      "isTarget": false
                    }
                  ]
                }
              ]
            }
          ],
          "splitDays": [
            {
              "id": "D4000000-0000-4000-8000-000000000005",
              "name": "UI Day",
              "systemImage": "dumbbell.fill",
              "subtitle": "Synthetic",
              "colorHex": 4169983,
              "includesAllExercises": false,
              "sortOrder": 0
            }
          ],
          "dayPlans": [
            {
              "dayName": "UI Day",
              "exerciseIDs": ["D4000000-0000-4000-8000-000000000001"]
            }
          ]
        }
        """
    }

    static func environment(json: String) -> [String: String] {
        let data = Data(json.utf8)
        return ["ROCKLOG_INJECT_FILE_B64": data.base64EncodedString()]
    }
}
