enum AppVersion {
    static let number = 172
    static let label = "Версия 172"

    // Заполняет автоматическая проверка (.github/workflows/auto-version.yml). Вручную не менять.
    static let sourceCommit = "fd1d4b4"
    static let pullRequest = 180 // 0 — изменение без PR
    static let date = "08.10.2026 00:19"
}
