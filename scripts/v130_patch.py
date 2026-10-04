from pathlib import Path

p = Path("AppViews.swift")
text = p.read_text()
old = '''        guard !number.isEmpty else { return }\n        draft[index].legNumber = number\n        draft[index].flightNumber = number\n\n        let previousEnd = index > 0 ? times(for: draft[index - 1]).engineOff : nil'''
new = '''        guard !number.isEmpty else { return }\n\n        let previousEnd = index > 0 ? times(for: draft[index - 1]).engineOff : nil'''
if old not in text:
    raise RuntimeError("autofill canonicalization block not found")
text = text.replace(old, new, 1)
p.write_text(text)
print("v130 leading-zero fix applied")
