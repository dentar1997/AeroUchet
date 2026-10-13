# Тёплый iPad для CI-скриншотов

Подробно — `.memory/WORKFLOW.md`, раздел «Быстрые CI-скриншоты», и решение U53 в `.memory/DECISIONS.md`.

1. Задача с проверкой вида: ветка **`prewarm/<тема>`** от свежего `main`.
2. **В начале работы**, до правок Swift, отправить ветку в GitHub (`git push -u origin prewarm/<тема>`) — тёплый iPad включится сам. Он же включается от любого push в `prewarm/*`, если был выключен. Вручную: `gh workflow run early-ipad-prewarm.yml -f request_epoch=$(date +%s)`.
3. Открыть PR. Каждый новый SHA PR снимается без повторной загрузки iPad.
4. Снимок: ветка `ci-shots` → `shots/<SHA>/`, артефакт `ipad-shot` в PR CI.
   Claude: `python3 Scripts/ci_ipad.py fetch-shot --sha <SHA> --dest <папка>`.

Какие экраны снимать — `shots.json` в этой папке **в ветке задачи** (без него — `aircraft-tamm`; перед слиянием убрать):

```json
{"shots": [{"name": "calendar"}, {"name": "home"}]}
```

Готовые экраны: `home`, `calendar`, `assignments`, `accounting`, `more` (с вымышленными рейсами текущего месяца),
`aircraft-tamm` (таблица ВС), `main-screen` (без данных). Свой экран: `{"name": "x", "args": ["--aerouchet-ci-tab=calendar"]}` —
аргументы только вида `--aerouchet-ci-…`, их понимает приложение в Simulator (`CIScreens.swift`).

У каждого снимка есть `<экран>-layout.txt`: строки текста, ровность столбцов (OK/OFF) и подсказки о неровных рядах (HINT).
