#!/bin/sh
# After a branch test action, print crash and test-result text from the
# xcresult. Xcode Cloud otherwise reports "Crash: RockLog" with no file.
# Archive and main still skip. A test action fails when the bundle is
# missing, the suite ran zero tests, or the count is under the RockLogTests floor.
set -u

ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}"

is_test_action() {
  case "${CI_XCODEBUILD_ACTION:-}" in
    test|test-without-building) return 0 ;;
    *) return 1 ;;
  esac
}

unit_test_floor() {
  if [ -n "${CI_EXPECTED_TEST_COUNT:-}" ]; then
    printf '%s\n' "$CI_EXPECTED_TEST_COUNT"
    return
  fi
  # test-without-building runs on a host where $ROOT may not hold the sources
  # (Build 78: floor 0). Try the script's own checkout, then the committed floor.
  script_root=$(CDPATH= cd -- "$(dirname "$0")/.." 2>/dev/null && pwd)
  for dir in "$ROOT/RockLogTests" "$script_root/RockLogTests"; do
    [ -d "$dir" ] || continue
    count=$(grep -R --include='*.swift' -h -E '^[[:space:]]*func test_' "$dir" 2>/dev/null | grep -c . || true)
    if [ "${count:-0}" -gt 0 ]; then printf '%s\n' "$count"; return; fi
  done
  committed="$(dirname "$0")/unit_test_floor.txt"
  if [ -f "$committed" ]; then
    echo "ci_post_xcodebuild: RockLogTests sources not found; using committed floor" >&2
    tr -dc '0-9' < "$committed"; echo; return
  fi
  printf '0\n'
}

echo "ci_post_xcodebuild: CI_XCODEBUILD_ACTION=${CI_XCODEBUILD_ACTION:-unset} CI_BRANCH=${CI_BRANCH:-unset} CI_WORKFLOW=${CI_WORKFLOW:-unset}"

# xcresulttool can sit on a large result bundle until Xcode Cloud kills the
# action. Bound every call. python3 is already used by ci_pre_xcodebuild.
run_xcresulttool() {
  _seconds="$1"
  shift
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$_seconds" "$@" << 'PY'
import subprocess, sys
seconds = float(sys.argv[1])
cmd = sys.argv[2:]
try:
    completed = subprocess.run(cmd, timeout=seconds)
except subprocess.TimeoutExpired:
    print(
        "ci_post_xcodebuild: timed out after %ss: %s" % (sys.argv[1], " ".join(cmd)),
        flush=True,
    )
    sys.exit(124)
sys.exit(completed.returncode)
PY
  else
    echo "ci_post_xcodebuild: python3 is missing; running without a timeout."
    "$@"
  fi
}

if [ "${CI_BRANCH:-}" = "main" ]; then
  echo "ci_post_xcodebuild: main archive is unchanged. Skipping the crash log."
  exit 0
fi

case "${CI_XCODEBUILD_ACTION:-}" in
  archive|build-for-archive|export)
    echo "ci_post_xcodebuild: no test result for this action."
    exit 0
    ;;
esac

BUNDLE="${CI_RESULT_BUNDLE_PATH:-}"
if [ -z "$BUNDLE" ] || [ ! -d "$BUNDLE" ]; then
  if [ -n "${CI_DERIVED_DATA_PATH:-}" ] && [ -d "${CI_DERIVED_DATA_PATH}" ]; then
    BUNDLE=$(find "${CI_DERIVED_DATA_PATH}" -name '*.xcresult' -type d -print -quit 2>/dev/null || true)
  fi
fi

if [ -z "${BUNDLE:-}" ] || [ ! -d "$BUNDLE" ]; then
  echo "ci_post_xcodebuild: no result bundle (CI_RESULT_BUNDLE_PATH=${CI_RESULT_BUNDLE_PATH:-unset})."
  if is_test_action; then
    echo "ci_post_xcodebuild: a test action needs an xcresult. Failing."
    exit 1
  fi
  echo "ci_post_xcodebuild: this action does not run tests. Skipping the crash log."
  exit 0
fi

echo "ci_post_xcodebuild: result bundle $BUNDLE"

if ! command -v xcrun >/dev/null 2>&1; then
  echo "ci_post_xcodebuild: xcrun is not on PATH."
  if is_test_action; then
    echo "ci_post_xcodebuild: cannot read the test count without xcrun. Failing."
    exit 1
  fi
  echo "ci_post_xcodebuild: Skipping the crash log."
  exit 0
fi

SUMMARY_FILE=$(mktemp)
echo "ci_post_xcodebuild: test-results summary"
set -o pipefail
if run_xcresulttool 180 xcrun xcresulttool get test-results summary --path "$BUNDLE" | tee "$SUMMARY_FILE"; then
  SUMMARY_READ=1
else
  SUMMARY_READ=0
  echo "ci_post_xcodebuild: test-results summary was not available."
fi
set +o pipefail

echo "ci_post_xcodebuild: test-results tests"
run_xcresulttool 180 xcrun xcresulttool get test-results tests --path "$BUNDLE" || \
  echo "ci_post_xcodebuild: test-results tests was not available."

# The full legacy blob is what hung Evidence after a multi-hour result.
# Branch Test still prints it, under the same timeout.
if [ "${CI_WORKFLOW:-}" = "RockLog Evidence" ]; then
  echo "ci_post_xcodebuild: skipping legacy xcresult JSON for workflow RockLog Evidence."
else
  echo "ci_post_xcodebuild: legacy xcresult JSON"
  run_xcresulttool 180 xcrun xcresulttool get --legacy --path "$BUNDLE" --format json || \
    run_xcresulttool 180 xcrun xcresulttool get --path "$BUNDLE" --format json || \
    echo "ci_post_xcodebuild: legacy get was not available."
fi

find "$(dirname "$BUNDLE")" -type f \( -name '*.crash' -o -name '*.ips' \) -print 2>/dev/null | while IFS= read -r crash; do
  echo "ci_post_xcodebuild: crash file $crash"
  head -c 200000 "$crash" || true
  echo
done

if ! is_test_action; then
  rm -f "$SUMMARY_FILE"
  exit 0
fi

if [ "$SUMMARY_READ" != "1" ]; then
  echo "ci_post_xcodebuild: refusing a test action with no readable summary."
  rm -f "$SUMMARY_FILE"
  exit 1
fi

FLOOR=$(unit_test_floor)
echo "ci_post_xcodebuild: unit-test floor ${FLOOR} (override with CI_EXPECTED_TEST_COUNT)"
python3 - "$SUMMARY_FILE" "$FLOOR" << 'PY'
import json, sys
raw = open(sys.argv[1], encoding="utf-8", errors="replace").read()
start = raw.find("{")
end = raw.rfind("}")
if start < 0 or end < start:
    print("ci_post_xcodebuild: summary was not JSON.", flush=True)
    sys.exit(1)
summary = json.loads(raw[start:end + 1])
count = summary.get("totalTestCount")
if not isinstance(count, int):
    print("ci_post_xcodebuild: summary has no totalTestCount.", flush=True)
    sys.exit(1)
floor = int(sys.argv[2])
print("ci_post_xcodebuild: totalTestCount %s floor %s" % (count, floor), flush=True)
if floor <= 0:
    print("ci_post_xcodebuild: unit-test floor is 0. Check RockLogTests or set CI_EXPECTED_TEST_COUNT.", flush=True)
    sys.exit(1)
if count <= 0 or count < floor:
    print("ci_post_xcodebuild: test count is missing or below the floor.", flush=True)
    sys.exit(1)
PY
status=$?
rm -f "$SUMMARY_FILE"
exit "$status"
