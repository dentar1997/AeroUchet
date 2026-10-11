#!/usr/bin/env python3
"""Detect the letterboxed, NOT actually rotated, Simulator framebuffer.

simctl screenshots remain 2048x2732 even if the real iPad landscape UI has
been rotated in Simulator.app. A false-positive portrait frame has solid black
margins at the top. This checks raw pixels without third-party dependencies.
"""
import struct
import sys
import zlib


def top_band_red_level(path: str, sample_y: int = 96) -> float:
    with open(path, "rb") as stream:
        data = stream.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("Not a PNG screenshot")

    offset = 8
    compressed = bytearray()
    dimensions = None
    while offset + 12 <= len(data):
        size = struct.unpack_from(">I", data, offset)[0]
        tag = data[offset + 4:offset + 8]
        payload = data[offset + 8:offset + 8 + size]
        offset += size + 12
        if tag == b"IHDR":
            width, height, depth, color, method, filtering, interlace = struct.unpack(">IIBBBBB", payload)
            if depth != 8 or color not in (2, 6) or interlace:
                raise ValueError("Unsupported screenshot format")
            dimensions = (width, height, 3 if color == 2 else 4)
        elif tag == b"IDAT":
            compressed.extend(payload)
        elif tag == b"IEND":
            break

    if dimensions is None:
        raise ValueError("Missing PNG header")
    width, height, components = dimensions
    if (width, height) != (2048, 2732):
        raise ValueError(f"Unexpected raw dimensions {width}x{height}")

    decompressed = zlib.decompress(compressed)
    stride = width * components
    pos = 0
    above = bytearray(stride)
    for _ in range(sample_y + 1):
        filter_type = decompressed[pos]
        pos += 1
        row = bytearray(decompressed[pos:pos + stride])
        pos += stride
        if filter_type == 1:
            for i in range(stride):
                row[i] = (row[i] + (row[i - components] if i >= components else 0)) & 255
        elif filter_type == 2:
            for i in range(stride):
                row[i] = (row[i] + above[i]) & 255
        elif filter_type in (3, 4):
            for i in range(stride):
                a = row[i - components] if i >= components else 0
                b = above[i]
                if filter_type == 3:
                    predictor = (a + b) // 2
                else:
                    c = above[i - components] if i >= components else 0
                    pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                    predictor = a if pa <= pb and pa <= pc else b if pb <= pc else c
                row[i] = (row[i] + predictor) & 255
        elif filter_type != 0:
            raise ValueError("Invalid PNG row filter")
        above = row

    return sum(row[i] for i in range(0, stride, components * 8)) / (width // 8)


if __name__ == "__main__":
    level = top_band_red_level(sys.argv[1])
    print(f"Orientation top-margin mean red level: {level:.1f}")
    if level < 9:
        print("NOT_ROTATED: the screen is portrait-letterboxed", file=sys.stderr)
        sys.exit(1)
    print("Orientation verified: no portrait letterbox")
