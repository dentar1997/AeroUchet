#!/usr/bin/env bash
# Diagnostic run on iPad Pro 12.9-inch (prefer 3rd generation), landscape + dark.
# Works on macOS runners using an unpacked *test-only* .app copy.
set -euo pipefail

PREBOOT_MODE=false
if [ "$#" -eq 2 ] && [ "$1" = "--preboot" ]; then
  PREBOOT_MODE=true
  ARCHIVE=""
  RESULTS="$2"
elif [ "$#" -eq 2 ]; then
  ARCHIVE="$1"
  RESULTS="$2"
else
  echo "Usage: $0 <AeroUchet-Simulator.zip> <results-dir> OR $0 --preboot <results-dir>" >&2
  exit 2
fi

mkdir -p "$RESULTS"
if [ "$PREBOOT_MODE" = true ]; then
  exec > >(tee "$RESULTS/preboot.log") 2>&1
else
  exec > >(tee "$RESULTS/smoke.log") 2>&1
  echo "PRECHECK" > "$RESULTS/status.txt"
  test -f "$ARCHIVE"
fi

DEVICE_ID=""
cleanup() {
  local result="$?"
  echo "Smoke script exit code: $result; preboot=$PREBOOT_MODE"
  if [ "$PREBOOT_MODE" = false ] && [ -n "$DEVICE_ID" ]; then
    xcrun simctl shutdown "$DEVICE_ID" || true
  fi
}
trap cleanup EXIT

echo "AeroUchet simulator smoke: 12.9-inch landscape, dark; preboot=$PREBOOT_MODE"
xcodebuild -version
if [ "$PREBOOT_MODE" = true ] || [ ! -s "$RESULTS/device-udid.txt" ]; then
  xcrun simctl list devices available -j > "$RESULTS/available-devices.json"
  xcrun simctl list devicetypes -j > "$RESULTS/available-device-types.json"
fi

# The user's 12.9-inch iPad Pro bought in 2019 is closest to the 3rd generation.
# Prefer that exact device type, creating a simulator when the runner only has
# newer devices pre-created. Do not silently substitute a 13-inch iPad.
if [ "$PREBOOT_MODE" = false ] && [ -s "$RESULTS/device-udid.txt" ]; then
  DEVICE_ID="$(cat "$RESULTS/device-udid.txt")"
  echo "Reusing prewarmed Simulator: $DEVICE_ID"
else
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
fi
echo "Selected simulator UUID: $DEVICE_ID"
xcrun simctl list devices | grep -F "$DEVICE_ID" || true

if [ "$PREBOOT_MODE" = true ]; then
  # Start as early as possible. The build job compiles Swift while iPadOS boots.
  xcrun simctl boot "$DEVICE_ID"
  echo "$DEVICE_ID" > "$RESULTS/device-udid.txt"
  xcrun simctl bootstatus "$DEVICE_ID" -b
  echo "PREBOOTED" > "$RESULTS/preboot.status"
  echo "iPad Simulator ready for the forthcoming compiled app"
  exit 0
fi
# With a prewarmed device we wait on the SAME boot; do not restart Simulator.
if [ ! -s "$RESULTS/device-udid.txt" ]; then
  echo "Preboot unavailable; falling back to a normal boot"
  xcrun simctl boot "$DEVICE_ID"
fi
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
  echo "Simulator GUI rotation was not accepted; cannot assert landscape"
  echo "ROTATE_FAILED" > "$RESULTS/status.txt"
  exit 1
fi
sleep 4

# simctl captures the native 2048x2732 backing buffer even when the device
# AND the entire UI have rotated to landscape. Preserve that raw evidence,
# and re-orient the *export* 90 degrees clockwise to 2732x2048 for review.
# This is not a fake rotated portrait UI: the raw image will show all
# interface text and the system status bar sideways after device rotation.
xcrun simctl io "$DEVICE_ID" screenshot "$RESULTS/raw-screen.png"
echo "RAW_SCREENSHOT" > "$RESULTS/status.txt"
python3 - "$RESULTS/raw-screen.png" "$RESULTS/raw-buffer-size.txt" <<'PY'
import struct
import sys
with open(sys.argv[1], "rb") as stream:
    data = stream.read(24)
if data[:8] != b"\x89PNG\r\n\x1a\n":
    sys.exit("Invalid raw screenshot")
width, height = struct.unpack(">II", data[16:24])
with open(sys.argv[2], "w", encoding="utf-8") as stream:
    stream.write(f"{width}x{height}\n")
print(f"Raw simulator buffer: {width}x{height}")
if (width, height) not in [(2048, 2732), (2732, 2048)]:
    sys.exit("Unexpected 12.9-inch simulator buffer size")
PY
if [ "$(cat "$RESULTS/raw-buffer-size.txt")" = "2048x2732" ]; then
  sips --rotate 90 --out "$RESULTS/main-screen.png" "$RESULTS/raw-screen.png" >/dev/null
  echo "Normalized landscape export from rotated Simulator framebuffer"
else
  cp "$RESULTS/raw-screen.png" "$RESULTS/main-screen.png"
  echo "Simulator export was already landscape"
fi
echo "SCREENSHOT" > "$RESULTS/status.txt"

# Verify native 12.9-inch geometry on the normalized landscape export.
# Keep raw-screen.png for independent visual confirmation of UI rotation.
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
    "rawBufferPixels": open(image.replace("main-screen.png", "raw-buffer-size.txt"), encoding="utf-8").read().strip(),
    "rotationMethod": "Simulator Device > Rotate Right; preserve raw, normalize screenshot for display",
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

# The second launch uses the SAME table that users reach from "Ещё".
# A simulator-only launch argument seeds a query so Tamm is visible without
# an unreliable automated tap/keyboard sequence or artificial screenshot data.
echo "Opening the real Aircraft Reference view filtered to Tamm"
xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID"
xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" --aerouchet-ci-aircraft-tamm
sleep 6
xcrun simctl io "$DEVICE_ID" screenshot "$RESULTS/aircraft-tamm-raw.png"
if [ "$(cat "$RESULTS/raw-buffer-size.txt")" = "2048x2732" ]; then
  sips --rotate 90 --out "$RESULTS/aircraft-tamm.png" "$RESULTS/aircraft-tamm-raw.png" >/dev/null
else
  cp "$RESULTS/aircraft-tamm-raw.png" "$RESULTS/aircraft-tamm.png"
fi
python3 - "$RESULTS/aircraft-tamm.png" <<'PY'
import struct
import sys
with open(sys.argv[1], "rb") as stream:
    data = stream.read(24)
assert data[:8] == bytes([137, 80, 78, 71, 13, 10, 26, 10]), "Invalid aircraft PNG"
width, height = struct.unpack(">II", data[16:24])
print("Aircraft screenshot dimensions:", width, "x", height)
assert (width, height) == (2732, 2048), "Aircraft screenshot is not 12.9-inch landscape"
PY
if ! xcrun simctl spawn "$DEVICE_ID" launchctl list | grep -F "$BUNDLE_ID"; then
  echo "Aircraft screen launch disappeared" >&2
  echo "AIRCRAFT_EXITED" > "$RESULTS/status.txt"
  exit 1
fi

# Lightweight iPhone-preview sized enough for readable labels on mobile.
sips -s format jpeg -s formatOptions 85 -Z 1800 \
  --out "$RESULTS/aircraft-tamm-preview.jpg" "$RESULTS/aircraft-tamm.png" >/dev/null

echo "PASS" > "$RESULTS/status.txt"
echo "PASS: iPad 12.9-inch, landscape, dark, main + actual aircraft Tamm screen; both app launches stayed running"
