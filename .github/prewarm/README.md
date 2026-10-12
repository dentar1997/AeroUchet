# Тёплый iPad для CI-скриншотов

Подробно — `.memory/WORKFLOW.md`, раздел «Быстрые CI-скриншоты», и решение U53 в `.memory/DECISIONS.md`.

1. Задача с проверкой вида: ветка **`prewarm/<тема>`** от свежего `main`.
2. **В начале работы**, до правок Swift, отправить ветку в GitHub (`git push -u origin prewarm/<тема>`) — тёплый iPad включится сам. Он же включается от любого push в `prewarm/*`, если был выключен. Вручную: `gh workflow run early-ipad-prewarm.yml -f request_epoch=$(date +%s)`.
3. Открыть PR. Каждый новый SHA PR снимается без повторной загрузки iPad.
4. Снимок: ветка `ci-shots` → `shots/<SHA>/`, артефакт `ipad-shot` в PR CI.
   Claude: `python3 Scripts/ci_ipad.py fetch-shot --sha <SHA> --dest <папка>`.

Какие экраны снимать — необязательный `shots.json` в этой папке (по умолчанию `aircraft-tamm`):

```json
{"shots": [{"name": "aircraft-tamm"}, {"name": "main-screen", "settle": 4}]}
```

Аргументы запуска — только вида `--aerouchet-ci-…`, их понимает приложение в Simulator.
