from pathlib import Path

path = Path("AppViews.swift")
text = path.read_text()
old = '''        : Color.primary

        ZStack(alignment: .leading) {'''
new = '''        : Color.primary

        return ZStack(alignment: .leading) {'''
count = text.count(old)
if count != 1:
    raise SystemExit(f"expected exactly one stable editor return target, found {count}")
path.write_text(text.replace(old, new, 1))
