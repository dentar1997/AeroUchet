import Foundation

/// Защита сохранённых данных от затирания (аудит 04.10).
///
/// Если сохранённое значение не читается (например, после изменения модели),
/// хранилище начинает с пустого списка, и первое же сохранение перезаписало бы
/// историю. Поэтому до этого сырые байты копируются в резерв: отдельный ключ
/// UserDefaults и файл в «Документах» приложения. Резерв ничем не удаляется.
enum StorageSafety {
    static let backupPrefix = "unreadableBackup."
    static let pendingNoticeKey = "unreadableBackup.pendingNotice"

    /// Сохраняет копию нечитаемых данных и запоминает, о чём предупредить Дениса.
    static func preserveUnreadable(
        _ data: Data,
        key: String,
        title: String,
        error: Error?,
        defaults: UserDefaults = .standard
    ) {
        let stamp = stampFormatter.string(from: Date())
        defaults.set(data, forKey: backupPrefix + key + "." + stamp)
        writeFileCopy(data, name: "\(key)_\(stamp).json")

        var notices = defaults.stringArray(forKey: pendingNoticeKey) ?? []
        if !notices.contains(title) {
            notices.append(title)
            defaults.set(notices, forKey: pendingNoticeKey)
        }
        print("Не удалось прочитать сохранённые данные «\(title)», копия сохранена:", error as Any)
    }

    /// Названия данных, которые при запуске не прочитались (для предупреждения).
    static func pendingNotices(defaults: UserDefaults = .standard) -> [String] {
        defaults.stringArray(forKey: pendingNoticeKey) ?? []
    }

    static func clearPendingNotices(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: pendingNoticeKey)
    }

    /// Читает значение; если данные есть, но не читаются, сохраняет резерв и возвращает nil.
    static func decode<T: Decodable>(
        _ type: T.Type,
        key: String,
        title: String,
        defaults: UserDefaults = .standard
    ) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            preserveUnreadable(data, key: key, title: title, error: error, defaults: defaults)
            return nil
        }
    }

    /// Сообщение интерфейсу: данные не сохранились (аудит 05.10, п. 5).
    static let saveFailedNotification = Notification.Name("AeroUchet.storageSaveFailed")

    /// Кодирует и сохраняет значение. Если кодирование не удалось, прежние данные
    /// остаются нетронутыми, а интерфейс показывает предупреждение.
    @discardableResult
    static func store<T: Encodable>(
        _ value: T,
        key: String,
        title: String,
        defaults: UserDefaults = .standard
    ) -> Bool {
        do {
            let data = try JSONEncoder().encode(value)
            defaults.set(data, forKey: key)
            return true
        } catch {
            reportSaveFailure(title: title, error: error)
            return false
        }
    }

    static func reportSaveFailure(title: String, error: Error) {
        print("Не удалось сохранить «\(title)»:", error)
        let post = {
            NotificationCenter.default.post(
                name: saveFailedNotification,
                object: nil,
                userInfo: ["title": title]
            )
        }
        if Thread.isMainThread { post() } else { DispatchQueue.main.async(execute: post) }
    }

    /// Папка данных приложения (Application Support/АэроУчёт).
    static func dataFileURL(_ name: String) -> URL? {
        let manager = FileManager.default
        guard let base = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let folder = base.appendingPathComponent("АэроУчёт", isDirectory: true)
        try? manager.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent(name)
    }

    /// Сохраняет значение файлом. Ошибка записи на диск видна (в отличие от UserDefaults).
    @discardableResult
    static func storeFile<T: Encodable>(_ value: T, name: String, title: String) -> Bool {
        guard let url = dataFileURL(name) else {
            reportSaveFailure(title: title, error: CocoaError(.fileNoSuchFile))
            return false
        }
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            reportSaveFailure(title: title, error: error)
            return false
        }
    }

    /// Читает файл; если он есть, но не читается — резерв и nil.
    static func decodeFile<T: Decodable>(_ type: T.Type, name: String, title: String) -> T? {
        guard let url = dataFileURL(name),
              let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            preserveUnreadable(data, key: "file." + name, title: title, error: error)
            return nil
        }
    }

    private static func writeFileCopy(_ data: Data, name: String) {
        let manager = FileManager.default
        guard let documents = manager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let folder = documents.appendingPathComponent("Резерв АэроУчёта", isDirectory: true)
        do {
            try manager.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: folder.appendingPathComponent(name), options: .atomic)
        } catch {
            print("Не удалось записать файл резерва:", error)
        }
    }

    private static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Moscow")
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter
    }()
}
