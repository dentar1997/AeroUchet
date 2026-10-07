# 07.10 23:38 · ChatGPT · вероятная причина скачка v169
- **Денис:** уточнил, что скачок происходит при каждом свайпе; хочет по возможности сохранить визуальный blur v169.
- **Видео:** покадрово видно не просто лаг: верхняя панель вкладок остаётся на месте, а весь контент `FlightScheduleDatabaseV130View` под ней на время свайпа подскакивает вверх примерно на высоту пустой navigation bar (~54 pt), затем возвращается.
- **Код:** вкладка Test = `NavigationStack { FlightScheduleDatabaseV130View(...) }`; сам экран задаёт `.navigationTitle("").navigationBarTitleDisplayMode(.inline)`, то есть держит пустую navigation bar. В iOS 26 safe area navigation bar может меняться при scroll/minimization; Apple отдельно даёт `toolbarMinimizationBehavior` и `toolbarMinimizationSafeAreaAdjustment`.
- **Вывод:** вертикальный скачок вероятнее связан не с самим Gaussian blur, а с collapse/minimization пустой navigation bar/safe-area при каждом scroll. Custom blur v169 всё ещё тяжёлый, но наблюдаемый сдвиг на точную высоту панели — отдельный layout-механизм.
- **Предлагаемое исправление:** для Test/экрана расписания убрать ненужную navigation bar полностью (`.toolbar(.hidden, for: .navigationBar)`) либо запретить её минимизацию/изменение safe area. После этого можно вернуть визуальный механизм v169 и отдельно проверить производительность.
- **Сделано:** код не менялся.
- **Статус:** диагностика, ждёт решения Дениса / слова «Программируй».
