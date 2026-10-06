import Foundation
import Security

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
        let url = folder.appendingPathComponent(name)
        try? manager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        return url
    }

    static func fileExists(_ name: String) -> Bool {
        guard let url = dataFileURL(name) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Записывает готовые байты файлом. Ошибка видна интерфейсу.
    @discardableResult
    static func storeData(_ data: Data, name: String, title: String) -> Bool {
        guard let url = dataFileURL(name) else {
            reportSaveFailure(title: title, error: CocoaError(.fileNoSuchFile))
            return false
        }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            reportSaveFailure(title: title, error: error)
            return false
        }
    }

    static func removeFile(_ name: String) {
        guard let url = dataFileURL(name),
              FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Имена файлов в подпапке данных (без пути), по алфавиту.
    static func fileNames(inFolder folder: String) -> [String] {
        guard let url = dataFileURL(folder + "/.probe")?.deletingLastPathComponent(),
              let names = try? FileManager.default.contentsOfDirectory(atPath: url.path) else {
            return []
        }
        return names.sorted()
    }

    /// Хранение файлом с v144 (аудит 05.10, п. 2/3, шаг 1).
    /// Если файл есть — он главный. Если файла ещё нет — читается прежняя запись
    /// UserDefaults (`legacy`) и сразу переносится в файл. Прежняя запись
    /// не стирается: при откате на старую версию данные на момент переноса на месте.
    static func loadMigrating<T: Codable>(
        _ type: T.Type,
        file: String,
        title: String,
        legacy: () -> T?
    ) -> T? {
        if fileExists(file) {
            return decodeFile(type, name: file, title: title)
        }
        guard let value = legacy() else { return nil }
        storeFile(value, name: file, title: title)
        return value
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


/// Секреты (ссылка календаря портала с токеном) — в Связке ключей iPad,
/// а не в настройках приложения (аудит 05.10, п. 15).
enum KeychainStore {
    private static let service = "AeroUchet"

    static func string(for account: String) -> String? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// true — записано в Связку ключей.
    @discardableResult
    static func set(_ value: String, for account: String) -> Bool {
        let data = Data(value.utf8)
        let query = baseQuery(account)
        let update: [String: Any] = [kSecValueData as String: data]
        var status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            status = SecItemAdd(add as CFDictionary, nil)
        }
        if status != errSecSuccess {
            print("Связка ключей: не удалось сохранить, код \(status)")
        }
        return status == errSecSuccess
    }

    static func remove(_ account: String) {
        SecItemDelete(baseQuery(account) as CFDictionary)
    }

    private static func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
