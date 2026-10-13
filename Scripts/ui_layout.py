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
BASELINE_TOLERANCE = 5.0  # pt: descenders (р, у, д) alone move the ink bottom by ~3.5 pt


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
        vertical = []
        for a, b in blobs:
            column = mask.crop((a, top, b + 1, bottom + 1)).resize((1, bottom - top + 1), Image.BOX).tobytes()
            rows = [i for i, v in enumerate(column) if v > 0]
            vertical.append([round((top + rows[0]) / scale, 1), round((top + rows[-1]) / scale, 1)] if rows else [None, None])
        result.append({
            "y_pt": round(top / scale, 1),
            "h_pt": round((bottom - top + 1) / scale, 1),
            "blobs_pt": [[round(a / scale, 1), round(b / scale, 1), round((a + b) / 2 / scale, 1)] for a, b in blobs],
            "blobs_y_pt": vertical,
        })
    return {"size_pt": [width / scale, height / scale], "bands": result}


def column_checks(layout, tolerance):
    """Neighbouring rows with the same number of columns that look like a table:
    a column counts as aligned if its centre, left or right edge matches within
    the tolerance. Only pairs where most columns align are reported (otherwise the
    rows are ordinary text), and the columns that do not align are flagged."""
    checks = []
    bands = layout["bands"]
    for first, second in zip(bands, bands[1:]):
        a, b = first["blobs_pt"], second["blobs_pt"]
        if len(a) != len(b) or len(a) < 3:
            continue
        cols = []
        for x, y in zip(a, b):
            deltas = {"centre": y[2] - x[2], "left": y[0] - x[0], "right": y[1] - x[1]}
            mode, delta = min(deltas.items(), key=lambda kv: abs(kv[1]))
            cols.append({"mode": mode, "delta_pt": round(delta, 1), "ok": abs(delta) <= tolerance})
        aligned = sum(c["ok"] for c in cols)
        if aligned < max(2, round(0.6 * len(cols))):
            continue
        worst = max((c["delta_pt"] for c in cols), key=abs)
        checks.append({
            "rows_y_pt": [first["y_pt"], second["y_pt"]],
            "columns": len(cols),
            "per_column": cols,
            "off_columns": [i + 1 for i, c in enumerate(cols) if not c["ok"]],
            "worst_pt": worst,
            "ok": aligned == len(cols),
        })
    return checks


def baseline_checks(layout, tolerance):
    """Rows of >= 3 same-size elements (e.g. numbers in a row of cards) should sit on
    one line: flag rows whose bottoms differ by more than the tolerance."""
    checks = []
    for band in layout["bands"]:
        items = [(x, y) for x, y in zip(band["blobs_pt"], band["blobs_y_pt"]) if y[0] is not None]
        if len(items) < 3:
            continue
        heights = sorted(y[1] - y[0] for _, y in items)
        typical = heights[len(heights) // 2]
        same = [(x, y) for x, y in items if typical and abs((y[1] - y[0]) - typical) <= 0.2 * typical]
        if len(same) < 3:
            continue
        bottoms = [y[1] for _, y in same]
        spread = round(max(bottoms) - min(bottoms), 1)
        if spread > tolerance:
            checks.append({"row_y_pt": band["y_pt"], "elements": len(same), "bottom_spread_pt": spread,
                           "bottoms_pt": bottoms, "x_pt": [x[2] for x, _ in same]})
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
    layout["baseline_checks"] = baseline_checks(layout, max(args.tolerance, BASELINE_TOLERANCE))
    lines = [f"Screen {layout['size_pt'][0]:g}×{layout['size_pt'][1]:g} pt, {len(layout['bands'])} text rows"]
    for band in layout["bands"]:
        centres = ", ".join(f"{c[2]:g}" for c in band["blobs_pt"])
        lines.append(f"  y={band['y_pt']:7.1f} h={band['h_pt']:4.1f}  {len(band['blobs_pt'])} blobs, centres x: {centres}")
    lines.append("Column alignment of table-like row pairs (c=centre, l=left, r=right edge):")
    for check in layout["column_checks"] or []:
        mark = "OK " if check["ok"] else "OFF"
        detail = ", ".join(f"{c['mode'][0]}{c['delta_pt']:+g}" for c in check["per_column"])
        off = f" — off columns {check['off_columns']}" if check["off_columns"] else ""
        lines.append(f"  {mark} rows y={check['rows_y_pt'][0]:g}/{check['rows_y_pt'][1]:g}: {detail} pt{off}")
    if not layout["column_checks"]:
        lines.append("  (no table-like row pairs found)")
    lines.append("Uneven rows — hints, check by eye (same-size elements whose bottoms differ > 5 pt):")
    for check in layout["baseline_checks"]:
        lines.append(f"  HINT row y={check['row_y_pt']:g}: {check['elements']} elements, bottoms differ by {check['bottom_spread_pt']:g} pt "
                     f"(x={check['x_pt']}, bottom={check['bottoms_pt']})")
    if not layout["baseline_checks"]:
        lines.append("  none")
    print("\n".join(lines))
    if args.json:
        with open(args.json, "w", encoding="utf-8") as stream:
            json.dump(layout, stream, ensure_ascii=False, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
