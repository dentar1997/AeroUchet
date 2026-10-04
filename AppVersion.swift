enum AppVersion {
    static let number = 128
    static let label = "Версия 128"

    // Заполняет автоматическая проверка (.github/workflows/auto-version.yml). Вручную не менять.
    static let sourceCommit = "a6fccc3"
    static let pullRequest = 137 // 0 — изменение без PR
    static let date = "04.10.2026 16:21"
}
