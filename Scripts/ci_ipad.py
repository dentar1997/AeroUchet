#!/usr/bin/env python3
"""iPad Simulator tooling for AeroUchet CI (GitHub Actions macOS runners).

Only the Python standard library is used.

Subcommands
  prepare        boot the 12.9-inch iPad: dark appearance, Simulator GUI, Rotate Right.
                 --settle (warm session) also installs a recent CI build once, verifies
                 landscape on real pixels and warms the screenshot path.
  capture        install a CI-built .app and take verified landscape screenshots.
  wait-artifact  wait for this run's AeroUchet-Simulator artifact and download it.
  session        warm iPad session: serves every new head SHA of open prewarm/* PRs.
  publish        put a capture on the ci-shots branch (readable through plain git).
  verify-shot    PR build job: wait for this SHA's warm shot on ci-shots, re-check it.
  fetch-shot     assistants: wait for a shot on ci-shots and copy it locally (git only).
  check-raw      letterbox check of a raw screenshot or of a raw-top strip.
  summarize      markdown summary of a capture directory.

Profile (U47): iPad Pro 12.9-inch (prefer 3rd generation), landscape, dark.
A screenshot is never accepted on PNG size alone: the raw framebuffer must not be
portrait-letterboxed (see check_raw), the app must still be running, and every
proof names the PR head SHA and the build run that produced the installed app.
"""

import argparse
import base64
import glob
import io
import json
import os
import plistlib
import re
import shlex
import shutil
import struct
import subprocess
import sys
import tarfile
import tempfile
import threading
import time
import urllib.error
import urllib.request
import zipfile
import zlib
from datetime import datetime, timezone

REPO = os.environ.get("GITHUB_REPOSITORY", "dentar1997/AeroUchet")
API_URL = os.environ.get("GITHUB_API_URL", "https://api.github.com")
SERVER_URL = os.environ.get("GITHUB_SERVER_URL", "https://github.com")
WARM_WORKFLOW_FILE = "early-ipad-prewarm.yml"
CI_WORKFLOW_FILE = "ios-ci.yml"
CI_WORKFLOW_NAME = "AeroUchet CI"
BUILD_JOB_NAME = "Build iOS app"
APP_ARTIFACT = "AeroUchet-Simulator"
SHOTS_BRANCH = "ci-shots"
WARM_BRANCH_PREFIX = "prewarm/"
ACTIVE_RUN_STATES = ("queued", "in_progress", "waiting", "requested", "pending")
WAITING_RUN_STATES = ("queued", "waiting", "requested", "pending")
DEVICE_NAME = "AeroUchet iPad Pro 12.9 CI"
RAW_SIZE = (2048, 2732)
LANDSCAPE_SIZE = (2732, 2048)
SAMPLE_ROW = 96
STRIP_ROWS = 128
LETTERBOX_LIMIT = 9.0
KEEP_SHOTS = 6
KEEP_SESSIONS = 5
JPEG_QUALITY = 80
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
USER_AGENT = "aerouchet-ci-ipad"
BOT_NAME = "github-actions[bot]"
BOT_EMAIL = "41898282+github-actions[bot]@users.noreply.github.com"

# Screens the app can open directly with a simulator-only launch argument.
SHOT_REGISTRY = {
    "main-screen": {"args": [], "settle": 5},
    "aircraft-tamm": {"args": ["--aerouchet-ci-aircraft-tamm"], "settle": 2},
}
DEFAULT_WARM_SHOTS = "aircraft-tamm"
SHOT_NAME_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,39}$")
SHOT_ARG_RE = re.compile(r"^--aerouchet-ci-[a-z0-9-]{1,60}$")

ROTATE_RIGHT = """tell application "Simulator" to activate
tell application "System Events"
  tell application process "Simulator"
    click menu item "Rotate Right" of menu 1 of menu bar item "Device" of menu bar 1
  end tell
end tell
"""

SHOTS_README = """# ci-shots — служебная ветка снимков iPad из CI

Ветку перезаписывает автоматика (`Scripts/ci_ipad.py publish`): один коммит,
последние снимки iPad Pro 12,9″ (альбомная, тёмная тема) по SHA PR.
Нужна, чтобы ИИ видел снимок через обычный git, без скачивания артефактов.

- `latest.json` — последний опубликованный снимок;
- `index.json` — последние снимки и сессии тёплого iPad;
- `shots/<SHA>/` — `proof.json` (SHA, build run, проверки), `*.jpg`,
  `*-raw-top.png` (верх сырого кадра для проверки поворота), `timeline.jsonl`, `capture.log`;
- `sessions/<run>.json` — состояние сессии тёплого iPad.

Личных данных здесь нет: Simulator в CI чистый, без загрузок Дениса.
"""


# --------------------------------------------------------------------------- logging

_SINKS = []


def log(message):
    stamp = datetime.now(timezone.utc).strftime("%H:%M:%S")
    line = f"[{stamp}] {message}"
    print(line, flush=True)
    for sink in list(_SINKS):
        try:
            sink.write(line + "\n")
            sink.flush()
        except (OSError, ValueError):
            pass


class LogTo:
    """Duplicate log() output into a file for the duration of a block."""

    def __init__(self, path):
        self.path = path
        self.handle = None

    def __enter__(self):
        self.handle = open(self.path, "a", encoding="utf-8")
        _SINKS.append(self.handle)
        return self

    def __exit__(self, *exc):
        _SINKS.remove(self.handle)
        self.handle.close()
        return False


def redact(arg):
    text = str(arg)
    return "<auth-header>" if "extraheader" in text or "AUTHORIZATION" in text else text


def fmt(cmd):
    return " ".join(shlex.quote(redact(part)) for part in cmd)


def utc(epoch=None):
    moment = datetime.fromtimestamp(time.time() if epoch is None else epoch, timezone.utc)
    return moment.strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_utc(text):
    return datetime.strptime(text, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc).timestamp()


class Timeline:
    """Append-only JSONL of phases; since_t0_sec is relative to the request time."""

    def __init__(self, path, t0=None):
        self.path = path
        self.t0 = t0
        os.makedirs(os.path.dirname(path) or ".", exist_ok=True)

    def mark(self, phase, **extra):
        now = time.time()
        record = {"phase": phase, "utc": utc(now), "epoch": round(now, 1)}
        if self.t0:
            record["since_t0_sec"] = round(now - self.t0, 1)
        record.update(extra)
        line = json.dumps(record, ensure_ascii=False)
        with open(self.path, "a", encoding="utf-8") as stream:
            stream.write(line + "\n")
        log("TIMELINE " + line)
        return now


# --------------------------------------------------------------------------- processes and files

class CommandError(RuntimeError):
    pass


def sh(cmd, timeout=300, check=True, quiet=False, input_text=None, env=None, cwd=None):
    started = time.time()
    try:
        done = subprocess.run(
            cmd, capture_output=True, encoding="utf-8", errors="replace",
            timeout=timeout, input=input_text, env=env, cwd=cwd,
        )
    except subprocess.TimeoutExpired:
        log(f"$ {fmt(cmd)}  [TIMEOUT {timeout}s]")
        if check:
            raise CommandError(f"timeout after {timeout}s: {fmt(cmd)}")
        done = subprocess.CompletedProcess(cmd, 124, "", "timeout")
    done.duration = time.time() - started
    log(f"$ {fmt(cmd)}  [{done.duration:.1f}s, rc={done.returncode}]")
    if not quiet:
        for text in (done.stdout, done.stderr):
            text = (text or "").strip()
            if text:
                log("  " + text[-1500:].replace("\n", "\n  "))
    if check and done.returncode != 0:
        detail = ((done.stderr or "") + (done.stdout or "")).strip()[-400:]
        raise CommandError(f"rc={done.returncode}: {fmt(cmd)}: {detail}")
    return done


def write_text(path, text):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as stream:
        stream.write(text)
    os.replace(tmp, path)


def read_text(path):
    try:
        with open(path, encoding="utf-8") as stream:
            return stream.read().strip()
    except (FileNotFoundError, NotADirectoryError):
        return ""


def write_json(path, data):
    write_text(path, json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def read_json(path):
    text = read_text(path)
    if not text:
        return None
    try:
        return json.loads(text)
    except ValueError:
        return None


# --------------------------------------------------------------------------- PNG (no third-party code)

def png_header(path):
    with open(path, "rb") as stream:
        head = stream.read(33)
    if len(head) < 33 or head[:8] != PNG_SIGNATURE or head[12:16] != b"IHDR":
        raise ValueError(f"{os.path.basename(path)}: not a PNG")
    width, height, depth, color, _, _, interlace = struct.unpack(">IIBBBBB", head[16:29])
    return width, height, depth, color, interlace


def png_top_rows(path, count):
    """Decode only the first `count` rows of an 8-bit RGB/RGBA PNG."""
    width, height, depth, color, interlace = png_header(path)
    if depth != 8 or color not in (2, 6) or interlace:
        raise ValueError(f"{os.path.basename(path)}: unsupported PNG format")
    with open(path, "rb") as stream:
        data = stream.read()
    components = 3 if color == 2 else 4
    count = min(count, height)
    stride = width * components
    idat = bytearray()
    offset = 8
    while offset + 12 <= len(data):
        size = struct.unpack_from(">I", data, offset)[0]
        tag = data[offset + 4:offset + 8]
        if tag == b"IDAT":
            idat.extend(data[offset + 8:offset + 8 + size])
        elif tag == b"IEND":
            break
        offset += size + 12
    needed = count * (stride + 1)
    raw = zlib.decompressobj().decompress(bytes(idat), needed)
    if len(raw) < needed:
        raise ValueError(f"{os.path.basename(path)}: truncated image data")
    rows = []
    above = bytearray(stride)
    pos = 0
    for _ in range(count):
        kind = raw[pos]
        pos += 1
        row = bytearray(raw[pos:pos + stride])
        pos += stride
        if kind == 1:
            for i in range(components, stride):
                row[i] = (row[i] + row[i - components]) & 255
        elif kind == 2:
            for i in range(stride):
                row[i] = (row[i] + above[i]) & 255
        elif kind == 3:
            for i in range(stride):
                left = row[i - components] if i >= components else 0
                row[i] = (row[i] + ((left + above[i]) >> 1)) & 255
        elif kind == 4:
            for i in range(stride):
                a = row[i - components] if i >= components else 0
                b = above[i]
                c = above[i - components] if i >= components else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                predictor = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                row[i] = (row[i] + predictor) & 255
        elif kind != 0:
            raise ValueError(f"{os.path.basename(path)}: bad PNG filter {kind}")
        rows.append(row)
        above = row
    return width, height, components, rows


def write_png(path, width, components, rows):
    color = 6 if components == 4 else 2
    payload = b"".join(b"\x00" + bytes(row) for row in rows)

    def chunk(tag, body):
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", width, len(rows), 8, color, 0, 0, 0)
    with open(path, "wb") as stream:
        stream.write(PNG_SIGNATURE + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(payload, 9)) + chunk(b"IEND", b""))


