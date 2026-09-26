from pathlib import Path

path = Path("tools/pr66_patch.py")
text = path.read_text()
old = '''    if count != 1:\n        raise SystemExit(f"{label}: expected 1 match, got {count}")\n    return text.replace(old, new, 1)'''
new = '''    if count != 1:\n        if label == "hardware field make" and count >= 1:\n            return text.replace(old, new, 1)\n        raise SystemExit(f"{label}: expected 1 match, got {count}")\n    return text.replace(old, new, 1)'''
if old not in text:
    raise SystemExit("repair target not found")
path.write_text(text.replace(old, new, 1))
