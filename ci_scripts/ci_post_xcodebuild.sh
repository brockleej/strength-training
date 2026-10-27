#!/bin/sh
# After a branch test action, print crash and test-result text from the
# xcresult. Xcode Cloud otherwise reports "Crash: RockLog" with no file.
# Archive on main does not run this. A missing bundle must not fail the job.
set -u

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
  echo "ci_post_xcodebuild: no result bundle (CI_RESULT_BUNDLE_PATH=${CI_RESULT_BUNDLE_PATH:-unset}). Skipping the crash log."
  exit 0
fi

echo "ci_post_xcodebuild: result bundle $BUNDLE"

if ! command -v xcrun >/dev/null 2>&1; then
  echo "ci_post_xcodebuild: xcrun is not on PATH. Skipping the crash log."
  exit 0
fi

echo "ci_post_xcodebuild: test-results summary"
run_xcresulttool 180 xcrun xcresulttool get test-results summary --path "$BUNDLE" || \
  echo "ci_post_xcodebuild: test-results summary was not available."

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

exit 0
