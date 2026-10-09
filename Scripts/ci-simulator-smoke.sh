#!/usr/bin/env bash
# Diagnostic run on iPad Pro 12.9-inch (prefer 3rd generation), landscape + dark.
# Works on macOS runners using an unpacked *test-only* .app copy.
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

echo "AeroUchet simulator smoke: 12.9-inch landscape, system dark mode"
echo "PRECHECK" > "$RESULTS/status.txt"
test -f "$ARCHIVE"
xcodebuild -version
xcrun simctl list devices available -j > "$RESULTS/available-devices.json"
xcrun simctl list devicetypes -j > "$RESULTS/available-device-types.json"

# The user's 12.9-inch iPad Pro bought in 2019 is closest to the 3rd generation.
# Prefer that exact device type, creating a simulator when the runner only has
# newer devices pre-created. Do not silently substitute a 13-inch iPad.
DEVICE_ID="$(python3 - "$RESULTS/available-devices.json" "$RESULTS/available-device-types.json" <<'PY'
import json
import re
import subprocess
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    devices = json.load(stream).get("devices", {})
with open(sys.argv[2], encoding="utf-8") as stream:
    types = json.load(stream).get("devicetypes", [])

runtimes = []
for runtime in devices:
    match = re.search(r"\.iOS-(\d+)(?:-(\d+))?", runtime)
    if match and int(match.group(1)) >= 26:
        runtimes.append(((int(match.group(1)), int(match.group(2) or 0)), runtime))
if not runtimes:
    sys.exit("No installed iOS 26+ runtime")
runtimes.sort(reverse=True)

def twelve_nine(name):
    return "iPad" in name and re.search(r"12[.,]9", name) is not None

def third_gen(name):
    return re.search(r"(?:3rd|third)\s+generation", name, re.I) is not None

all_existing = []
for _, runtime in runtimes:
    for item in devices.get(runtime, []):
        if item.get("isAvailable") is False or not twelve_nine(item.get("name", "")):
            continue
        all_existing.append((item, runtime))

exact = [(item, runtime) for item, runtime in all_existing if third_gen(item["name"])]
if exact:
    item, runtime = exact[0]
    print(f"Exact 12.9-inch 3rd-generation device: {item['name']} ({runtime})", file=sys.stderr)
    print(item["udid"])
    sys.exit(0)

# Create a 3rd-gen 12.9-inch model under the available iOS runtime if possible.
matching_types = [item for item in types if twelve_nine(item.get("name", ""))]
matching_types.sort(key=lambda item: (
    not third_gen(item.get("name", "")),
    item.get("name", "")
))
for item in matching_types:
    for _, runtime in runtimes:
        command = [
            "xcrun", "simctl", "create",
            "AeroUchet iPad Pro 12.9 CI", item["identifier"], runtime
        ]
        outcome = subprocess.run(command, capture_output=True, text=True)
        if outcome.returncode == 0 and outcome.stdout.strip():
            print(f"Created device type {item['name']} on {runtime}", file=sys.stderr)
            print(outcome.stdout.strip())
            sys.exit(0)
        print(f"Cannot create {item['name']} on {runtime}: {outcome.stderr.strip()[:250]}", file=sys.stderr)

# A runner with a ready-made 12.9-inch model is acceptable as a close fallback.
if all_existing:
    item, runtime = all_existing[0]
    print(f"WARNING: closest available 12.9-inch model: {item['name']} ({runtime})", file=sys.stderr)
    print(item["udid"])
    sys.exit(0)

sys.exit("No compatible 12.9-inch iPad Pro Simulator; refusing to switch to 13-inch")
PY
)"
echo "Selected simulator UUID: $DEVICE_ID"
xcrun simctl list devices | grep -F "$DEVICE_ID" || true

xcrun simctl boot "$DEVICE_ID"
xcrun simctl bootstatus "$DEVICE_ID" -b
echo "BOOTED" > "$RESULTS/status.txt"

# System appearance (independent from any in-app tint or custom blur).
xcrun simctl ui "$DEVICE_ID" appearance dark
APPEARANCE="$(xcrun simctl ui "$DEVICE_ID" appearance)"
echo "Simulator appearance: $APPEARANCE"
if ! printf '%s' "$APPEARANCE" | grep -qi dark; then
  echo "Cannot verify dark system appearance" >&2
  echo "DARK_MODE_FAILED" > "$RESULTS/status.txt"
  exit 1
fi
echo "DARK_MODE" > "$RESULTS/status.txt"

