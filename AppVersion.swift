enum AppVersion {
    static let number = 150
    static let label = "Версия 150"

    // Заполняет автоматическая проверка (.github/workflows/auto-version.yml). Вручную не менять.
    static let sourceCommit = "f588279"
    static let pullRequest = 159 // 0 — изменение без PR
    static let date = "07.10.2026 04:01"
}
