#!/usr/bin/env python3
"""Защита личных данных в публичном репозитории AeroUchet.

Падает, если в отслеживаемых файлах есть:
  - личные файлы по расширению (.xls, .xlsx, .numbers, .ics, .pdf, видео, фото с iPhone);
  - ссылка календаря с токеном, webcal://, домены портала экипажей, параметр token=.
Личное хранится только в приватном AeroUchet-Private.
Исключения: служебная картинка Playgrounds и сами скрипты/workflow, где описаны шаблоны.
"""
import re, subprocess, sys

BAD_EXT = re.compile(r"\.(xls|xlsx|numbers|ics|pdf|mp4|mov|heic|m4a)$", re.I)
BAD_TEXT = [
    (re.compile(r"/calendar/ics/[A-Za-z0-9-]{12,}"), "ссылка ICS с токеном"),
    (re.compile(r"webcal://", re.I), "webcal-ссылка"),
    (re.compile(r"\bcrew\.[a-z0-9-]+\.(ru|com)\b", re.I), "домен портала экипажей"),
    (re.compile(r"[?&]token=[A-Za-z0-9_-]{8,}", re.I), "token= в ссылке"),
]
ALLOWED_FILES = {".swiftpm/playgrounds/DocumentThumbnail.png"}
SKIP_TEXT = (".github/scripts/privacy_guard.py", ".github/workflows/privacy-guard.yml")

files = subprocess.run(["git", "ls-files"], capture_output=True, text=True, check=True).stdout.splitlines()
problems = []
for f in files:
    if f in ALLOWED_FILES:
        continue
    if BAD_EXT.search(f):
        problems.append(f"{f}: личный файл по расширению — место ему в AeroUchet-Private")
        continue
    if f.startswith(SKIP_TEXT) or f.endswith((".png", ".jpg", ".jpeg")):
        continue
    try:
        text = open(f, encoding="utf-8").read()
    except (UnicodeDecodeError, IsADirectoryError, FileNotFoundError):
        continue
    for rx, what in BAD_TEXT:
        for m in rx.finditer(text):
            line = text.count("\n", 0, m.start()) + 1
            problems.append(f"{f}:{line}: {what}")

if problems:
    print("Найдены личные данные в публичном репозитории:")
    print("\n".join(problems))
    print("\nУбрать из файла (и при необходимости из истории git), личное — в AeroUchet-Private.")
    sys.exit(1)
print(f"Личных данных не найдено ({len(files)} файлов).")
