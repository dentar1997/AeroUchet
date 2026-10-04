enum AppVersion {
    static let number = 124
    static let label = "Версия 124"

    // Заполняет автоматическая проверка (.github/workflows/auto-version.yml). Вручную не менять.
    static let sourceCommit = "e6567b9"
    static let pullRequest = 125 // 0 — изменение без PR
    static let date = "04.10.2026 08:59"
}
