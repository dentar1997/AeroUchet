# 07.10 23:56 · ChatGPT · v171 — custom blur в Test + без пустой navigation bar
- **Денис:** попросил вернуть свой blur из v169 во вкладку «Тест» и убрать скачок при каждом свайпе.
- **Сделано:** PR #179 → **v171**.
- В `ScheduleCalendar.swift` восстановлен точный custom blur v169: `CADisplayLink`, снимок `window.layer`, half-resolution capture, `CIGaussianBlur`, радиус 0…20 pt, default blur 30%, непрерывный ползунок.
- В `ContentView.swift` у `NavigationStack` вкладки «Тест» скрыта пустая navigation bar через `.toolbar(.hidden, for: .navigationBar)`, чтобы она не меняла safe area при вертикальном scroll.
- **Проверки:** Build iOS app ✅, Swift quality checks ✅, Privacy Guard ✅; squash merge `512c3dc`; auto-version поднял `AppVersion` до 171.
- **Статус:** ждёт проверки на iPad.
- **Проверить:** 1) остался ли визуальный blur как в v169; 2) исчезли ли вертикальные скачки при каждом свайпе; 3) blur не исчезает после отпускания ползунка/повторного открытия окна.
