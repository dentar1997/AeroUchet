enum AppVersion {
    static let number = 123
    static let label = "Версия 123"

    // Заполняет автоматическая проверка (.github/workflows/auto-version.yml). Вручную не менять.
    static let sourceCommit = "280ae4f"
    static let pullRequest = 132 // 0 — изменение без PR
    static let date = "04.10.2026 02:19"
}
