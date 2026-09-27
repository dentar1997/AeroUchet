from pathlib import Path
import re

path = Path('InlineWheelTestView.swift')
text = path.read_text()
pattern = r'\n// MARK: - Test 3: full editor prototype\n.*?\n// MARK: - Shared prototype shell'
text, count = re.subn(pattern, '\n// MARK: - Shared prototype shell', text, flags=re.S)
if count != 1:
    raise SystemExit(f'cleanup count={count}')
path.write_text(text)
