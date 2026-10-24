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

- `formatVersion` is 1 for files this build writes. Version 2 is the same document plus `unitSystem`, copied from `weightUnit`. Stepping back to 1 keeps `unitSystem`.
- `weightUnit` is `lb` or `kg`. It names the display unit. Every weight number in the payload is still pounds.
- `kind` is `backup`, `coach.session`, `coach.batch`, `program`, or `split`.
- Stable `id` values are UUID strings.
- Keys this version does not know are kept and written back out.

Older files that are not envelopes (a backup with `version` and `exercises`, a `rocklog.coach.session`, a `rocklog.program`, or a `rocklog.split`) are lifted into this envelope. The original object becomes `payload`.

The JSON Schema is `rocklog.interchange.schema.json`. Templates and synthetic samples, rebuilt from the shapes in git history, are in `samples/`. They are not anyone's training log.
