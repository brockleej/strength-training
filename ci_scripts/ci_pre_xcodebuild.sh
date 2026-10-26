#!/bin/sh
# Xcode Cloud used to stamp CI_BUILD_NUMBER (stuck on 11 after we hand-uploaded
# TestFlight 12). App Store then rejected: "bundle version must be higher".
# Pin RockLog (com.lee.lift2026) to max(17, Cloud incrementer).
# Pin the Live Activity widget (com.lee.lift2026.restwidget) to that same
# build number, and copy the app's MARKETING_VERSION onto it (ITMS-90473).
# Leave RockCoach and the share extension at 1.
# RockCoach is in this GitHub repo for local Xcode; it is not a TestFlight product.
set -eu

if [ "${CI_XCODE_SCHEME:-}" = "RockCoach" ]; then
  echo "ci_pre_xcodebuild: scheme RockCoach is GitHub/local only — not TestFlight. Failing this Cloud job."
  exit 1
fi

ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}"
ROCKLOG_PBX="$ROOT/RockLog.xcodeproj/project.pbxproj"
LEGACY_PBX="$ROOT/strength-training.xcodeproj/project.pbxproj"
# Build Tests already pinned versions. The later "test-without-building"
# action does not have the project file, and versions are unused then.
if [ "${CI_XCODEBUILD_ACTION:-}" = "test-without-building" ] || { [ ! -f "$ROCKLOG_PBX" ] && [ ! -f "$LEGACY_PBX" ]; }; then
  echo "ci_pre_xcodebuild: skipping version pin (action=${CI_XCODEBUILD_ACTION:-unset}). Not a build or archive."
  exit 0
fi
if [ -f "$ROCKLOG_PBX" ]; then
  PBX="$ROCKLOG_PBX"
else
  PBX="$LEGACY_PBX"
fi
MIN=17
CLOUD="${CI_BUILD_NUMBER:-0}"

if [ "$CLOUD" -ge "$MIN" ] 2>/dev/null; then
  VER="$CLOUD"
else
  VER="$MIN"
fi

echo "ci_pre_xcodebuild: pinning RockLog and rest widget CURRENT_PROJECT_VERSION to $VER (Cloud was ${CI_BUILD_NUMBER:-unset})"

python3 - "$PBX" "$VER" << 'PY'
import pathlib, re, sys

path = pathlib.Path(sys.argv[1])
ver = sys.argv[2]
text = path.read_text()
app_bundle = "PRODUCT_BUNDLE_IDENTIFIER = com.lee.lift2026;"
widget_bundle = "PRODUCT_BUNDLE_IDENTIFIER = com.lee.lift2026.restwidget;"
# Simpler: split on isa = XCBuildConfiguration and patch those blocks.
parts = re.split(r"(isa = XCBuildConfiguration;)", text)
chunks = []
for i in range(1, len(parts), 2):
    body = parts[i + 1] if i + 1 < len(parts) else ""
    chunks.append(parts[i] + body)

marketing_versions = []
for chunk in chunks:
    if app_bundle in chunk:
        match = re.search(r"MARKETING_VERSION = ([^;]+);", chunk)
        if not match:
            raise SystemExit("RockLog config missing MARKETING_VERSION")
        marketing_versions.append(match.group(1).strip())
if len(marketing_versions) != 2 or len(set(marketing_versions)) != 1:
    raise SystemExit(
        f"expected 2 RockLog configs with one MARKETING_VERSION, found {marketing_versions}"
    )
marketing = marketing_versions[0]

out = [parts[0]]
updated = 0
widget_updated = 0
for chunk in chunks:
    if app_bundle in chunk:
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
    elif widget_bundle in chunk:
        new_chunk, n = re.subn(
            r"CURRENT_PROJECT_VERSION = \d+;",
            f"CURRENT_PROJECT_VERSION = {ver};",
            chunk,
            count=1,
        )
        if n != 1:
            raise SystemExit("rest widget config missing CURRENT_PROJECT_VERSION")
        new_chunk, n = re.subn(
            r"MARKETING_VERSION = [^;]+;",
            f"MARKETING_VERSION = {marketing};",
            new_chunk,
            count=1,
        )
        if n != 1:
            raise SystemExit("rest widget config missing MARKETING_VERSION")
        chunk = new_chunk
        widget_updated += 1
    out.append(chunk)
if updated != 2:
    raise SystemExit(f"expected to pin 2 RockLog configs, updated {updated}")
if widget_updated != 2:
    raise SystemExit(f"expected to pin 2 rest widget configs, updated {widget_updated}")
path.write_text("".join(out))
print(f"updated {updated} RockLog build configurations")
print(f"updated {widget_updated} rest widget build configurations to {ver} / {marketing}")
PY