def check_raw(path, strip_path=None, allow_strip=False):
    """Mean red level of raw row 96. A portrait-letterboxed frame is black there (~0).

    simctl keeps a 2048x2732 buffer even when the iPad UI is rotated to landscape;
    a correctly rotated landscape app fills the top of that buffer (level ~44 in
    AeroUchet's dark UI). Optionally saves the decoded top rows as a small strip
    so another job can repeat the check without the 5 MB raw file.
    """
    width, height, _, _, _ = png_header(path)
    if allow_strip:
        if width != RAW_SIZE[0] or height <= SAMPLE_ROW:
            raise ValueError(f"unexpected strip size {width}x{height}")
    elif (width, height) != RAW_SIZE:
        raise ValueError(f"unexpected raw size {width}x{height}")
    width, _, components, rows = png_top_rows(path, STRIP_ROWS)
    row = rows[SAMPLE_ROW]
    level = sum(row[i] for i in range(0, width * components, components * 8)) / (width // 8)
    if strip_path:
        write_png(strip_path, width, components, rows)
    return level


# --------------------------------------------------------------------------- Simulator

def simctl(*args, **kwargs):
    return sh(["xcrun", "simctl", *args], **kwargs)


def select_device():
    devices = json.loads(simctl("list", "devices", "available", "-j", quiet=True, timeout=240).stdout).get("devices", {})
    types = json.loads(simctl("list", "devicetypes", "-j", quiet=True, timeout=240).stdout).get("devicetypes", [])
    runtimes = []
    for runtime in devices:
        match = re.search(r"\.iOS-(\d+)(?:-(\d+))?", runtime)
        if match and int(match.group(1)) >= 26:
            runtimes.append(((int(match.group(1)), int(match.group(2) or 0)), runtime))
    if not runtimes:
        raise CommandError("No installed iOS 26+ runtime")
    runtimes.sort(reverse=True)

    def twelve_nine(name):
        return "iPad" in name and re.search(r"12[.,]9", name) is not None

    def third_gen(name):
        return re.search(r"(?:3rd|third)\s+generation", name, re.I) is not None

    existing = [
        (item, runtime)
        for _, runtime in runtimes
        for item in devices.get(runtime, [])
        if item.get("isAvailable") is not False and twelve_nine(item.get("name", ""))
    ]
    exact = [pair for pair in existing if third_gen(pair[0]["name"])]
    if exact:
        item, runtime = exact[0]
        return item["udid"], {"name": item["name"], "runtime": runtime, "how": "existing 3rd generation"}
    # The user's 2019 iPad Pro 12.9" is closest to the 3rd generation: create it.
    candidates = sorted(
        (kind for kind in types if twelve_nine(kind.get("name", ""))),
        key=lambda kind: (not third_gen(kind.get("name", "")), kind.get("name", "")),
    )
    for kind in candidates:
        for _, runtime in runtimes:
            made = simctl("create", DEVICE_NAME, kind["identifier"], runtime, check=False, timeout=240)
            if made.returncode == 0 and made.stdout.strip():
                return made.stdout.strip(), {"name": kind["name"], "runtime": runtime, "how": "created"}
    if existing:
        item, runtime = existing[0]
        log(f"WARNING: closest available 12.9-inch model: {item['name']} ({runtime})")
        return item["udid"], {"name": item["name"], "runtime": runtime, "how": "closest existing"}
    raise CommandError("No 12.9-inch iPad Pro Simulator; refusing to switch to 13-inch")


def boot_device(udid):
    done = simctl("boot", udid, check=False, timeout=300)
    if done.returncode != 0 and "Booted" not in (done.stderr or "") + (done.stdout or ""):
        raise CommandError("simctl boot failed")
    simctl("bootstatus", udid, "-b", timeout=900, quiet=True)


def current_appearance(udid):
    return (simctl("ui", udid, "appearance", check=False, timeout=180).stdout or "").strip()


def ensure_dark(udid):
    for _ in range(3):
        simctl("ui", udid, "appearance", "dark", check=False, timeout=180)
        appearance = current_appearance(udid)
        if "dark" in appearance.lower():
            return appearance
        time.sleep(2)
    raise CommandError("cannot verify dark system appearance")


def gui_running():
    return subprocess.run(["pgrep", "-x", "Simulator"], capture_output=True).returncode == 0


def open_gui(udid):
    sh(["open", "-a", "Simulator", "--args", "-CurrentDeviceUDID", udid], check=False, timeout=120)
    deadline = time.time() + 90
    while time.time() < deadline:
        if gui_running():
            return
        time.sleep(0.5)
    raise CommandError("Simulator.app did not start")


def rotate_right():
    """simctl has no rotate command: use Simulator's own Device > Rotate Right menu."""
    for attempt in range(1, 6):
        if sh(["osascript", "-"], input_text=ROTATE_RIGHT, check=False, timeout=90).returncode == 0:
            return attempt
        time.sleep(2)
    raise CommandError("Simulator Device > Rotate Right was not accepted")


# --------------------------------------------------------------------------- local incremental build (warm session)

APP_NAME = "АэроУчёт"
XCODEBUILD_ARGS = [
    "-scheme", APP_NAME,
    "-destination", "generic/platform=iOS Simulator",
    "CODE_SIGNING_ALLOWED=NO",
    "ARCHS=arm64",
]
COMPILE_ERROR_RE = re.compile(r"\.swift:\d+:\d+: error: ")
# Same wrapper the CI "Package simulator app" step writes when no .app is produced.
FALLBACK_INFO = {
    "CFBundleDevelopmentRegion": "ru",
    "CFBundleDisplayName": APP_NAME,
    "CFBundleExecutable": APP_NAME,
    "CFBundleIdentifier": "local.aerouchet.simulator",
    "CFBundleInfoDictionaryVersion": "6.0",
    "CFBundleName": APP_NAME,
    "CFBundlePackageType": "APPL",
    "CFBundleShortVersionString": "1.0",
    "CFBundleVersion": "1",
    "LSRequiresIPhoneOS": True,
    "MinimumOSVersion": "26.0",
    "UIDeviceFamily": [1, 2],
}


def repo_remote():
    return f"{SERVER_URL}/{REPO}.git"


class SourceTree:
    """One working copy and one DerivedData for the whole session. git rewrites
    only the files that differ between commits, so xcodebuild recompiles only
    what changed instead of the whole app on a fresh CI runner."""

    def __init__(self, root):
        self.dir = os.path.join(root, "src")
        self.derived = os.path.join(root, "DerivedData")

    def git(self, args, **kwargs):
        return sh(["git", "-C", self.dir, *args], **kwargs)

    def fetch(self, refspec):
        if not os.path.isdir(os.path.join(self.dir, ".git")):
            os.makedirs(self.dir, exist_ok=True)
            sh(["git", "init", "-q", self.dir], quiet=True)
        self.git(["fetch", "-q", "--depth", "1", repo_remote(), refspec], timeout=300, quiet=True)
        return self.git(["rev-parse", "FETCH_HEAD"], quiet=True).stdout.strip()

    def parents(self, commit):
        text = self.git(["cat-file", "-p", commit], quiet=True).stdout
        return [line.split()[1] for line in text.splitlines() if line.startswith("parent ")]

    def checkout(self, commit):
        self.git(["checkout", "-q", "--force", "--detach", commit], timeout=300, quiet=True)

    def build(self, log_path, timeout=1500):
        """(kind, seconds, lines): kind is ok, compile (Swift errors) or infra."""
        started = time.time()
        cmd = ["xcodebuild", *XCODEBUILD_ARGS, "-derivedDataPath", self.derived, "build"]
        try:
            with open(log_path, "w", encoding="utf-8") as stream:
                code = subprocess.run(cmd, cwd=self.dir, stdout=stream, stderr=subprocess.STDOUT, timeout=timeout).returncode
        except subprocess.TimeoutExpired:
            code = 124
        seconds = time.time() - started
        lines = read_text(log_path).splitlines()
        log(f"xcodebuild build in the session [{seconds:.1f}s, rc={code}]")
        if code == 0:
            return "ok", seconds, []
        errors = sorted({line.strip() for line in lines if COMPILE_ERROR_RE.search(line)})[:40]
        if errors:
            return "compile", seconds, errors
        return "infra", seconds, [line.strip() for line in lines if "error" in line.lower()][-10:] or [f"xcodebuild rc={code}"]

    def package(self, work):
        products = os.path.join(self.derived, "Build", "Products", "Debug-iphonesimulator")
        apps = glob.glob(os.path.join(products, "**", "*.app"), recursive=True)
        if apps:
            return min(apps, key=lambda path: (path.count(os.sep), path))
        executable = os.path.join(products, APP_NAME)
        if not os.path.isfile(executable):
            raise CommandError("the build produced neither an .app nor the executable")
        app = os.path.join(work, APP_NAME + ".app")
        shutil.rmtree(app, ignore_errors=True)
        os.makedirs(app)
        shutil.copy2(executable, os.path.join(app, APP_NAME))
        with open(os.path.join(app, "Info.plist"), "wb") as stream:
            plistlib.dump(FALLBACK_INFO, stream)
        return app


def prebuild_base(src_root, state, timeline):
    """Build main once while the iPad settles: later PR builds are incremental."""
    tree = SourceTree(src_root)
    commit = tree.fetch("refs/heads/main")
    tree.checkout(commit)
    timeline.mark("settle.base_checked_out", commit=commit[:12])
    kind, seconds, lines = tree.build(state_file(state, "prebuild.log"))
    timeline.mark("settle.base_built", kind=kind, build_sec=round(seconds, 1))
    if kind != "ok":
        log("base prebuild failed: " + "; ".join(lines[:3]))
        return None
    return tree.package(state_file(state, "prebuild-app"))


def install_app(udid, app, bundle, state):
    """Clean install. An in-place upgrade of the previous build has failed with
    installd 'deltainstallcommands … try again later', so a build installed earlier
    in this state is removed first. A fresh device is NOT asked to terminate or
    uninstall: right after boot those no-op calls took 60 s and 110 s (PR #204)."""
    marker = state_file(state, "app-installed")
    if os.path.exists(marker):
        simctl("terminate", udid, bundle, check=False, timeout=60, quiet=True)
        simctl("uninstall", udid, bundle, check=False, timeout=180, quiet=True)
    for attempt in range(1, 4):
        if simctl("install", udid, app, check=False, timeout=300).returncode == 0:
            write_text(marker, bundle)
            return attempt
        log(f"simctl install failed (attempt {attempt}); uninstalling and retrying")
        time.sleep(2 * attempt)
        simctl("uninstall", udid, bundle, check=False, timeout=120, quiet=True)
    raise CommandError("simctl install failed three times")


def patch_app(app):
    """Restrict ONLY this test copy to landscape (shipped app and sources untouched)."""
    plist_path = os.path.join(app, "Info.plist")
    with open(plist_path, "rb") as stream:
        info = plistlib.load(stream)
    landscape = ["UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"]
    info["UIRequiresFullScreen"] = True
    info["UISupportedInterfaceOrientations"] = list(landscape)
    info["UISupportedInterfaceOrientations~ipad"] = list(landscape)
    with open(plist_path, "wb") as stream:
        plistlib.dump(info, stream)
    return app, info["CFBundleIdentifier"]


def unpack_app(archive, work):
    """Unzip a CI .app archive into a scratch copy and patch it."""
    shutil.rmtree(work, ignore_errors=True)
    os.makedirs(work)
    sh(["unzip", "-q", archive, "-d", work], timeout=240)
    apps = glob.glob(os.path.join(work, "**", "*.app"), recursive=True)
    if not apps:
        raise CommandError("no .app bundle inside the archive")
    return patch_app(min(apps, key=lambda path: (path.count(os.sep), path)))


def stage_app(source, work):
    """A .zip from CI or a .app folder from a local build → patched scratch copy."""
    if os.path.isdir(source):
        shutil.rmtree(work, ignore_errors=True)
        os.makedirs(work)
        copy = os.path.join(work, os.path.basename(source.rstrip(os.sep)))
        shutil.copytree(source, copy, symlinks=True)
        return patch_app(copy)
    return unpack_app(source, work)


def launch_app(udid, bundle, args):
    simctl("launch", "--terminate-running-process", udid, bundle, *args, timeout=180)


def app_alive(udid, bundle):
    done = simctl("spawn", udid, "launchctl", "list", check=False, timeout=180, quiet=True)
    return bundle in (done.stdout or "")


def screenshot(udid, path):
    if os.path.exists(path):
        os.remove(path)
    return simctl("io", udid, "screenshot", path, timeout=300, quiet=True).duration


def normalize_raw(raw, png):
    width, height = png_header(raw)[:2]
    if (width, height) == RAW_SIZE:
        sh(["sips", "--rotate", "90", "--out", png, raw], quiet=True, timeout=120)
    elif (width, height) == LANDSCAPE_SIZE:
        shutil.copyfile(raw, png)
    else:
        raise CommandError(f"unexpected raw size {width}x{height}")
    if png_header(png)[:2] != LANDSCAPE_SIZE:
        raise CommandError("PROFILE_MISMATCH: expected a 2732x2048 landscape PNG")


def capture_one(udid, bundle, shot, out, timeline, export=True):
    name = shot["name"]
    launch_app(udid, bundle, shot["args"])
    timeline.mark(f"{name}.launched")
    time.sleep(shot["settle"])
    raw = os.path.join(out, f"{name}-raw.png")
    strip = os.path.join(out, f"{name}-raw-top.png")
    seconds = screenshot(udid, raw)
    level = check_raw(raw, strip)
    timeline.mark(f"{name}.raw_ready", screenshot_sec=round(seconds, 1), red_level=round(level, 1))
    repairs = 0
    while level < LETTERBOX_LIMIT:
        if repairs >= 4:
            raise CommandError(f"{name}: raw frame still portrait-letterboxed after {repairs} rotations; refusing a false PASS")
        repairs += 1
        log(f"{name}: portrait letterbox (red {level:.1f}); Rotate Right repair {repairs}")
        if not gui_running():
            open_gui(udid)
        rotate_right()
        time.sleep(3)
        seconds = screenshot(udid, raw)
        level = check_raw(raw, strip)
        timeline.mark(f"{name}.raw_retry", attempt=repairs, screenshot_sec=round(seconds, 1), red_level=round(level, 1))
    result = {
        "name": name,
        "args": shot["args"],
        "settle_sec": shot["settle"],
        "raw_red_level": round(level, 1),
        "rotation_repairs": repairs,
        "screenshot_sec": round(seconds, 1),
    }
    if export:
        png = os.path.join(out, f"{name}.png")
        normalize_raw(raw, png)
        jpg = os.path.join(out, f"{name}.jpg")
        sh(["sips", "-s", "format", "jpeg", "-s", "formatOptions", str(JPEG_QUALITY), png, "--out", jpg], quiet=True, timeout=120)
        result["image"] = f"{name}.jpg"
    if not app_alive(udid, bundle):
        raise CommandError(f"{name}: the application exited before verification")
    timeline.mark(f"{name}.done")
    return result


# --------------------------------------------------------------------------- prepare / capture

def state_file(state, name):
    return os.path.join(state, name)


def prepare_pid_alive(state):
    pid = read_text(state_file(state, "prepare.pid"))
    if not pid:
        return False
    try:
        os.kill(int(pid), 0)
        return True
    except (OSError, ValueError):
        return False


def wait_state(state, name, accepted, timeout):
    """Wait for a state marker written by the prepare process."""
    deadline = time.time() + timeout
    grace = time.time() + 5
    while time.time() < deadline:
        value = read_text(state_file(state, name))
        if value in accepted:
            return value
        if not prepare_pid_alive(state) and time.time() > grace:
            value = read_text(state_file(state, name))
            return value if value in accepted else "NOT_RUNNING"
        time.sleep(0.5)
    return "TIMEOUT"


def prepare_device(state, visual, settle, timeline, src_root=None):
    os.makedirs(state, exist_ok=True)
    timeline.mark("prepare.start", visual=visual, settle=settle)
    udid = read_text(state_file(state, "device-udid.txt"))
    if not udid:
        udid, device = select_device()
        write_json(state_file(state, "device.json"), device)
        write_text(state_file(state, "device-udid.txt"), udid)
        timeline.mark("prepare.device_selected", device=device["name"], runtime=device["runtime"], how=device["how"])
    if read_text(state_file(state, "boot.status")) != "BOOTED":
        boot_device(udid)
        write_text(state_file(state, "boot.status"), "BOOTED")
        timeline.mark("prepare.booted")
    if visual:
        appearance = ensure_dark(udid)
        write_text(state_file(state, "appearance.status"), appearance)
        timeline.mark("prepare.dark", appearance=appearance)
        if not gui_running():
            open_gui(udid)
        timeline.mark("prepare.gui_open")
        if read_text(state_file(state, "rotation.status")) != "REQUESTED":
            attempts = rotate_right()
            write_text(state_file(state, "rotation.status"), "REQUESTED")
            timeline.mark("prepare.rotate_requested", osascript_attempts=attempts)
    if settle:
        settle_device(state, udid, timeline, src_root)
    write_text(state_file(state, "prepare.status"), "READY")
    timeline.mark("prepare.ready")
    return udid


def settle_device(state, udid, timeline, src_root=None):
    """Warm session only: let the freshly booted iPadOS finish its first-boot work.

    Builds main once (so PR builds are incremental), installs that build, launches
    the target screen, verifies the landscape frame on real pixels (repairing the
    rotation if needed) and takes an extra screenshot, so the first real PR
    capture meets a quiet system. A recent CI artifact is the fallback app.
    """
    source, origin = None, None
    if src_root:
        try:
            source = prebuild_base(src_root, state, timeline)
            origin = "prebuilt main"
        except Exception as error:
            log(f"base prebuild failed: {error}")
    if source is None:
        ready_zip = state_file(state, "warm-app.zip")
        none_marker = state_file(state, "warm-app.none")
        deadline = time.time() + 240
        while time.time() < deadline and not (os.path.exists(ready_zip) or os.path.exists(none_marker)):
            time.sleep(1)
        if os.path.exists(ready_zip):
            source, origin = ready_zip, read_text(state_file(state, "warm-app.source"))
    out = state_file(state, "warmup")
    os.makedirs(out, exist_ok=True)
    if source:
        app, bundle = stage_app(source, os.path.join(out, "_app"))
        install_app(udid, app, bundle, state)
        timeline.mark("settle.warm_app_installed", source=origin)
        shot = {"name": "warmup", "args": list(SHOT_REGISTRY["aircraft-tamm"]["args"]), "settle": 2}
        result = capture_one(udid, bundle, shot, out, timeline, export=False)
        write_json(state_file(state, "orientation.json"), result)
        seconds = screenshot(udid, os.path.join(out, "warmup-second.png"))
        timeline.mark("settle.second_screenshot", screenshot_sec=round(seconds, 1))
        simctl("terminate", udid, bundle, check=False, timeout=60, quiet=True)
        shutil.rmtree(os.path.join(out, "_app"), ignore_errors=True)
    else:
        simctl("launch", udid, "com.apple.Preferences", check=False, timeout=180)
        time.sleep(3)
        for index in (1, 2):
            seconds = screenshot(udid, os.path.join(out, f"preferences-{index}.png"))
            timeline.mark("settle.screenshot", index=index, screenshot_sec=round(seconds, 1))
        simctl("terminate", udid, "com.apple.Preferences", check=False, timeout=60, quiet=True)
    timeline.mark("settle.done")


def build_shots(names=None, spec=None):
    """Shots from a registry list ("a,b:4") or a JSON spec (.github/prewarm/shots.json)."""
    shots = []
    if spec is not None:
        items = spec.get("shots") if isinstance(spec, dict) else spec
        if not isinstance(items, list) or not 1 <= len(items) <= 4:
            raise ValueError("shots spec must list 1-4 shots")
        for item in items:
            name = str(item.get("name", ""))
            if not SHOT_NAME_RE.match(name):
                raise ValueError(f"bad shot name {name!r}")
            base = SHOT_REGISTRY.get(name, {"args": [], "settle": 3})
            args = item.get("args", base["args"])
            if not isinstance(args, list) or not all(isinstance(a, str) and SHOT_ARG_RE.match(a) for a in args):
                raise ValueError(f"shot {name}: launch arguments must look like --aerouchet-ci-...")
            settle = int(item.get("settle", base["settle"]))
            if not 1 <= settle <= 15:
                raise ValueError(f"shot {name}: settle must be 1-15 seconds")
            shots.append({"name": name, "args": list(args), "settle": settle})
        return shots
    for token in (names or DEFAULT_WARM_SHOTS).split(","):
        name, _, settle = token.strip().partition(":")
        if name not in SHOT_REGISTRY:
            raise ValueError(f"unknown shot {name!r}")
        base = SHOT_REGISTRY[name]
        shots.append({"name": name, "args": list(base["args"]), "settle": int(settle) if settle else base["settle"]})
    return shots


def capture(state, archive, out, shots, meta, install_early):
    """Install the app built for meta['pr_sha'] and take every verified shot."""
    os.makedirs(out, exist_ok=True)
    timeline = Timeline(os.path.join(out, "timeline.jsonl"), meta.get("t0"))
    proof = {
        "status": "FAIL",
        "stage": "start",
        "mode": meta.get("mode"),
        "pr_sha": meta.get("pr_sha"),
        "pr_number": meta.get("pr_number"),
        "head_ref": meta.get("head_ref"),
        "build_run_id": meta.get("build_run_id"),
        "artifact_id": meta.get("artifact_id"),
        "session_run_id": meta.get("session_run_id"),
        "ci_run_created": meta.get("ci_run_created"),
        "source": meta.get("source"),
        "built_commit": meta.get("built_commit"),
        "built_ref": meta.get("built_ref"),
        "build_sec": meta.get("build_sec"),
        "target": "iPad Pro 12.9-inch, landscape, dark",
        "shots": [],
    }
    started = time.time()
    with LogTo(os.path.join(out, "capture.log")):
        try:
            timeline.mark("capture.start", mode=meta.get("mode"), sha=(meta.get("pr_sha") or "")[:12])
            proof["stage"] = "boot"
            if wait_state(state, "boot.status", {"BOOTED"}, 900) != "BOOTED":
                log("No prepared iPad: booting it here")
                prepare_device(state, visual=True, settle=False, timeline=timeline)
            udid = read_text(state_file(state, "device-udid.txt"))
            proof["device"] = read_json(state_file(state, "device.json"))
            proof["stage"] = "unpack"
            app, bundle = stage_app(archive, os.path.join(out, "_app"))
            timeline.mark("capture.unpacked")
            if install_early:
                proof["stage"] = "install"
                install_app(udid, app, bundle, state)
                timeline.mark("capture.installed")
            proof["stage"] = "visual"
            prepared = wait_state(state, "prepare.status", {"READY", "FAILED"}, 600)
            if prepared != "READY":
                log(f"Prepare status {prepared}: setting dark appearance and rotation here")
                ensure_dark(udid)
                if not gui_running():
                    open_gui(udid)
                if read_text(state_file(state, "rotation.status")) != "REQUESTED":
                    rotate_right()
                    write_text(state_file(state, "rotation.status"), "REQUESTED")
                timeline.mark("capture.visual_repaired", prepare_status=prepared)
            if not install_early:
                proof["stage"] = "install"
                install_app(udid, app, bundle, state)
                timeline.mark("capture.installed")
            appearance = current_appearance(udid)
            if "dark" not in appearance.lower():
                appearance = ensure_dark(udid)
            proof["appearance"] = appearance
            for shot in shots:
                proof["stage"] = f"shot:{shot['name']}"
                proof["shots"].append(capture_one(udid, bundle, shot, out, timeline))
            proof["status"] = "PASS"
            proof["stage"] = "done"
        except Exception as error:  # every failure becomes a FAIL proof with its stage
            proof["error"] = str(error)[:1500]
            log(f"CAPTURE FAILED at {proof['stage']}: {error}")
        finally:
            ready = timeline.mark("capture.end", status=proof["status"])
            proof["capture_sec"] = round(ready - started, 1)
            proof["shot_ready_utc"] = utc(ready)
            proof["shot_ready_epoch"] = round(ready, 1)
            if meta.get("ci_run_created"):
                proof["ci_run_to_shot_sec"] = round(ready - parse_utc(meta["ci_run_created"]), 1)
            if meta.get("t0"):
                proof["t0_to_shot_sec"] = round(ready - meta["t0"], 1)
            write_json(os.path.join(out, "proof.json"), proof)
            write_text(os.path.join(out, "status.txt"), proof["status"])
            shutil.rmtree(os.path.join(out, "_app"), ignore_errors=True)
    return proof


def failure_proof(out, meta, stage, error):
    """FAIL proof for a SHA that never reached the iPad (e.g. Swift compile errors)."""
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(out)
    now = time.time()
    proof = {key: meta.get(key) for key in (
        "mode", "pr_sha", "pr_number", "head_ref", "build_run_id", "session_run_id",
        "ci_run_created", "source", "built_commit", "built_ref", "build_sec")}
    proof.update({
        "status": "FAIL", "stage": stage, "error": error[:6000], "shots": [],
        "target": "iPad Pro 12.9-inch, landscape, dark",
        "shot_ready_utc": utc(now), "shot_ready_epoch": round(now, 1),
    })
    write_json(os.path.join(out, "proof.json"), proof)
    write_text(os.path.join(out, "status.txt"), "FAIL")
    write_text(os.path.join(out, "capture.log"), error + "\n")
    return proof


# --------------------------------------------------------------------------- GitHub REST (stdlib, ETag-aware)

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


class GitHub:
    """Minimal client. Conditional GETs (ETag → 304) do not count against the
    rate limit, so a long session can poll every couple of seconds."""

    def __init__(self, token):
        self.token = token
        self.cache = {}
        self.opener = urllib.request.build_opener(NoRedirect)
        self.remaining = None

    def request(self, method, path, body=None, cache=True, attempts=6):
        url = path if path.startswith("http") else API_URL + path
        cached = self.cache.get(url) if cache and method == "GET" else None
        for attempt in range(1, attempts + 1):
            headers = {
                "Authorization": f"Bearer {self.token}",
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
                "User-Agent": USER_AGENT,
            }
            if cached:
                headers["If-None-Match"] = cached[0]
            data = json.dumps(body).encode("utf-8") if body is not None else None
            request = urllib.request.Request(url, data=data, method=method, headers=headers)
            try:
                with self.opener.open(request, timeout=30) as response:
                    raw = response.read()
                    payload = json.loads(raw.decode("utf-8")) if raw else {}
                    etag = response.headers.get("ETag")
                    self.note_rate(response.headers)
                    if cache and method == "GET" and etag:
                        self.cache[url] = (etag, payload)
                    return payload
            except urllib.error.HTTPError as error:
                self.note_rate(error.headers)
                if error.code == 304 and cached:
                    return cached[1]
                if error.code == 404:
                    return None
                if error.code in (301, 302, 303, 307, 308):
                    return {"_location": error.headers.get("Location")}
                limited = error.code == 403 and error.headers.get("X-RateLimit-Remaining") == "0"
                if not (error.code >= 500 or error.code == 429 or limited) or attempt == attempts:
                    raise
                wait = min(60, 3 * attempt)
                if error.headers.get("Retry-After", "").isdigit():
                    wait = min(120, int(error.headers["Retry-After"]))
                log(f"GitHub API {error.code} for {path}; retry in {wait}s")
                time.sleep(wait)
            except (urllib.error.URLError, OSError) as error:
                if attempt == attempts:
                    raise
                log(f"GitHub API network error for {path} ({error}); retry {attempt}")
                time.sleep(2 * attempt)
        return None

    def note_rate(self, headers):
        value = (headers or {}).get("X-RateLimit-Remaining") if headers is not None else None
        if value is not None and str(value).isdigit():
            self.remaining = int(value)

    def poll_interval(self):
        """2 s normally; back off if the hourly API budget is running low."""
        if self.remaining is not None and self.remaining < 150:
            return 20
        if self.remaining is not None and self.remaining < 400:
            return 8
        return 2

    def get(self, path, cache=True):
        return self.request("GET", path, cache=cache)

    def post(self, path, body=None):
        return self.request("POST", path, body=body, cache=False)


def find_ci_run(gh, sha):
    data = gh.get(f"/repos/{REPO}/actions/runs?head_sha={sha}&event=pull_request&per_page=20") or {}
    runs = [run for run in data.get("workflow_runs", []) if run.get("name") == CI_WORKFLOW_NAME]
    return max(runs, key=lambda run: run["created_at"]) if runs else None


def find_app_artifact(gh, run_id, cache=True):
    data = gh.get(f"/repos/{REPO}/actions/runs/{run_id}/artifacts?per_page=100", cache=cache) or {}
    for item in data.get("artifacts", []):
        if item.get("name") == APP_ARTIFACT and not item.get("expired"):
            return item
    return None


def build_failed(gh, run_id):
    data = gh.get(f"/repos/{REPO}/actions/runs/{run_id}/jobs?per_page=100") or {}
    return any(
        job.get("name") == BUILD_JOB_NAME and job.get("conclusion") in ("failure", "cancelled", "timed_out")
        for job in data.get("jobs", [])
    )


def run_created_at(gh, run_id):
    run = gh.get(f"/repos/{REPO}/actions/runs/{run_id}", cache=False) or {}
    return run.get("created_at")


def warm_runs(gh, cache=True):
    data = gh.get(f"/repos/{REPO}/actions/workflows/{WARM_WORKFLOW_FILE}/runs?per_page=15", cache=cache) or {}
    return data.get("workflow_runs", [])


def run_mode(run):
    """'serve', 'restart' or 'stop' — encoded in the warm workflow's run-name."""
    parts = (run.get("display_title") or "").split(" · ")
    return parts[1].strip() if len(parts) >= 2 and parts[1].strip() in ("serve", "restart", "stop") else "serve"


def download_app_artifact(gh, artifact_id, dest):
    """Download an artifact zip (redirect fetched WITHOUT the API token) and
    return the inner AeroUchet-Simulator.zip."""
    os.makedirs(dest, exist_ok=True)
    outer = os.path.join(dest, "artifact.zip")
    for attempt in range(1, 5):
        try:
            target = gh.request("GET", f"/repos/{REPO}/actions/artifacts/{artifact_id}/zip", cache=False) or {}
            location = target.get("_location")
            if not location:
                raise RuntimeError("no download location for the artifact")
            request = urllib.request.Request(location, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(request, timeout=180) as response, open(outer, "wb") as stream:
                shutil.copyfileobj(response, stream, 1 << 20)
            break
        except (urllib.error.URLError, OSError, RuntimeError) as error:
            if attempt == 4:
                raise
            log(f"artifact download failed ({error}); retry {attempt}")
            time.sleep(2 * attempt)
    with zipfile.ZipFile(outer) as bundle:
        inner = next((name for name in bundle.namelist() if name.endswith(APP_ARTIFACT + ".zip")), None)
        if not inner:
            raise RuntimeError("artifact does not contain AeroUchet-Simulator.zip")
        bundle.extract(inner, dest)
    os.remove(outer)
    return os.path.join(dest, inner)


# --------------------------------------------------------------------------- ci-shots branch (plain git)

def auth_header(token):
    return base64.b64encode(f"x-access-token:{token}".encode("utf-8")).decode("ascii")


def git_in(work, args, auth=None, **kwargs):
    cmd = ["git", "-C", work]
    if auth:
        cmd += ["-c", f"http.{SERVER_URL}/.extraheader=AUTHORIZATION: basic {auth}"]
    return sh(cmd + args, **kwargs)


def shots_remote():
    return f"{SERVER_URL}/{REPO}.git"


def update_shots_branch(token, message, mutate):
    """Rewrite ci-shots as ONE commit (old snapshots are not kept in history),
    with a lease so two writers never silently drop each other's shots."""
    auth = auth_header(token)
    work = tempfile.mkdtemp(prefix="ci-shots-")
    env = dict(os.environ, GIT_AUTHOR_NAME=BOT_NAME, GIT_AUTHOR_EMAIL=BOT_EMAIL,
               GIT_COMMITTER_NAME=BOT_NAME, GIT_COMMITTER_EMAIL=BOT_EMAIL)
    try:
        sh(["git", "init", "-q", work], quiet=True)
        for attempt in range(1, 7):
            for entry in os.listdir(work):
                if entry != ".git":
                    path = os.path.join(work, entry)
                    shutil.rmtree(path) if os.path.isdir(path) else os.remove(path)
            git_in(work, ["read-tree", "--empty"], quiet=True)
            fetched = git_in(work, ["fetch", "-q", "--depth", "1", shots_remote(),
                                    f"+refs/heads/{SHOTS_BRANCH}:refs/shots/current"],
                             auth, check=False, quiet=True, timeout=120)
            old = ""
            if fetched.returncode == 0:
                old = git_in(work, ["rev-parse", "refs/shots/current"], quiet=True).stdout.strip()
                git_in(work, ["read-tree", "refs/shots/current"], quiet=True)
                git_in(work, ["checkout-index", "-a", "-f"], quiet=True)
            mutate(work)
            git_in(work, ["add", "-A"], quiet=True)
            tree = git_in(work, ["write-tree"], quiet=True).stdout.strip()
            commit = sh(["git", "-C", work, "commit-tree", tree, "-m", message], env=env, quiet=True).stdout.strip()
            pushed = git_in(work, ["push", "-q", f"--force-with-lease=refs/heads/{SHOTS_BRANCH}:{old}",
                                   shots_remote(), f"{commit}:refs/heads/{SHOTS_BRANCH}"],
                            auth, check=False, timeout=120)
            if pushed.returncode == 0:
                log(f"ci-shots updated: {message}")
                return True
            denied = (pushed.stderr or "") + (pushed.stdout or "")
            if re.search(r"403|denied|not allowed|Permission", denied):
                log("ci-shots: no write permission for this token (fork PR?); not publishing")
                return False
            time.sleep(attempt)
        return False
    finally:
        shutil.rmtree(work, ignore_errors=True)


def load_index(work):
    index = read_json(os.path.join(work, "index.json")) or {}
    index.setdefault("shots", [])
    index.setdefault("sessions", [])
    return index


def publish_capture(token, out, sha, label):
    proof = read_json(os.path.join(out, "proof.json")) or {}

    def mutate(work):
        shots_root = os.path.join(work, "shots")
        target = os.path.join(shots_root, sha)
        shutil.rmtree(target, ignore_errors=True)
        os.makedirs(target)
        for name in sorted(os.listdir(out)):
            path = os.path.join(out, name)
            if os.path.isfile(path) and (name in ("proof.json", "timeline.jsonl") or name.endswith(".jpg") or name.endswith("-raw-top.png")):
                shutil.copyfile(path, os.path.join(target, name))
        log_path = os.path.join(out, "capture.log")
        if os.path.exists(log_path):
            with open(log_path, "rb") as stream:
                tail = stream.read()[-200000:]
            with open(os.path.join(target, "capture.log"), "wb") as stream:
                stream.write(tail)
        index = load_index(work)
        entry = {
            "sha": sha,
            "label": label,
            "status": proof.get("status"),
            "mode": proof.get("mode"),
            "pr_number": proof.get("pr_number"),
            "build_run_id": proof.get("build_run_id"),
            "ci_run_to_shot_sec": proof.get("ci_run_to_shot_sec"),
            "published_utc": utc(),
            "images": [shot.get("image") for shot in proof.get("shots", []) if shot.get("image")],
        }
        index["shots"] = [entry] + [item for item in index["shots"] if item.get("sha") != sha]
        index["shots"] = index["shots"][:KEEP_SHOTS]
        keep = {item["sha"] for item in index["shots"]}
        for name in os.listdir(shots_root):
            if name not in keep:
                shutil.rmtree(os.path.join(shots_root, name), ignore_errors=True)
        write_json(os.path.join(work, "index.json"), index)
        write_json(os.path.join(work, "latest.json"), entry)
        write_text(os.path.join(work, "README.md"), SHOTS_README)

    return update_shots_branch(token, f"shots: {label} {sha[:12]} {proof.get('status')}", mutate)


def publish_session(token, run_id, data):
    def mutate(work):
        sessions_root = os.path.join(work, "sessions")
        os.makedirs(sessions_root, exist_ok=True)
        write_json(os.path.join(sessions_root, f"{run_id}.json"), data)
        index = load_index(work)
        entry = {"run_id": str(run_id), "state": data.get("state"), "updated_utc": utc()}
        index["sessions"] = [entry] + [item for item in index["sessions"] if item.get("run_id") != str(run_id)]
        index["sessions"] = index["sessions"][:KEEP_SESSIONS]
        keep = {f"{item['run_id']}.json" for item in index["sessions"]}
        for name in os.listdir(sessions_root):
            if name not in keep:
                os.remove(os.path.join(sessions_root, name))
        write_json(os.path.join(work, "index.json"), index)
        write_text(os.path.join(work, "README.md"), SHOTS_README)

    return update_shots_branch(token, f"session {run_id}: {data.get('state')}", mutate)


def extract_shot(work, ref, sha, dest):
    """Copy shots/<sha>/ from a fetched ci-shots ref into dest."""
    archive = subprocess.run(["git", "-C", work, "archive", "--format=tar", ref, f"shots/{sha}"], capture_output=True)
    if archive.returncode != 0:
        raise CommandError(archive.stderr.decode("utf-8", "replace").strip())
    os.makedirs(dest, exist_ok=True)
    with tarfile.open(fileobj=io.BytesIO(archive.stdout)) as bundle:
        for member in bundle.getmembers():
            if not member.isfile():
                continue
            name = os.path.basename(member.name)
            with bundle.extractfile(member) as source, open(os.path.join(dest, name), "wb") as target:
                shutil.copyfileobj(source, target)


def proof_matches(proof, sha, build_run_id, built_commit):
    """A session build must be of the very commit PR CI tested; a CI-artifact
    capture must come from this very PR CI run."""
    if proof.get("pr_sha") != sha:
        return False
    if proof.get("source") == "session-build":
        return bool(built_commit) and proof.get("built_commit") == built_commit
    return str(proof.get("build_run_id")) == str(build_run_id)


def check_extracted_shot(proof, dest):
    """Independent re-check of a published shot (used by the PR build job)."""
    if proof.get("status") != "PASS":
        log(f"Capture FAILED for this SHA at {proof.get('stage')}: {proof.get('error')}")
        tail = read_text(os.path.join(dest, "capture.log"))[-3000:]
        if tail:
            log("capture.log tail:\n" + tail)
        return 1
    if not proof.get("shots"):
        log("Proof lists no shots")
        return 1
    for shot in proof["shots"]:
        strip = os.path.join(dest, f"{shot['name']}-raw-top.png")
        level = check_raw(strip, allow_strip=True)
        if level < LETTERBOX_LIMIT:
            log(f"{shot['name']}: raw strip is portrait-letterboxed (red {level:.1f})")
            return 1
        if abs(level - float(shot.get("raw_red_level", -100))) > 0.6:
            log(f"{shot['name']}: strip level {level:.1f} does not match proof {shot.get('raw_red_level')}")
            return 1
        if not shot.get("image") or not os.path.exists(os.path.join(dest, shot["image"])):
            log(f"{shot['name']}: published image missing")
            return 1
    if "dark" not in str(proof.get("appearance", "")).lower():
        log(f"Proof does not confirm dark appearance: {proof.get('appearance')}")
        return 1
    log(
        f"Verified iPad shot ({proof.get('mode')}, {proof.get('source')}): PR head {proof.get('pr_sha', '')[:12]}, "
        f"built commit {proof.get('built_commit')}, build run {proof.get('build_run_id')}, "
        f"shots {[s['name'] for s in proof['shots']]}, PR CI run → shot {proof.get('ci_run_to_shot_sec')} s"
    )
    return 0


# --------------------------------------------------------------------------- commands

def token_from_env():
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if not token:
        raise SystemExit("GITHUB_TOKEN is required")
    return token


def cmd_prepare(args):
    state = args.state
    os.makedirs(state, exist_ok=True)
    write_text(state_file(state, "prepare.pid"), str(os.getpid()))
    write_text(state_file(state, "prepare.status"), "STARTING")
    timeline = Timeline(state_file(state, "timeline.jsonl"), args.t0)
    try:
        prepare_device(state, args.visual, args.settle, timeline, args.src_root)
        return 0
    except Exception as error:
        write_text(state_file(state, "prepare.error"), str(error))
        write_text(state_file(state, "prepare.status"), "FAILED")
        timeline.mark("prepare.failed", error=str(error)[:300])
        return 1


def shots_from_args(args):
    if getattr(args, "shots_file", None) and os.path.exists(args.shots_file):
        return build_shots(spec=read_json(args.shots_file))
    return build_shots(names=args.shots)


def cmd_capture(args):
    created = args.ci_run_created
    if not created and args.build_run_id and (os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")):
        try:
            created = run_created_at(GitHub(token_from_env()), args.build_run_id)
        except Exception as error:
            log(f"cannot read the CI run creation time: {error}")
    meta = {
        "mode": args.mode,
        "pr_sha": args.pr_sha,
        "pr_number": int(args.pr_number) if str(args.pr_number or "").isdigit() else None,
        "head_ref": args.head_ref,
        "build_run_id": int(args.build_run_id) if str(args.build_run_id or "").isdigit() else args.build_run_id,
        "ci_run_created": created,
    }
    proof = capture(args.state, args.zip, args.out, shots_from_args(args), meta, args.install_early)
    return 0 if proof["status"] == "PASS" else 1


def cmd_wait_artifact(args):
    gh = GitHub(token_from_env())
    timeline = Timeline(os.path.join(args.dest, "timeline.jsonl"))
    deadline = time.time() + args.timeout
    next_build_check = 0
    while time.time() < deadline:
        artifact = find_app_artifact(gh, args.run_id)
        if artifact:
            timeline.mark("artifact.visible", artifact_id=artifact["id"])
            path = download_app_artifact(gh, artifact["id"], args.dest)
            final = os.path.join(args.dest, APP_ARTIFACT + ".zip")
            if os.path.abspath(path) != os.path.abspath(final):
                shutil.move(path, final)
            timeline.mark("artifact.downloaded")
            return 0
        if time.time() >= next_build_check:
            if build_failed(gh, args.run_id):
                log("Build job failed: no app for a screenshot")
                return 1
            next_build_check = time.time() + 8
        time.sleep(2)
    log("Timed out waiting for this run's app artifact")
    return 1


def cmd_publish(args):
    ok = publish_capture(token_from_env(), args.out, args.sha, args.label)
    return 0 if ok else 1


def cmd_verify_shot(args):
    """Exit 0: verified PASS; 1: the shot for this SHA failed; 3: no warm shot will come."""
    token = token_from_env()
    gh = GitHub(token)
    auth = auth_header(token)
    work = tempfile.mkdtemp(prefix="verify-shot-")
    sh(["git", "init", "-q", work], quiet=True)
    deadline = time.time() + args.timeout
    last_ref = None
    inactive_since = None
    next_active_check = 0
    try:
        while time.time() < deadline:
            listed = git_in(work, ["ls-remote", shots_remote(), f"refs/heads/{SHOTS_BRANCH}"], auth, check=False, quiet=True, timeout=60)
            ref = listed.stdout.split()[0] if listed.returncode == 0 and listed.stdout.strip() else None
            if ref and ref != last_ref:
                fetched = git_in(work, ["fetch", "-q", "--depth", "1", shots_remote(), f"+refs/heads/{SHOTS_BRANCH}:refs/shots/current"],
                                 auth, check=False, quiet=True, timeout=120)
                if fetched.returncode == 0:
                    last_ref = ref
                    shown = git_in(work, ["show", f"refs/shots/current:shots/{args.sha}/proof.json"], check=False, quiet=True)
                    if shown.returncode == 0:
                        proof = json.loads(shown.stdout)
                        if proof_matches(proof, args.sha, args.build_run_id, args.built_commit):
                            extract_shot(work, "refs/shots/current", args.sha, args.dest)
                            return check_extracted_shot(proof, args.dest)
                        log(f"A shot for {args.sha[:12]} exists but for another build "
                            f"({proof.get('source')}: commit {proof.get('built_commit')}, run {proof.get('build_run_id')}); waiting")
            if time.time() >= next_active_check:
                active = [run for run in warm_runs(gh, cache=False) if run.get("status") in ACTIVE_RUN_STATES]
                if active:
                    inactive_since = None
                else:
                    inactive_since = inactive_since or time.time()
                    if time.time() - inactive_since >= args.grace:
                        log("No warm iPad session is running")
                        return 3
                next_active_check = time.time() + 10
            time.sleep(2)
        log("Timed out waiting for the warm iPad shot")
        return 3
    finally:
        shutil.rmtree(work, ignore_errors=True)


def cmd_fetch_shot(args):
    """For assistants (Claude): wait for a shot through plain git, no Actions API."""
    repo = args.repo
    deadline = time.time() + args.timeout
    last_ref = None
    while True:
        listed = sh(["git", "-C", repo, "ls-remote", "origin", f"refs/heads/{SHOTS_BRANCH}"], check=False, quiet=True, timeout=60)
        ref = listed.stdout.split()[0] if listed.returncode == 0 and listed.stdout.strip() else None
        if ref and ref != last_ref:
            fetched = sh(["git", "-C", repo, "fetch", "-q", "--depth", "1", "origin", f"+refs/heads/{SHOTS_BRANCH}:refs/shots/current"],
                         check=False, quiet=True, timeout=120)
            if fetched.returncode == 0:
                last_ref = ref
                names = sh(["git", "-C", repo, "ls-tree", "--name-only", "refs/shots/current", "shots/"], check=False, quiet=True).stdout.split()
                wanted = None
                if args.sha:
                    matches = [name.split("/", 1)[1] for name in names if name.split("/", 1)[1].startswith(args.sha)]
                    wanted = matches[0] if len(matches) == 1 else None
                else:
                    latest = sh(["git", "-C", repo, "show", "refs/shots/current:latest.json"], check=False, quiet=True)
                    wanted = json.loads(latest.stdout).get("sha") if latest.returncode == 0 else None
                if wanted:
                    proof = json.loads(sh(["git", "-C", repo, "show", f"refs/shots/current:shots/{wanted}/proof.json"], quiet=True).stdout)
                    if not args.build_run_id or str(args.build_run_id) in (str(proof.get("build_run_id")), str(proof.get("ci_run_id"))):
                        extract_shot(repo, "refs/shots/current", wanted, args.dest)
                        print(json.dumps(proof, ensure_ascii=False, indent=2))
                        return 0 if proof.get("status") == "PASS" else 1
        if time.time() >= deadline:
            log("No shot yet")
            return 3
        time.sleep(args.interval)


def cmd_check_raw(args):
    level = check_raw(args.path, allow_strip=args.strip)
    print(f"Orientation top-margin mean red level: {level:.1f}")
    if level < LETTERBOX_LIMIT:
        print("NOT_ROTATED: the screen is portrait-letterboxed", file=sys.stderr)
        return 1
    print("Orientation verified: no portrait letterbox")
    return 0


def cmd_summarize(args):
    proof = read_json(os.path.join(args.out, "proof.json"))
    if not proof:
        print("### iPad screenshot: no proof.json")
        return 0
    lines = [
        f"### iPad 12.9 landscape/dark: {proof.get('status')} ({proof.get('mode')}, {proof.get('source')})",
        f"- PR head `{(proof.get('pr_sha') or '')[:12]}`, build run {proof.get('build_run_id')}, appearance {proof.get('appearance')}",
    ]
    for shot in proof.get("shots", []):
        lines.append(
            f"- `{shot['name']}`: red {shot['raw_red_level']}, rotation repairs {shot['rotation_repairs']}, "
            f"screenshot {shot['screenshot_sec']} s"
        )
    if proof.get("ci_run_to_shot_sec") is not None:
        lines.append(f"- PR CI run created → shot ready: **{proof['ci_run_to_shot_sec']} s**")
    if proof.get("build_sec") is not None:
        lines.append(f"- session build: {proof['build_sec']} s ({proof.get('built_ref')} {(proof.get('built_commit') or '')[:12]})")
    lines.append(f"- capture stage: {proof.get('capture_sec')} s")
    if proof.get("error"):
        lines.append(f"- error at `{proof.get('stage')}`: {proof['error']}")
    print("\n".join(lines))
    return 0


# --------------------------------------------------------------------------- warm session

def request_epoch(value):
    value = (value or "").strip()
    if value.isdigit():
        return int(value)
    if os.environ.get("GITHUB_EVENT_NAME") == "push":
        data = read_json(os.path.join(".github", "prewarm", "request.json")) or {}
        if isinstance(data.get("request_epoch"), int) and data["request_epoch"] > 0:
            return data["request_epoch"]
    return int(time.time())


def fetch_warm_app(token, state, timeline):
    """Recent successful CI build for the settle step (any recent app will do)."""
    gh = GitHub(token)
    try:
        runs = gh.get(f"/repos/{REPO}/actions/workflows/{CI_WORKFLOW_FILE}/runs?status=success&per_page=15", cache=False) or {}
        for run in runs.get("workflow_runs", []):
            artifact = find_app_artifact(gh, run["id"], cache=False)
            if not artifact:
                continue
            path = download_app_artifact(gh, artifact["id"], state_file(state, "warm-download"))
            write_text(state_file(state, "warm-app.source"), f"run {run['id']} {run.get('head_sha', '')[:12]} {run.get('created_at')}")
            os.replace(path, state_file(state, "warm-app.zip"))
            timeline.mark("session.warm_app_ready", build_run_id=run["id"])
            return
        timeline.mark("session.warm_app_missing")
    except Exception as error:
        log(f"warm-up app unavailable: {error}")
    write_text(state_file(state, "warm-app.none"), "none")


def shots_for_sha(gh, sha):
    """Per-task screens: optional .github/prewarm/shots.json at the PR head."""
    data = gh.get(f"/repos/{REPO}/contents/.github/prewarm/shots.json?ref={sha}", cache=False)
    if data and data.get("content"):
        try:
            return build_shots(spec=json.loads(base64.b64decode(data["content"]).decode("utf-8")))
        except (ValueError, KeyError) as error:
            log(f"shots.json ignored ({error}); using the default screen")
    return build_shots(names=DEFAULT_WARM_SHOTS)


class WarmSession:
    """One warm iPad for the whole task.

    For every new head SHA of an open prewarm/* PR: build the PR test-merge commit
    incrementally right here (warm DerivedData, no CI queue, no artifact round trip),
    install it on the already booted iPad and publish the verified shot to ci-shots.
    If the local build cannot run, the PR CI artifact of that SHA is used instead.
    """

    def __init__(self, args):
        self.args = args
        self.root = args.root
        self.state = os.path.join(self.root, "state")
        os.makedirs(self.state, exist_ok=True)
        self.token = token_from_env()
        self.gh = GitHub(self.token)
        self.run_id = os.environ.get("GITHUB_RUN_ID", "local")
        self.t0 = request_epoch(args.request_epoch)
        self.timeline = Timeline(os.path.join(self.root, "timeline.jsonl"), self.t0)
        self.local = not args.no_local_build
        self.tree = SourceTree(self.root)
        self.served = {}
        self.records = []
        self.capture_failures = 0
        self.started = time.time()
        self.last_activity = None
        self.last_request = self.started
        self.end_reason = None
        self.prepare = None

    def state_summary(self, state):
        prepare_lines = []
        for line in read_text(state_file(self.state, "timeline.jsonl")).splitlines():
            try:
                prepare_lines.append(json.loads(line))
            except ValueError:
                pass
        summary = {
            "state": state,
            "session_run_id": self.run_id,
            "request_epoch": self.t0,
            "started_utc": utc(self.started),
            "local_build": self.local,
            "prepare_status": read_text(state_file(self.state, "prepare.status")),
            "prepare_timeline": prepare_lines,
            "orientation": read_json(state_file(self.state, "orientation.json")),
            "served": self.records,
            "end_reason": self.end_reason,
            "idle_minutes": self.args.idle_minutes,
            "api_remaining": self.gh.remaining,
            "updated_utc": utc(),
        }
        if summary["prepare_status"] == "FAILED":
            summary["prepare_error"] = read_text(state_file(self.state, "prepare.error"))
            summary["prepare_log_tail"] = read_text(os.path.join(self.root, "prepare.log"))[-4000:]
        prebuild_log = read_text(state_file(self.state, "prebuild.log"))
        if prebuild_log and not any(line.get("phase") == "settle.base_built" and line.get("kind") == "ok" for line in prepare_lines):
            summary["prebuild_log_tail"] = prebuild_log[-3000:]
        return summary

    def publish_state(self, state):
        try:
            publish_session(self.token, self.run_id, self.state_summary(state))
        except Exception as error:
            log(f"session state not published: {error}")

    def start(self):
        self.timeline.mark("session.start", run_id=self.run_id, local_build=self.local,
                           idle_minutes=self.args.idle_minutes, wait_first_minutes=self.args.wait_first_minutes)
        command = [sys.executable, os.path.abspath(__file__), "prepare", "--state", self.state,
                   "--visual", "--settle", "--t0", str(self.t0)]
        if self.local:
            command += ["--src-root", self.root]
        log_handle = open(os.path.join(self.root, "prepare.log"), "w", encoding="utf-8")
        self.prepare = subprocess.Popen(command, stdout=log_handle, stderr=subprocess.STDOUT)
        threading.Thread(target=fetch_warm_app, args=(self.token, self.state, self.timeline), daemon=True).start()

    def absorb_requests(self):
        """Another warm request while we run: serve it here instead of booting twice."""
        for run in warm_runs(self.gh):
            if str(run["id"]) == str(self.run_id) or run.get("status") not in WAITING_RUN_STATES:
                continue
            mode = run_mode(run)
            if mode in ("restart", "stop"):
                self.end_reason = f"{mode} requested by run {run['id']}"
                return False
            try:
                self.gh.post(f"/repos/{REPO}/actions/runs/{run['id']}/cancel")
                self.last_request = time.time()
                if self.last_activity is not None:
                    self.last_activity = self.last_request
                self.timeline.mark("session.request_absorbed", run_id=run["id"], event=run.get("event"), ref=run.get("head_branch"))
            except Exception as error:
                log(f"cannot absorb run {run['id']}: {error}")
        return True

    def candidates(self):
        pulls = self.gh.get(f"/repos/{REPO}/pulls?state=open&per_page=50") or []
        result = []
        for pr in pulls:
            head = pr.get("head") or {}
            if not head.get("ref", "").startswith(WARM_BRANCH_PREFIX):
                continue
            if (pr.get("base") or {}).get("ref") != "main" or (head.get("repo") or {}).get("full_name") != REPO:
                continue
            result.append(pr)
        result.sort(key=lambda pr: pr.get("updated_at", ""), reverse=True)
        return result

    def next_work(self):
        for pr in self.candidates():
            if pr["head"]["sha"] not in self.served:
                return pr, pr["head"]["sha"]
        return None

    def resolve_build_commit(self, number, sha):
        """The PR test-merge commit PR CI checks out, once GitHub has made it for sha."""
        deadline = time.time() + 30
        while time.time() < deadline:
            try:
                merge = self.tree.fetch(f"refs/pull/{number}/merge")
                parents = self.tree.parents(merge)
                if len(parents) == 2 and parents[1] == sha:
                    return merge, "merge"
            except CommandError as error:
                log(f"merge ref not ready: {error}")
            time.sleep(1.5)
        return self.tree.fetch(sha), "head"

    def build_locally(self, number, sha, work):
        commit, ref = self.resolve_build_commit(number, sha)
        self.tree.checkout(commit)
        self.timeline.mark("sha.checked_out", sha=sha[:12], built_commit=commit[:12], ref=ref)
        kind, seconds, lines = self.tree.build(os.path.join(work, "build.log"))
        self.timeline.mark("sha.built", sha=sha[:12], kind=kind, build_sec=round(seconds, 1))
        app = self.tree.package(os.path.join(work, "pkg")) if kind == "ok" else None
        return {"kind": kind, "commit": commit, "ref": ref, "seconds": round(seconds, 1), "lines": lines, "app": app}

    def wait_ci_artifact(self, sha, timeout=900):
        deadline = time.time() + timeout
        while time.time() < deadline:
            run = find_ci_run(self.gh, sha)
            if run:
                artifact = find_app_artifact(self.gh, run["id"])
                if artifact:
                    return run, artifact
                if build_failed(self.gh, run["id"]):
                    return run, None
            time.sleep(self.gh.poll_interval())
        return None, None

    def head_moved(self, number, sha):
        current = self.gh.get(f"/repos/{REPO}/pulls/{number}", cache=False) or {}
        return (current.get("head") or {}).get("sha") != sha

    def serve(self, pr, sha):
        number = pr["number"]
        seen = self.timeline.mark("sha.seen", sha=sha[:12], pr=number)
        work = os.path.join(self.root, "shots", sha[:12])
        out = os.path.join(work, "out")
        os.makedirs(work, exist_ok=True)
        meta = {
            "mode": "warm", "pr_sha": sha, "pr_number": number, "head_ref": pr["head"]["ref"],
            "session_run_id": self.run_id, "t0": self.t0,
        }
        prepared = wait_state(self.state, "prepare.status", {"READY", "FAILED"}, 1500)
        if prepared != "READY":
            log(f"prepare status {prepared}; capturing anyway")
        source = None
        if self.local:
            try:
                result = self.build_locally(number, sha, work)
            except Exception as error:
                result = {"kind": "infra", "commit": None, "ref": None, "seconds": None, "lines": [str(error)[:300]], "app": None}
            meta.update(source="session-build", built_commit=result["commit"], built_ref=result["ref"], build_sec=result["seconds"])
            if result["kind"] == "ok":
                source = result["app"]
            elif result["kind"] == "compile":
                proof = failure_proof(out, meta, "build", "Swift compile errors (session build):\n" + "\n".join(result["lines"]))
                return self.finish(out, sha, number, proof, seen)
            else:
                self.timeline.mark("sha.local_build_unavailable", sha=sha[:12], detail=result["lines"][:3])
        if source is None:
            run, artifact = self.wait_ci_artifact(sha)
            if not artifact:
                proof = failure_proof(out, meta, "ci-artifact", "No app for this SHA: the PR CI build failed or did not finish")
                return self.finish(out, sha, number, proof, seen)
            source = download_app_artifact(self.gh, artifact["id"], os.path.join(work, "download"))
            meta.update(source="ci-artifact", build_run_id=run["id"], artifact_id=artifact["id"], ci_run_created=run["created_at"],
                        built_commit=None, built_ref=None, build_sec=None)
        if self.head_moved(number, sha):
            self.timeline.mark("sha.stale", sha=sha[:12], pr=number)
            return "STALE"
        proof = capture(self.state, source, out, shots_for_sha(self.gh, sha), meta, install_early=False)
        return self.finish(out, sha, number, proof, seen)

    def finish(self, out, sha, number, proof, seen):
        run = find_ci_run(self.gh, sha)
        ready = proof.get("shot_ready_epoch") or time.time()
        proof["seen_to_shot_sec"] = round(ready - seen, 1)
        if run:
            proof["ci_run_id"] = run["id"]
            proof["ci_run_created"] = run["created_at"]
            proof["ci_run_to_shot_sec"] = round(ready - parse_utc(run["created_at"]), 1)
        write_json(os.path.join(out, "proof.json"), proof)
        try:
            published = publish_capture(self.token, out, sha, f"warm PR #{number}")
        except Exception as error:
            log(f"publish failed: {error}")
            published = False
        record = {
            "sha": sha, "pr": number, "status": proof["status"], "stage": proof.get("stage"),
            "source": proof.get("source"), "build_sec": proof.get("build_sec"),
            "capture_sec": proof.get("capture_sec"), "seen_to_shot_sec": proof.get("seen_to_shot_sec"),
            "ci_run_to_shot_sec": proof.get("ci_run_to_shot_sec"), "published": published,
        }
        if run:
            record["ci_run_to_published_sec"] = round(time.time() - parse_utc(run["created_at"]), 1)
        self.records.append(record)
        self.timeline.mark("sha.published" if published else "sha.publish_failed", **record)
        return proof["status"] if proof.get("stage") != "build" else "COMPILE_ERROR"

    def loop(self):
        announced = False
        next_absorb = 0
        while True:
            now = time.time()
            if not announced and read_text(state_file(self.state, "prepare.status")) in ("READY", "FAILED"):
                announced = True
                self.timeline.mark("session.ready", prepare_status=read_text(state_file(self.state, "prepare.status")))
                self.publish_state("ready")
            if now >= next_absorb:
                next_absorb = now + 15
                if not self.absorb_requests():
                    break
            work = self.next_work()  # waiting work always wins over an idle exit
            if work is None:
                if self.last_activity is None:
                    if now - max(self.started, self.last_request) > self.args.wait_first_minutes * 60:
                        self.end_reason = "no prewarm PR arrived"
                        break
                elif now - self.last_activity > self.args.idle_minutes * 60:
                    self.end_reason = "idle"
                    break
                time.sleep(self.gh.poll_interval())
                continue
            pr, sha = work
            self.served[sha] = "IN_PROGRESS"
            try:
                status = self.serve(pr, sha)
            except Exception as error:
                status = "ERROR"
                self.timeline.mark("sha.error", sha=sha[:12], error=str(error)[:300])
            self.served[sha] = status
            self.last_activity = time.time()
            # A Swift compile error is the task's own problem: keep serving fixes.
            self.capture_failures = self.capture_failures + 1 if status in ("FAIL", "ERROR") else 0
            if self.capture_failures >= 2:
                self.end_reason = "two consecutive capture failures (PR CI will fall back)"
                break

    def close(self):
        self.timeline.mark("session.end", reason=self.end_reason, served=len(self.records))
        if self.prepare and self.prepare.poll() is None:
            self.prepare.terminate()
        summary = self.state_summary("ended")
        write_json(os.path.join(self.root, "summary.json"), summary)
        self.publish_state("ended")
        step_summary = os.environ.get("GITHUB_STEP_SUMMARY")
        if step_summary:
            lines = [f"### Warm iPad session: {self.end_reason}", f"- prepare: {summary['prepare_status']}, local build: {self.local}"]
            for record in self.records:
                lines.append(
                    f"- PR #{record['pr']} `{record['sha'][:12]}`: {record['status']} ({record['source']}), build "
                    f"{record['build_sec']} s, capture {record['capture_sec']} s, PR CI run → shot {record['ci_run_to_shot_sec']} s"
                )
            with open(step_summary, "a", encoding="utf-8") as stream:
                stream.write("\n".join(lines) + "\n")


def cmd_session(args):
    session = WarmSession(args)
    session.start()
    try:
        session.loop()
    finally:
        session.close()
    return 0


# --------------------------------------------------------------------------- CLI

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("prepare")
    p.add_argument("--state", required=True)
    p.add_argument("--visual", action="store_true", help="dark appearance + Simulator GUI + Rotate Right")
    p.add_argument("--settle", action="store_true", help="warm-up install/launch/screenshot (warm session)")
    p.add_argument("--t0", type=float, default=None)
    p.add_argument("--src-root", default=None, help="warm session: prebuild main here for incremental PR builds")
    p.set_defaults(func=cmd_prepare)

    p = sub.add_parser("capture")
    p.add_argument("--state", required=True)
    p.add_argument("--zip", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--shots", default=DEFAULT_WARM_SHOTS)
    p.add_argument("--shots-file", default=None)
    p.add_argument("--mode", default="A")
    p.add_argument("--pr-sha", default=None)
    p.add_argument("--pr-number", default=None)
    p.add_argument("--head-ref", default=None)
    p.add_argument("--build-run-id", default=None)
    p.add_argument("--ci-run-created", default=None)
    p.add_argument("--install-early", action="store_true", help="install while dark/rotation are still being prepared")
    p.set_defaults(func=cmd_capture)

    p = sub.add_parser("wait-artifact")
    p.add_argument("--run-id", required=True)
    p.add_argument("--dest", required=True)
    p.add_argument("--timeout", type=int, default=900)
    p.set_defaults(func=cmd_wait_artifact)

    p = sub.add_parser("session")
    p.add_argument("--root", required=True)
    p.add_argument("--idle-minutes", type=float, default=25)
    p.add_argument("--wait-first-minutes", type=float, default=45)
    p.add_argument("--request-epoch", default="")
    p.add_argument("--no-local-build", action="store_true", help="always use the PR CI artifact")
    p.set_defaults(func=cmd_session)

    p = sub.add_parser("publish")
    p.add_argument("--out", required=True)
    p.add_argument("--sha", required=True)
    p.add_argument("--label", default="shot")
    p.set_defaults(func=cmd_publish)

    p = sub.add_parser("verify-shot")
    p.add_argument("--sha", required=True)
    p.add_argument("--build-run-id", required=True)
    p.add_argument("--built-commit", default=None, help="GITHUB_SHA of the PR CI run (test-merge commit)")
    p.add_argument("--dest", required=True)
    p.add_argument("--timeout", type=int, default=900)
    p.add_argument("--grace", type=int, default=15)
    p.set_defaults(func=cmd_verify_shot)

    p = sub.add_parser("fetch-shot")
    p.add_argument("--sha", default=None, help="full or abbreviated PR head SHA; default: latest")
    p.add_argument("--build-run-id", default=None)
    p.add_argument("--dest", required=True)
    p.add_argument("--repo", default=".")
    p.add_argument("--timeout", type=int, default=900)
    p.add_argument("--interval", type=float, default=3)
    p.set_defaults(func=cmd_fetch_shot)

    p = sub.add_parser("check-raw")
    p.add_argument("path")
    p.add_argument("--strip", action="store_true")
    p.set_defaults(func=cmd_check_raw)

    p = sub.add_parser("summarize")
    p.add_argument("--out", required=True)
    p.set_defaults(func=cmd_summarize)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
