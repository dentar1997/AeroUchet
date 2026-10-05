enum AppVersion {
    static let number = 135
    static let label = "Версия 135"

    // Заполняет автоматическая проверка (.github/workflows/auto-version.yml). Вручную не менять.
    static let sourceCommit = "ab21c44"
    static let pullRequest = 144 // 0 — изменение без PR
    static let date = "06.10.2026 02:40"
}
