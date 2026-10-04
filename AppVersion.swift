enum AppVersion {
    static let number = 125
    static let label = "Версия 125"

    // Заполняет автоматическая проверка (.github/workflows/auto-version.yml). Вручную не менять.
    static let sourceCommit = "bbb7607"
    static let pullRequest = 134 // 0 — изменение без PR
    static let date = "04.10.2026 09:05"
}
