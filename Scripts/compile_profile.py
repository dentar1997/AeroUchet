#!/usr/bin/env python3
"""Aggregate -debug-time-function-bodies output of a Swift build log.

Usage: compile_profile.py build.log report.txt
Writes per-file type-check totals, slowest functions and slow-expression warnings.
"""
import collections, re, sys

log, out = sys.argv[1], sys.argv[2]
body = re.compile(r"^\s*(\d+(?:\.\d+)?)ms\s+(/[^:]+\.swift):(\d+):(\d+)\s+(.*)$")
slow = re.compile(r"(/[^:]+\.swift):(\d+):\d+: warning: (expression took \d+ms to type-check.*|(?:instance method|getter|global function|static method|initializer|closure|.*) '.*' took \d+ms to type-check.*)")
per_file = collections.Counter()
funcs = {}
warnings = set()
for line in open(log, encoding="utf-8", errors="replace"):
    m = body.match(line)
    if m:
        ms, path, row, _, what = float(m.group(1)), m.group(2), m.group(3), m.group(4), m.group(5)
        name = path.rsplit("/", 1)[-1]
        key = (name, int(row), what.strip()[:90])
        if ms > funcs.get(key, 0):
            funcs[key] = ms
        continue
    w = slow.search(line)
    if w:
        warnings.add((w.group(1).rsplit("/", 1)[-1], int(w.group(2)), w.group(3)[:160]))
for (name, row, what), ms in funcs.items():
    per_file[name] += ms
total = sum(per_file.values())
lines = [f"Type-check time of function bodies: {total/1000:.1f} s total (arm64, one pass)", "", "Per file:"]
for name, ms in per_file.most_common():
    lines.append(f"  {ms/1000:7.2f} s  {100*ms/total if total else 0:5.1f}%  {name}")
lines += ["", "Slowest 40 functions:"]
for (name, row, what), ms in sorted(funcs.items(), key=lambda kv: -kv[1])[:40]:
    lines.append(f"  {ms:8.0f} ms  {name}:{row}  {what}")
lines += ["", f"Slow-expression warnings ({len(warnings)}):"]
for name, row, text in sorted(warnings, key=lambda w: -int(re.search(r'(\d+)ms', w[2]).group(1)))[:60]:
    lines.append(f"  {name}:{row}  {text}")
open(out, "w", encoding="utf-8").write("\n".join(lines) + "\n")
print("\n".join(lines[:45]))
