#!/bin/sh
# Xcode Cloud used to stamp CI_BUILD_NUMBER (stuck on 11 after we hand-uploaded
# TestFlight 12). App Store then rejected: "bundle version must be higher".
# Pin only RockLog (com.lee.lift2026) to max(14, Cloud incrementer).
# Leave RockCoach and the share extension at 1.
# RockCoach is in this GitHub repo for local Xcode; it is not a TestFlight product.
set -eu

if [ "${CI_XCODE_SCHEME:-}" = "RockCoach" ]; then
  echo "ci_pre_xcodebuild: scheme RockCoach is GitHub/local only — not TestFlight. Failing this Cloud job."
  exit 1
fi

ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}"
PBX="$ROOT/strength-training.xcodeproj/project.pbxproj"
MIN=14
CLOUD="${CI_BUILD_NUMBER:-0}"

if [ "$CLOUD" -ge "$MIN" ] 2>/dev/null; then
  VER="$CLOUD"
else
  VER="$MIN"
fi

echo "ci_pre_xcodebuild: pinning RockLog CURRENT_PROJECT_VERSION to $VER (Cloud was ${CI_BUILD_NUMBER:-unset})"

python3 - "$PBX" "$VER" << 'PY'
import pathlib, re, sys

path = pathlib.Path(sys.argv[1])
ver = sys.argv[2]
text = path.read_text()
# Each XCBuildConfiguration block. Only rewrite the RockLog app.
block = re.compile(
    r"/\* Debug \*/ = \{.*?isa = XCBuildConfiguration;.*?buildSettings = \{.*?\n\t\t\t\};",
    re.S,
)
# Simpler: split on isa = XCBuildConfiguration and patch blocks that contain lift2026.
parts = re.split(r"(isa = XCBuildConfiguration;)", text)
out = [parts[0]]
updated = 0
for i in range(1, len(parts), 2):
    head = parts[i]
    body = parts[i + 1] if i + 1 < len(parts) else ""
    chunk = head + body
    if "PRODUCT_BUNDLE_IDENTIFIER = com.lee.lift2026;" in chunk:
        new_chunk, n = re.subn(
            r"CURRENT_PROJECT_VERSION = \d+;",
            f"CURRENT_PROJECT_VERSION = {ver};",
            chunk,
            count=1,
        )
        if n != 1:
            raise SystemExit("RockLog config missing CURRENT_PROJECT_VERSION")
        chunk = new_chunk
        updated += 1
    out.append(chunk)
if updated != 2:
    raise SystemExit(f"expected to pin 2 RockLog configs, updated {updated}")
path.write_text("".join(out))
print(f"updated {updated} RockLog build configurations")
PY
