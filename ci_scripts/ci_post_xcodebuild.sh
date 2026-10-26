#!/bin/sh
# After a branch test action, print crash and test-result text from the
# xcresult. Xcode Cloud otherwise reports "Crash: RockLog" with no file.
# Archive on main does not run this. A missing bundle must not fail the job.
set -u

echo "ci_post_xcodebuild: CI_XCODEBUILD_ACTION=${CI_XCODEBUILD_ACTION:-unset} CI_BRANCH=${CI_BRANCH:-unset}"

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
xcrun xcresulttool get test-results summary --path "$BUNDLE" || \
  echo "ci_post_xcodebuild: test-results summary was not available."

echo "ci_post_xcodebuild: test-results tests"
xcrun xcresulttool get test-results tests --path "$BUNDLE" || \
  echo "ci_post_xcodebuild: test-results tests was not available."

# Older Xcode: one JSON blob, which includes crash diagnostics when present.
echo "ci_post_xcodebuild: legacy xcresult JSON"
xcrun xcresulttool get --legacy --path "$BUNDLE" --format json || \
  xcrun xcresulttool get --path "$BUNDLE" --format json || \
  echo "ci_post_xcodebuild: legacy get was not available."

find "$(dirname "$BUNDLE")" -type f \( -name '*.crash' -o -name '*.ips' \) -print 2>/dev/null | while IFS= read -r crash; do
  echo "ci_post_xcodebuild: crash file $crash"
  head -c 200000 "$crash" || true
  echo
done

exit 0
