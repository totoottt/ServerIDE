#!/usr/bin/env bash
set -euo pipefail
# XcodeGen must have generated the project before this script runs.
simulator_id=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
phones = [d for runtime, rows in devices.items() if ".iOS-" in runtime
          for d in rows if d.get("isAvailable") and "iPhone" in d["name"]]
if not phones:
    raise SystemExit("No available iPhone simulator installed on this build machine")
print(phones[0]["udid"])
')
xcodebuild test \
  -project ServerIDE.xcodeproj \
  -scheme ServerIDE \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$simulator_id" \
  -derivedDataPath build/TestDerivedData \
  -resultBundlePath test_results.xcresult \
  CODE_SIGNING_ALLOWED=NO \
  | tee test_simulator.log
