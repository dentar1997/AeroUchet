# 08.10 02:00 · ChatGPT · v176 — live custom blur 20 FPS
- Денис: v175 на 10 FPS визуально мало; попросил поднять до 20.
- Сделано: PR #184 → v176.
- Изменение минимальное: `preferredFramesPerSecond` 10 → 20.
- Safe SwiftUI-boundary v173, защита от jump и вся остальная логика blur сохранены.
- Defaults стекла: blur 50%, opacity 100%, dark tint 25%.
- Проверки: Build iOS app ✅, Static Analyze ✅, Swift quality checks ✅, Privacy Guard ✅; squash merge `6bff013`; auto-version → 176.
- Статус: ждёт проверки на iPad — достаточно ли плавно и лучше ли FPS, чем v173 на 30 FPS.
