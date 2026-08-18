# RockLog Coach — Path 1 (recovered)

**Recovered:** 2026-08-17 from Grok 4.5 session `019fd3e9` (cwd was `/Users/lee`, not this repo).  
**Source date:** 2026-08-12.  
**Code started:** 2026-08-17 — schema locked, RockLog export/share, RockCoach Path 1 scaffold.

Resume: *Continue RockCoach Path 1 from `docs/coaching-companion/PATH-1.md`.*

---

## Freeze (year one)

| # | Decision |
|---|----------|
| 1 | **RockLog** = athlete logging only |
| 2 | **RockLog Coach** = separate review companion |
| 3 | Shared backend later; **import OK as backup**. Path 1 = **no backend** |
| 4 | Shared format: **`rocklog.coach.session` v1** |
| 5 | Coach **read-only first**; **assign workouts later** |
| 6 | **No tonnage** in the product (raw sets / reps / progression only) |

Scale: designed for ≤10, optimized for **5–6** unrelated clients. Sync: **async**, same/next day — not live.

Do not re-debate companion vs one app, tonnage, or live sync unless something forces a rethink.

---

## The three roles

| Piece | Who | Job |
|--------|-----|-----|
| **RockLog** | Client | Log workouts (what exists now) |
| **RockLog Coach** | You | Roster → sessions → sets/reps → progression |
| **Shared store** | Neither uses as an app | Only needed so your phone can see *their* iCloud-private data |

Client RockLog lives in **their** iCloud. Coach cannot read that. Files or a later backend are the only paths.

```
Client phone                         Shared middle                    Your phone
RockLog  ──writes workouts──►  (files now / avahost later)  ──reads──►  Coach
```

---

## Path 1 (locked)

| Piece | Year-one start |
|--------|----------------|
| **RockLog** | Log as today + **export coach JSON** + share |
| **RockLog Coach** | New app: import/view sessions, history, progression (**read-only**) |
| **Backend** | **Not required** |

**Client UX after Finish** (Settings: “Share session with coach”):

1. Build `rocklog.coach.session` JSON  
2. Temp file e.g. `Lee-Pull-2026-08-11.rocklogcoach`  
3. System **Share sheet**  
4. Messages / Mail / Files / AirDrop  
5. You: **Coach → Import** (or open the file with Coach)

Do **not** paste JSON into SMS. Attachment only.

**avahost.com:** fine as Path 1.5 auto-drop (`HTTPS POST` + token). Not needed for Path 1. Static hosting alone still means Share/Files.

```
Path 1 (now)
  RockLog ──Finish──► Share sheet ──Messages/Mail/Files──► Import──► Coach

Path 1.5
  RockLog ──Finish──► HTTPS POST ──► avahost.com ──► Coach list/fetch

Path 2
  Link coach + roster; same JSON; assign workouts later
```

---

## Build order

1. **Freeze schema** — `rocklog.coach.session` v1 (sets, reps, no tonnage)  
2. **RockLog** — Export for coach + optional share-after-finish  
3. **Coach app** — import file, client folder (manual name), session list, set detail, simple progression  
4. **Later** — avahost upload + Coach refresh  

Shared Swift library for the JSON type is fine; do not duplicate a second progression engine forever.

---

## Schema (`rocklog.coach.session` v1) — locked

Formal JSON Schema: `docs/coaching-companion/rocklog.coach.session.v1.schema.json`  
Shared Swift: `Shared/CoachFormat/CoachSessionDocument.swift` + `CoachProgression.swift`

- One workout = `rocklog.coach.session` v1 (`.rocklogcoach`, UTI `com.lee.rocklog.coach.session`)
- Two or more unsent workouts = sibling format `rocklog.coach.batch` v1 (same extension). Session objects are unchanged.
- Athlete display name + stable UUID (not an Apple ID)
- Session date, day type, rotation track, notes, effort
- Exercises: name, muscle, mode, notes
- Sets: weight, reps, side, assist, warmup, completedAt
- **No tonnage / volume totals**
- `schemaVersion` 1 — Coach rejects unknown majors

Do not add fields to `rocklog.coach.session` without bumping that schema. Batch is a new format name, not a session v2.

## Path 1 status (2026-08-17)

| Piece | Where |
|--------|--------|
| Schema + codec | `Shared/CoachFormat/` — session v1 unchanged; batch v1 envelope |
| RockLog export | This workout **or** since last share (unsent completed IDs). 1 → session file; 2+ → batch |
| Share-after-finish | Settings toggle → share **this** workout |
| RockCoach app | target **RockCoach** · bundle `com.lee.rockcoach` · local SwiftData roster |
| Not started | avahost Path 1.5, assign workouts, App Store listing |

---

## Privacy

Messages threads keep the file as long as the chat. Fine for Path 1 with people you trust. Later: HTTPS + token on avahost beats long-lived chat history.
