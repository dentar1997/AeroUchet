# Тёплый iPad для CI-скриншотов

Подробно — `.memory/WORKFLOW.md`, раздел «Быстрые CI-скриншоты», решения U53 и U55 в `.memory/DECISIONS.md`.

1. Задача: **любая** ветка от свежего `main` (имя не важно: `fix/…`, `feat/…`, `claude/…`).
2. **В начале работы**, до правок Swift, отправить ветку в GitHub (`git push -u origin <ветка>`) — тёплый iPad включится сам.
   Он же включается от любого push в любую ветку, кроме `main` и правок только `.memory`. Живёт до 2 ч без правок (до 5,5 ч всего).
   Вручную: `gh workflow run early-ipad-prewarm.yml -f request_epoch=$(date +%s)`; выключить — `-f mode=stop`.
3. Открыть PR в `main`. Каждый новый SHA любого открытого PR снимается без повторной загрузки iPad: ~40 с после push
   (первая правка за вечер — ~5 мин на прогрев). Держать открытым один PR с правками Swift за раз.
4. Снимок: ветка `ci-shots` → `shots/<SHA>/` (`*.jpg`, `proof.json`, `*-layout.txt`) и артефакт `ipad-shot` в PR CI.
   Claude: `python3 Scripts/ci_ipad.py fetch-shot --sha <SHA> --dest <папка>`.

Какие экраны снимать — `shots.json` в этой папке **в ветке задачи** (без него — `home` + `aircraft-tamm`; перед слиянием убрать):

```json
{"shots": [{"name": "calendar"}, {"name": "home"}]}
```

Готовые экраны: `home`, `calendar`, `assignments`, `accounting`, `more` (с вымышленными рейсами текущего месяца),
`aircraft-tamm` (таблица ВС), `main-screen` (без данных). Свой экран: `{"name": "x", "args": ["--aerouchet-ci-tab=calendar"]}` —
аргументы только вида `--aerouchet-ci-…`, их понимает приложение в Simulator (`CIScreens.swift`).

У каждого снимка есть `<экран>-layout.txt`: строки текста, ровность столбцов (OK/OFF) и подсказки о неровных рядах (HINT).
