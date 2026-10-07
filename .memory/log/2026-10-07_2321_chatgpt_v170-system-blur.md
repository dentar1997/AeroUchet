# 07.10 23:21 · ChatGPT · v170 — системный live-blur
- **Денис:** после прыжков всего экрана в v169 выбрал системный blur и сказал «Программируй».
- **Сделано:** PR #178 → **v170**. В `ScheduleCalendar.swift` полностью удалён runtime-механизм v169: `CADisplayLink`, постоянный `window.layer.render`, скрывание слоёв и Core Image Gaussian blur. Вместо него обычный `UIVisualEffectView` + `UIBlurEffect` с системными material-стилями.
- **Настройки:** ползунок «Размытие» теперь имеет 5 устойчивых уровней: нет / ultraThin / thin / material / thick; «Прозрачность стекла» и «Тёмный оттенок» сохранены. Paused animator из v168 не возвращался.
- **Проверки:** PR #178 — Build iOS app ✅, Swift quality checks ✅, Privacy Guard ✅; squash merge `1f8e033`; auto-version поднял `AppVersion` до 170.
- **Статус:** ждёт проверки на iPad.
- **Дальше:** проверить, исчезли ли прыжки всего экрана и сохраняется ли blur при закрытии/повторном открытии окна; затем подобрать уровни/прозрачность.
