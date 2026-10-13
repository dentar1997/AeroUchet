#!/usr/bin/env python3
"""Keep an already-initialised iPad Simulator between GitHub Actions runs.

A brand-new simulator spends minutes on its first boot (data migration, caches),
and the first commands afterwards are slow. This script stages a prepared device
(and CoreSimulator's caches) for actions/cache, and puts it back on a new runner.

  key                      print a cache key (runner image + iOS runtime build)
  stage   --state S --dest D   shut the prepared device down and copy it to D
  restore --src D --state S    copy it back and make ci_ipad.py reuse it
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ci_ipad  # noqa: E402

HOME = os.path.expanduser("~")
DEVICES = os.path.join(HOME, "Library/Developer/CoreSimulator/Devices")
CACHE_DIRS = [os.path.join(HOME, "Library/Developer/CoreSimulator/Caches")]
CACHE_VERSION = "v1"


def du(path):
    if not os.path.exists(path):
        return 0
    done = subprocess.run(["du", "-sk", path], capture_output=True, text=True)
    return int(done.stdout.split()[0]) * 1024 if done.returncode == 0 and done.stdout else 0


def ditto(src, dst):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    ci_ipad.sh(["ditto", src, dst], timeout=1200, quiet=True)


def runtime_build():
    data = json.loads(ci_ipad.sh(["xcrun", "simctl", "list", "runtimes", "-j"], quiet=True, timeout=240).stdout)
    builds = [r.get("buildversion", "") for r in data.get("runtimes", [])
              if r.get("isAvailable") and "iOS" in r.get("name", "")
              and r.get("version", "0").split(".")[0].isdigit() and int(r.get("version", "0").split(".")[0]) >= 26]
    return sorted(builds)[-1] if builds else "unknown"


def cmd_key(args):
    image = os.environ.get("ImageOS", "macos") + "-" + os.environ.get("ImageVersion", "unknown")
    print(f"ipad129-{CACHE_VERSION}-{image}-{runtime_build()}")
    return 0


def cmd_stage(args):
    udid = ci_ipad.read_text(ci_ipad.state_file(args.state, "device-udid.txt"))
    if not udid:
        sys.exit("no prepared device in state")
    started = time.time()
    ci_ipad.sh(["xcrun", "simctl", "shutdown", udid], check=False, timeout=300)
    shutil.rmtree(args.dest, ignore_errors=True)
    os.makedirs(args.dest)
    ditto(os.path.join(DEVICES, udid), os.path.join(args.dest, "device", udid))
    sizes = {"device": du(os.path.join(DEVICES, udid))}
    for index, path in enumerate(CACHE_DIRS):
        if os.path.isdir(path):
            ditto(path, os.path.join(args.dest, f"caches{index}"))
            sizes[f"caches{index}"] = du(path)
    meta = {"udid": udid, "device": ci_ipad.read_json(ci_ipad.state_file(args.state, "device.json")),
            "sizes_bytes": sizes, "stage_sec": round(time.time() - started, 1), "staged_utc": ci_ipad.utc()}
    ci_ipad.write_json(os.path.join(args.dest, "meta.json"), meta)
    print(json.dumps(meta, ensure_ascii=False, indent=1))
    return 0


def cmd_restore(args):
    meta = ci_ipad.read_json(os.path.join(args.src, "meta.json"))
    if not meta:
        print("no cached device: normal fresh boot")
        return 0
    started = time.time()
    udid = meta["udid"]
    ditto(os.path.join(args.src, "device", udid), os.path.join(DEVICES, udid))
    for index, path in enumerate(CACHE_DIRS):
        cached = os.path.join(args.src, f"caches{index}")
        if os.path.isdir(cached):
            ditto(cached, path)
    listed = ci_ipad.sh(["xcrun", "simctl", "list", "devices", "-j"], quiet=True, timeout=240).stdout
    if udid not in listed:
        # CoreSimulatorService already scanned the device set: make it rescan.
        subprocess.run(["killall", "-9", "com.apple.CoreSimulator.CoreSimulatorService"], capture_output=True)
        time.sleep(3)
        listed = ci_ipad.sh(["xcrun", "simctl", "list", "devices", "-j"], quiet=True, timeout=240).stdout
    if udid not in listed:
        print("cached device not recognised: normal fresh boot")
        return 0
    os.makedirs(args.state, exist_ok=True)
    ci_ipad.write_text(ci_ipad.state_file(args.state, "device-udid.txt"), udid)
    # The cached device already has the app: install_app() must remove it first.
    ci_ipad.write_text(ci_ipad.state_file(args.state, "app-installed"), "cached")
    ci_ipad.write_json(ci_ipad.state_file(args.state, "device.json"), dict(meta.get("device") or {}, how="restored from cache"))
    print(f"restored device {udid} in {time.time() - started:.1f} s")
    return 0


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("key").set_defaults(func=cmd_key)
    p = sub.add_parser("stage"); p.add_argument("--state", required=True); p.add_argument("--dest", required=True); p.set_defaults(func=cmd_stage)
    p = sub.add_parser("restore"); p.add_argument("--src", required=True); p.add_argument("--state", required=True); p.set_defaults(func=cmd_restore)
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
