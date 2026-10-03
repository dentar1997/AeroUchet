enum AppVersion {
    static let number = 122
    static let label = "Версия 122"

    // Заполняет автоматическая проверка (.github/workflows/auto-version.yml). Вручную не менять.
    static let sourceCommit = ""
    static let pullRequest = 0 // 0 — изменение без PR
    static let date = ""
}
