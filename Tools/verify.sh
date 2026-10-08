#!/bin/bash
set -euo pipefail
review_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$review_root"
review_temp="$(mktemp -d /tmp/fitswift-checks.XXXXXX)"
trap 'rm -rf "$review_temp"' EXIT

python3 Tools/check_secrets.py
python3 Tools/check_local_only.py
"${NODE_BIN:-node}" --test Backend/gateway.test.mjs

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
xcrun --sdk macosx swiftc -module-cache-path "$review_temp/modules" \
    FitnessApp/Models/User.swift FitnessApp/Models/WorkoutRecord.swift \
    FitnessApp/Models/UserManager.swift FitnessApp/Models/FitnessMetrics.swift \
    FitnessApp/Models/Achievement.swift Tools/RegressionChecks.swift \
    -o "$review_temp/regressions"
"$review_temp/regressions"
xcodebuild -scheme FitnessApp -configuration Release -destination 'generic/platform=iOS' \
    -derivedDataPath "$review_temp/release" CODE_SIGNING_ALLOWED=NO build
python3 Tools/check_local_only.py --app-bundle "$review_temp/release/Build/Products/Release-iphoneos/FitnessApp.app"
# Simulator runtime and physical-device tests are separate from this check.