UNPACKED="$RUNNER_TEMP/aerouchet-smoke-unpacked"
mkdir -p "$UNPACKED"
unzip -q "$ARCHIVE" -d "$UNPACKED"
APP_PATH="$(find "$UNPACKED" -type d -name '*.app' -print -quit)"
if [ -z "$APP_PATH" ]; then
  echo "No .app bundle inside archive" >&2
  exit 1
fi

# The Playgrounds CI bundles an executable manually. Restrict ONLY this extracted
# test copy to landscape. The shipped app, source code and original ZIP are unchanged.
PLIST="$APP_PATH/Info.plist"
test -f "$PLIST"
for key in UISupportedInterfaceOrientations UISupportedInterfaceOrientations~ipad UIRequiresFullScreen; do
  /usr/libexec/PlistBuddy -c "Delete :$key" "$PLIST" 2>/dev/null || true
done
/usr/libexec/PlistBuddy -c "Add :UIRequiresFullScreen bool true" "$PLIST"
for key in UISupportedInterfaceOrientations UISupportedInterfaceOrientations~ipad; do
  /usr/libexec/PlistBuddy -c "Add :$key array" "$PLIST"
  /usr/libexec/PlistBuddy -c "Add :$key:0 string UIInterfaceOrientationLandscapeLeft" "$PLIST"
  /usr/libexec/PlistBuddy -c "Add :$key:1 string UIInterfaceOrientationLandscapeRight" "$PLIST"
done
plutil -lint "$PLIST"
echo "Landscape-only orientations set on extracted diagnostic app bundle"

BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw -o - "$PLIST")"
echo "Installing: $APP_PATH"
xcrun simctl install "$DEVICE_ID" "$APP_PATH"
echo "INSTALLED" > "$RESULTS/status.txt"

xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID"
echo "LAUNCHED" > "$RESULTS/status.txt"
sleep 8

# simctl has no supported rotate subcommand. Try the same Device > Rotate
# menu that a developer uses in Simulator.app. On locked-down hosted runners,
# macOS may deny AppleScript accessibility; that failure is logged explicitly.
echo "Requesting landscape orientation from Simulator.app"
open -a Simulator --args -CurrentDeviceUDID "$DEVICE_ID" || true
sleep 5
if osascript <<'APPLESCRIPT'
tell application "Simulator" to activate
tell application "System Events"
  tell application process "Simulator"
    click menu item "Rotate Right" of menu 1 of menu bar item "Device" of menu bar 1
  end tell
end tell
APPLESCRIPT
then
  echo "Simulator Device > Rotate Right requested"
else
  echo "WARN: simulator GUI rotation failed (possibly macOS accessibility restrictions)"
fi
sleep 4

xcrun simctl io "$DEVICE_ID" screenshot "$RESULTS/main-screen.png"
echo "SCREENSHOT" > "$RESULTS/status.txt"

# Verify the native 12.9-inch pixel geometry AND landscape. A portrait screenshot
# is a failed requirement even if simctl launch and screenshot returned success.
python3 - "$RESULTS/main-screen.png" "$RESULTS/screenshot-profile.json" "$APPEARANCE" <<'PY'
import json
import struct
import sys

image, metadata, appearance = sys.argv[1:]
with open(image, "rb") as stream:
    header = stream.read(24)
if header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
    raise SystemExit("Invalid PNG screenshot")
width, height = struct.unpack(">II", header[16:24])
profile = {
    "target": "iPad Pro 12.9-inch (2019 purchase; prefer 3rd generation)",
    "systemAppearance": appearance.strip(),
    "orientation": "landscape" if width > height else "portrait",
    "imageWidth": width,
    "imageHeight": height,
    "expectedLandscapePixels": [2732, 2048],
}
with open(metadata, "w", encoding="utf-8") as stream:
    json.dump(profile, stream, indent=2, ensure_ascii=False)
print("Screenshot dimensions:", width, "x", height)
if (width, height) != (2732, 2048):
    raise SystemExit("PROFILE_MISMATCH: expected 2732x2048 native 12.9-inch landscape PNG")
PY

if ! xcrun simctl spawn "$DEVICE_ID" launchctl list | grep -F "$BUNDLE_ID"; then
  echo "Application service disappeared before profile verification" >&2
  echo "APP_EXITED" > "$RESULTS/status.txt"
  exit 1
fi

echo "PASS" > "$RESULTS/status.txt"
echo "PASS: iPad 12.9-inch 2732x2048 landscape + verified dark appearance"
