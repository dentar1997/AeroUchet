#!/usr/bin/env python3
"""Автоверсия АэроУчёта. Запускается из .github/workflows/auto-version.yml после push в main.

Если в push менялись .swift-файлы:
  - номер в AppVersion.swift поднимается на 1 (если его уже не подняли вручную);
  - записываются хеш коммита с изменениями кода, номер PR и дата (МСК);
  - сообщение для коммита бота пишется в файл, путь к которому в $COMMIT_MSG_FILE.
Если .swift не менялись — ничего не делает.
"""
import datetime, json, os, re, subprocess, sys, urllib.request

PATH = "AppVersion.swift"
before = os.environ.get("BEFORE", "")
after = os.environ["AFTER"]
repo = os.environ["REPO"]
token = os.environ.get("GH_TOKEN", "")
msg_file = os.environ["COMMIT_MSG_FILE"]


def git(*args):
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout


if not before or set(before) == {"0"}:
    before = git("rev-parse", after + "^").strip()

changed = [f for f in git("diff", "--name-only", before, after).splitlines() if f.endswith(".swift")]
if not changed:
    print("Swift не менялся — версия не трогается")
    sys.exit(0)


def number_in(text):
    return int(re.search(r"static let number = (\d+)", text).group(1))


try:
    old = number_in(git("show", f"{before}:{PATH}"))
except subprocess.CalledProcessError:
    old = 0
src = open(PATH, encoding="utf-8").read()
cur = number_in(src)
new = cur if cur > old else old + 1

# PR, к которому относится коммит
pr, title = 0, ""
try:
    req = urllib.request.Request(
        f"https://api.github.com/repos/{repo}/commits/{after}/pulls",
        headers={"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"},
    )
    pulls = json.load(urllib.request.urlopen(req, timeout=20))
    if pulls:
        pr, title = pulls[0]["number"], pulls[0]["title"]
except Exception as e:  # без PR (прямой коммит) или API недоступен
    print("PR не найден:", e)
if not pr:
    m = re.search(r"#(\d+)", git("log", "-1", "--format=%s", after))
    pr = int(m.group(1)) if m else 0
if not title:
    title = git("log", "-1", "--format=%s", after).strip()
title = re.sub(r"^(Версия \d+:\s*|\[PR #\d+\]\s*)", "", title)

short = after[:7]
ts = int(git("log", "-1", "--format=%ct", after).strip())
date = datetime.datetime.fromtimestamp(ts, datetime.timezone(datetime.timedelta(hours=3))).strftime("%d.%m.%Y %H:%M")

body = f'''enum AppVersion {{
    static let number = {new}
    static let label = "Версия {new}"

    // Заполняет автоматическая проверка (.github/workflows/auto-version.yml). Вручную не менять.
    static let sourceCommit = "{short}"
    static let pullRequest = {pr} // 0 — изменение без PR
    static let date = "{date}"
}}
'''
open(PATH, "w", encoding="utf-8").write(body)
pr_part = f"PR #{pr}, " if pr else ""
open(msg_file, "w", encoding="utf-8").write(f"Версия {new}: {title} ({pr_part}{short})\n")
print(f"Версия {old} → {new}, коммит {short}, PR {pr}")
