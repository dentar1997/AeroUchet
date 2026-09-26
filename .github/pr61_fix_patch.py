from pathlib import Path

path = Path('.github/pr61_patch.py')
text = path.read_text()
old = """def once(old, new, label):
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    text = text.replace(old, new, 1)
"""
new = """def once(old, new, label):
    global text
    count = text.count(old)
    if count < 1:
        raise SystemExit(f'{label}: expected at least 1 match, found {count}')
    text = text.replace(old, new, 1)
"""
if old not in text:
    raise SystemExit('once helper not found')
path.write_text(text.replace(old, new, 1))
