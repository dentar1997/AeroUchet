#!/usr/bin/env bash
# Experimental smoke test for the Swift Playgrounds simulator bundle.
# Run on macOS with Xcode and an installed iOS 26+ iPad simulator.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <AeroUchet-Simulator.zip> <results-dir>" >&2
  exit 2
fi

ARCHIVE="$1"
RESULTS="$2"
mkdir -p "$RESULTS"
exec > >(tee "$RESULTS/smoke.log") 2>&1

DEVICE_ID=""
cleanup() {
  local result="$?"
  echo "Smoke script exit code: $result"
  if [ -n "$DEVICE_ID" ]; then
    xcrun simctl shutdown "$DEVICE_ID" || true
  fi
}
trap cleanup EXIT

echo "Starting AeroUchet simulator smoke test"
echo "PRECHECK" > "$RESULTS/status.txt"
test -f "$ARCHIVE"
xcodebuild -version
xcrun simctl list devices available -j > "$RESULTS/available-devices.json"

DEVICE_ID="$(python3 - "$RESULTS/available-devices.json" <<'PY'
import json
import re
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    devices_by_runtime = json.load(handle).get("devices", {})

candidates = []
for runtime, devices in devices_by_runtime.items():
    match = re.search(r"\.iOS-(\d+)(?:-(\d+))?", runtime)
    if not match or int(match.group(1)) < 26:
        continue
    for device in devices:
        if "iPad" not in device.get("name", ""):
            continue
        if device.get("isAvailable") is False:
            continue
        priority = ("Pro" in device["name"], int(match.group(1)), int(match.group(2) or 0))
        candidates.append((priority, device["udid"], device["name"], runtime))

if not candidates:
    sys.exit("No available iPad Simulator with iOS 26 or later")

_, udid, name, runtime = max(candidates)
print(udid)
print(f"Selected {name} ({runtime})", file=sys.stderr)
PY
)"

echo "Selected device: $DEVICE_ID"
xcrun simctl boot "$DEVICE_ID"
xcrun simctl bootstatus "$DEVICE_ID" -b
echo "BOOTED" > "$RESULTS/status.txt"

UNPACKED="$RUNNER_TEMP/aerouchet-smoke-unpacked"
mkdir -p "$UNPACKED"
unzip -q "$ARCHIVE" -d "$UNPACKED"
APP_PATH="$(find "$UNPACKED" -type d -name '*.app' -print -quit)"
if [ -z "$APP_PATH" ]; then
  echo "No .app bundle inside archive" >&2
  exit 1
fi

BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw -o - "$APP_PATH/Info.plist")"
echo "Installing app bundle: $APP_PATH"
echo "Bundle identifier: $BUNDLE_ID"
xcrun simctl install "$DEVICE_ID" "$APP_PATH"
echo "INSTALLED" > "$RESULTS/status.txt"

xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID"
echo "LAUNCHED" > "$RESULTS/status.txt"
sleep 5

xcrun simctl io "$DEVICE_ID" screenshot "$RESULTS/main-screen.png"
echo "SCREENSHOT" > "$RESULTS/status.txt"

# Screenshot capture alone can succeed after an application crashes.
# Also verify that its launchd service is still registered.
if ! xcrun simctl spawn "$DEVICE_ID" launchctl list | grep -F "$BUNDLE_ID"; then
  echo "Application service not found after launch; screenshot may show SpringBoard" >&2
  exit 1
fi

echo "PASS" > "$RESULTS/status.txt"
echo "PASS: application is running and main-screen.png was captured"
