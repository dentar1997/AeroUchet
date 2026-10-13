#!/usr/bin/env python3
"""Per-file Swift frontend timings from -stats-output-dir (one job per file).

Usage: compile_stats.py stats_dir build.log report.txt
"""
import collections, glob, json, os, re, sys

stats_dir, build_log, out = sys.argv[1:4]
rows = []
keys = collections.Counter()
for path in glob.glob(os.path.join(stats_dir, "*.json")):
    try:
        data = json.load(open(path, encoding="utf-8"))
    except ValueError:
        continue
    name = os.path.basename(path)
    m = re.search(r"-([^-]+?\.swift)-", name)
    src = m.group(1) if m else name
    wall = 0.0
    phases = {}
    for key, value in data.items():
        if not isinstance(value, (int, float)):
            continue
        if key.startswith("time.") and key.endswith(".wall"):
            phase = key[len("time."):-len(".wall")]
            phases[phase] = value
            keys[phase] += value
    # Total = sum of the top-level phases that do not nest: sema, SILGen, SIL opt, IRGen, LLVM.
    top = [v for k, v in phases.items() if k in (
        "swift.Type checking and Semantic analysis", "swift.SILGen", "swift.SIL optimization",
        "swift.IRGen", "swift.LLVM pipeline", "swift.LLVM optimization", "swift.LLVM output",
        "swift.Parsing", "swift.Import resolution", "swift.Serialization, swiftmodule",
        "swift.SIL verification, pre-optimization", "swift.SIL verification, post-optimization")]
    wall = sum(top) if top else (max(phases.values()) if phases else 0.0)
    m2 = re.search(r"swift-frontend-([^-]+?)-all-", name)
    if m2 and not m:
        src = m2.group(1)
    rows.append((wall, src, phases, name))
rows.sort(reverse=True)
total = sum(r[0] for r in rows)
lines = [f"Swift frontend jobs: {len(rows)}; sum of per-file wall time: {total:.1f} s (arm64, -disable-batch-mode, -Onone)", "", "Per file (total frontend wall time):"]
for wall, src, phases, name in rows:
    top = sorted(((v, k) for k, v in phases.items() if k != "Frontend"), reverse=True)[:4]
    lines.append(f"  {wall:6.2f} s {100*wall/total if total else 0:5.1f}%  {src:42s} " + ", ".join(f"{k} {v:.1f}" for v, k in top))
lines += ["", "Phase totals across files:"]
for k, v in keys.most_common(40):
    lines.append(f"  {v:7.1f} s  {k}")
summary = [l for l in open(build_log, encoding="utf-8", errors="replace") if re.search(r"\| [0-9.]+ seconds", l) or "BUILD SUCCEEDED" in l or "BUILD FAILED" in l]
lines += ["", "xcodebuild timing summary:"] + ["  " + l.strip() for l in summary[:15]]
if not rows:
    sample = sorted(glob.glob(os.path.join(stats_dir, "*")))[:5]
    lines += ["", f"NO STATS FILES; dir listing: {sample}"]
open(out, "w", encoding="utf-8").write("\n".join(lines) + "\n")
print("\n".join(lines[:50]))
