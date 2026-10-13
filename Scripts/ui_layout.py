#!/usr/bin/env python3
"""Automatic layout check of an iPad screenshot (dark theme), in points.

Finds horizontal text bands, splits each band into blobs (words/columns) and,
for every pair of neighbouring bands with the same number of blobs (>= 3),
compares their centres — e.g. a table header against its first rows. Prints a
report; `--json` writes machine-readable results. Requires Pillow.

Usage: ui_layout.py screenshot.png [--json out.json] [--scale 2] [--tolerance 2]
"""
import argparse
import json
import sys

try:
    from PIL import Image
except ImportError:  # the caller decides whether that matters
    Image = None

INK = 95          # luminance of text/icons on the dark UI (backgrounds are ~25–60)
ROW_GAP = 3       # px: rows closer than this belong to one band
BLOB_GAP = 26     # px: horizontal gaps narrower than this join words of one cell


def bands_and_blobs(path, scale):
    image = Image.open(path).convert("L")
    width, height = image.size
    mask = image.point(lambda v: 255 if v > INK else 0)
    data = mask.tobytes()
    ink_rows = [y for y in range(height) if data[y * width:(y + 1) * width].count(255) > 0]
    bands = []
    for y in ink_rows:
        if bands and y - bands[-1][1] <= ROW_GAP:
            bands[-1][1] = y
        else:
            bands.append([y, y])
    result = []
    for top, bottom in bands:
        if bottom - top < 6:            # separators and hairlines
            continue
        strip = mask.crop((0, top, width, bottom + 1)).resize((width, 1), Image.BOX).tobytes()
        cols = [x for x, v in enumerate(strip) if v > 0]
        blobs = []
        for x in cols:
            if blobs and x - blobs[-1][1] <= BLOB_GAP:
                blobs[-1][1] = x
            else:
                blobs.append([x, x])
        result.append({
            "y_pt": round(top / scale, 1),
            "h_pt": round((bottom - top + 1) / scale, 1),
            "blobs_pt": [[round(a / scale, 1), round(b / scale, 1), round((a + b) / 2 / scale, 1)] for a, b in blobs],
        })
    return {"size_pt": [width / scale, height / scale], "bands": result}


def column_checks(layout, tolerance):
    checks = []
    bands = layout["bands"]
    for first, second in zip(bands, bands[1:]):
        a, b = first["blobs_pt"], second["blobs_pt"]
        if len(a) != len(b) or len(a) < 3:
            continue
        deltas = [round(y[2] - x[2], 1) for x, y in zip(a, b)]
        worst = max(deltas, key=abs)
        checks.append({
            "rows_y_pt": [first["y_pt"], second["y_pt"]],
            "columns": len(a),
            "centre_delta_pt": deltas,
            "worst_pt": worst,
            "ok": abs(worst) <= tolerance,
        })
    return checks


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("png")
    parser.add_argument("--json")
    parser.add_argument("--scale", type=float, default=2.0)
    parser.add_argument("--tolerance", type=float, default=2.0)
    args = parser.parse_args()
    if Image is None:
        print("Pillow not installed: layout check skipped")
        return 0
    layout = bands_and_blobs(args.png, args.scale)
    layout["column_checks"] = column_checks(layout, args.tolerance)
    lines = [f"Screen {layout['size_pt'][0]:g}×{layout['size_pt'][1]:g} pt, {len(layout['bands'])} text rows"]
    for band in layout["bands"]:
        centres = ", ".join(f"{c[2]:g}" for c in band["blobs_pt"])
        lines.append(f"  y={band['y_pt']:7.1f} h={band['h_pt']:4.1f}  {len(band['blobs_pt'])} blobs, centres x: {centres}")
    lines.append("Column alignment (neighbouring rows with the same number of columns):")
    for check in layout["column_checks"] or []:
        mark = "OK " if check["ok"] else "OFF"
        lines.append(f"  {mark} rows y={check['rows_y_pt'][0]:g}/{check['rows_y_pt'][1]:g}: Δcentre {check['centre_delta_pt']} pt")
    if not layout["column_checks"]:
        lines.append("  (no table-like row pairs found)")
    print("\n".join(lines))
    if args.json:
        with open(args.json, "w", encoding="utf-8") as stream:
            json.dump(layout, stream, ensure_ascii=False, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
