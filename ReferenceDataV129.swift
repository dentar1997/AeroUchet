import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers


enum AircraftFamilyV129: String, CaseIterable, Codable, Identifiable {
    case a320 = "A320"
    case a320S = "A320S"
    case a320N = "A320N"
    case a321 = "A321"
    case a321S = "A321S"
    case a321N = "A321N"

    var id: String { rawValue }

    static func normalized(_ raw: String) -> AircraftFamilyV129? {
        let value = raw.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(SHARK)", with: "S")
            .replacingOccurrences(of: "NEO", with: "N")

        switch value {
        case "A320", "320": return .a320
        case "A320A", "A320S", "32A": return .a320S
        case "A320N", "32N": return .a320N
        case "A321", "321": return .a321
        case "A321B", "A321S", "32B": return .a321S
        case "A321Q", "A321N", "32Q": return .a321N
        default: return nil
        }
    }

    static func display(_ raw: String) -> String {
        normalized(raw)?.rawValue ?? raw
    }
}


enum FlightScheduleAircraftGroupV131: String, CaseIterable, Identifiable {
    case all = "Все ВС"
    case a320 = "A320"
    case b737 = "B737"
    case a330 = "A330"
    case a350 = "A350"
    case b777 = "B777"

    var id: String { rawValue }

    func contains(rawAircraftCode: String) -> Bool {
        if self == .all { return true }
        if self == .a320 { return AircraftFamilyV129.normalized(rawAircraftCode) != nil }

        let value = rawAircraftCode.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        switch self {
        case .all: return true
        case .a320: return AircraftFamilyV129.normalized(rawAircraftCode) != nil
        case .b737: return value.hasPrefix("73") || value.hasPrefix("B73")
        case .a330: return value.hasPrefix("33") || value.hasPrefix("A33")
        case .a350: return value.hasPrefix("35") || value.hasPrefix("A35")
        case .b777: return value.hasPrefix("77") || value.hasPrefix("B77")
        }
    }
}


struct AircraftReferenceV129: Identifiable, Codable, Hashable {
    let registration: String
    let type: AircraftFamilyV129
    let surname: String
    let oldRegistration: String?
    let msn: String?
    let exactType: String?

    var id: String { registration }

    var digits: String {
        registration.filter(\.isNumber)
    }
}


@MainActor
final class AircraftReferenceStoreV129: ObservableObject {
    static let shared = AircraftReferenceStoreV129()

    @Published private(set) var aircraft: [AircraftReferenceV129]

    private init() {
        aircraft = Self.seed.sorted { left, right in
            if left.registration == "RA-73772" { return true }
            if right.registration == "RA-73772" { return false }
            return left.registration < right.registration
        }
    }

    func aircraft(for registration: String) -> AircraftReferenceV129? {
        let digits = String(registration.filter(\.isNumber).suffix(5))
        guard digits.count == 5 else { return nil }
        return aircraft.first { $0.digits == digits }
    }

    func stableAircraft(
        for type: AircraftFamilyV129,
        seed: String
    ) -> AircraftReferenceV129? {
        if type == .a320S, let tarasov = aircraft(for: "73772") {
            return tarasov
        }

        let candidates = aircraft
            .filter { $0.type == type }
            .sorted { $0.registration < $1.registration }
        guard !candidates.isEmpty else { return nil }

        let hash = seed.utf8.reduce(UInt64(1469598103934665603)) { partial, byte in
            (partial ^ UInt64(byte)) &* 1099511628211
        }
        return candidates[Int(hash % UInt64(candidates.count))]
    }

    private static func row(
        _ digits: String,
        _ surname: String,
        _ type: AircraftFamilyV129,
        old: String? = nil,
        msn: String? = nil,
        exact: String? = nil
    ) -> AircraftReferenceV129 {
        AircraftReferenceV129(
            registration: "RA-\(digits)",
            type: type,
            surname: surname,
            oldRegistration: old,
            msn: msn,
            exactType: exact
        )
    }

    // Справочник собран из присланных Денисом «Воздушного парка» и списка выбора ВС.
    // Поля старой регистрации/MSN заполняются только там, где источник прочитан однозначно.
    private static let seed: [AircraftReferenceV129] = [
        row("73160", "Вахтангов", .a321, old: "VP-BTL", msn: "5881", exact: "A321-211"),
        row("73161", "Бернес", .a321S, old: "VP-BKZ", msn: "8205", exact: "A321-211"),
        row("73162", "Вишневская", .a321, old: "VP-BOE", msn: "5755", exact: "A321-211"),
        row("73163", "Станиславский", .a321, old: "VP-BTG", msn: "5790", exact: "A321-211"),
        row("73164", "Дягилев", .a321, old: "VP-BTR", msn: "5913", exact: "A321-211"),
        row("73165", "Михалков", .a321, old: "VP-BOC", msn: "5720", exact: "A321-211"),
        row("73166", "Гомельский", .a321S, msn: "8363", exact: "A321-211"),
        row("73167", "Толбухин", .a320S, msn: "8418", exact: "A320-214"),
        row("73168", "Гагарин", .a320S, old: "VP-BIX", msn: "8319", exact: "A320-214"),
        row("73169", "Федотов", .a320S, old: "VP-BTX", msn: "8452", exact: "A320-214"),
        row("73170", "Герасимов", .a320S, old: "VP-BCB", msn: "7279", exact: "A320-214"),
        row("73171", "Фет", .a320S, old: "VP-BEO", msn: "7038", exact: "A320-214"),
        row("73172", "Поддубный", .a320S, old: "VP-BIL", msn: "8234", exact: "A320-214"),
        row("73173", "Северянин", .a320S, old: "VP-BIP", msn: "8276", exact: "A320-214"),
        row("73174", "Толстой", .a320S, old: "VP-BAC", msn: "7215", exact: "A320-214"),
        row("73175", "Маршак", .a320S, old: "VP-BJY", msn: "6963", exact: "A320-214"),
        row("73176", "Вернадский", .a320, msn: "4712", exact: "A320-214"),
        row("73177", "Белов", .a321S, msn: "8378", exact: "A321-211"),
        row("73178", "Набоков", .a321S, msn: "8147", exact: "A321-211"),
        row("73179", "Паустовский", .a320S, old: "VP-BJW", msn: "6954", exact: "A320-214"),
        row("73180", "Иоффе", .a320S, old: "VP-BAD", msn: "7240", exact: "A320-214"),
        row("73181", "Вознесенский", .a320S, old: "VP-BET", msn: "7071", exact: "A320-214"),
        row("73703", "Вавилов Н.", .a321N, old: "VP-BPP", msn: "10193", exact: "A321-251NX"),
        row("73704", "Годенко", .a321N, old: "VP-BRC", msn: "10314", exact: "A321-251NX"),
        row("73705", "Салманов", .a321N, old: "VP-BXT", msn: "10595", exact: "A321-251NX"),
        row("73706", "Мичурин", .a321, msn: "4058", exact: "A321-211"),
        row("73707", "Пирогов", .a321, msn: "4074", exact: "A321-211"),
        row("73708", "Грибоедова", .a321, msn: "4116", exact: "A321-211"),
        row("73709", "Шнитке", .a321S, msn: "6678", exact: "A321-211"),
        row("73710", "Любимов", .a321S, msn: "6726", exact: "A321-211"),
        row("73711", "Немирович-Данченко", .a321S),
        row("73712", "Дунаевский", .a321S),
        row("73713", "Гончаров", .a321S),
        row("73714", "Ушаков", .a321S),
        row("73715", "Зощенко", .a321S),
        row("73716", "Рихтер", .a321S),
        row("73717", "Рябушинский", .a321S),
        row("73718", "Бондарчук", .a321S),
        row("73719", "Тарковский", .a321S),
        row("73720", "Шукшин", .a321S),
        row("73721", "Левитан", .a321S),
        row("73722", "Рязанов", .a321S),
        row("73723", "Волков", .a321S),
        row("73724", "Александров", .a321S),
        row("73725", "Шишкин", .a321S),
        row("73726", "Рахманинов", .a321S),
        row("73727", "Менделеев", .a321S),
        row("73728", "Рождественский", .a321S),
        row("73729", "Вертинский", .a321S),
        row("73730", "Добрынин", .a320N),
        row("73731", "Этуш", .a320N),
        row("73732", "Жуковский", .a320N),
        row("73733", "Лазарев", .a320N),
        row("73734", "Мешалкин", .a320N),
        row("73735", "Беллинсгаузен", .a320N),
        row("73738", "Вавилов С.", .a320),
        row("73739", "Лобачевский", .a320),
        row("73740", "Джалиль", .a320),
        row("73743", "Тимирязев", .a320),
        row("73744", "Николаев", .a320),
        row("73745", "Тамм", .a320),
        row("73746", "Мечников", .a320S),
        row("73747", "Черенков", .a320S),
        row("73748", "Басов", .a320S),
        row("73749", "SKYTEAM", .a320S),
        row("73750", "Суворов", .a320S),
        row("73752", "Яблочков", .a320S),
        row("73753", "Ретро ливрея", .a320S),
        row("73754", "Мейерхольд", .a320S),
        row("73755", "Лихачёв", .a320S),
        row("73756", "Столетов", .a320S),
        row("73757", "SKYTEAM", .a320S),
        row("73758", "Вишневский", .a320S),
        row("73759", "Комаров", .a320S),
        row("73760", "Егоров", .a320S),
        row("73761", "Феоктистов", .a320S),
        row("73762", "Попович", .a320S),
        row("73763", "Жуков", .a320S),
        row("73764", "Герман", .a320S),
        row("73765", "Достоевский", .a320S),
        row("73766", "Шаляпин", .a320S),
        row("73767", "Левитан", .a320S),
        row("73768", "Флёров", .a320S),
        row("73769", "Малевич", .a320S),
        row("73770", "Прокофьев", .a320S),
        row("73771", "Бородин", .a320S),
        row("73772", "Тарасов", .a320S),
        row("73773", "Челюскин", .a320S),
        row("73774", "Репин", .a320S),
        row("73775", "Рублёв", .a320S),
        row("73776", "Семашко", .a320S),
        row("73777", "Гайдай", .a320S),
        row("73778", "Брюсов", .a320S),
        row("73779", "Довлатов", .a320S),
        row("73780", "Глазунов", .a320S),
        row("73781", "Лиена", .a320S)
    ]
}


struct FlightScheduleEntryV129: Identifiable, Codable, Hashable {
    let flightNumber: String
    let validFrom: Date
    let validTo: Date
    let operatingWeekdays: [Int]
    let departure: String
    let departureTerminal: String?
    let departureMinutesUTC: Int
    let arrival: String
    let arrivalTerminal: String?
    let arrivalMinutesUTC: Int
    let rawAircraftCode: String
    let configuration: String?
    let flightMinutes: Int

    var id: String { identityKey }

    var identityKey: String {
        [
            FlightScheduleStoreV129.normalizedFlightNumber(flightNumber),
            FlightScheduleStoreV129.dayKey(validFrom),
            FlightScheduleStoreV129.dayKey(validTo),
            operatingWeekdays.map(String.init).joined(separator: ","),
            departure,
            arrival
        ].joined(separator: "|")
    }
}


extension FlightScheduleEntryV129 {
    /// Та же строка расписания на более узком периоде (D40). nil — если период пуст.
    func clipped(from start: Date, to end: Date) -> FlightScheduleEntryV129? {
        let newFrom = max(start, validFrom)
        let newTo = min(end, validTo)
        guard newFrom <= newTo else { return nil }
        return FlightScheduleEntryV129(
            flightNumber: flightNumber,
            validFrom: newFrom,
            validTo: newTo,
            operatingWeekdays: operatingWeekdays,
            departure: departure,
            departureTerminal: departureTerminal,
            departureMinutesUTC: departureMinutesUTC,
            arrival: arrival,
            arrivalTerminal: arrivalTerminal,
            arrivalMinutesUTC: arrivalMinutesUTC,
            rawAircraftCode: rawAircraftCode,
            configuration: configuration,
            flightMinutes: flightMinutes
        )
    }
}


struct FlightScheduleImportRecordV129: Identifiable, Codable, Hashable {
    let id: UUID
    let importedAt: Date
    let validFrom: Date
    let validTo: Date
    let rowCount: Int
    let sourceName: String
    let fingerprint: String?
    let entryKeys: [String]?
}


struct FlightScheduleImportSummaryV134 {
    let added: Int
    let updated: Int
    let removed: Int
    let total: Int
    let unchanged: Bool
}


struct FlightScheduleMatchV129: Identifiable, Hashable {
    let entry: FlightScheduleEntryV129
    let operatingDateUTC: Date
    let engineOn: Date
    let engineOff: Date

    var id: String {
        entry.id + "|" + FlightScheduleStoreV129.dayKey(operatingDateUTC)
    }

    var departureWithTerminal: String {
        Self.code(entry.departure, terminal: entry.departureTerminal)
    }

    var arrivalWithTerminal: String {
        Self.code(entry.arrival, terminal: entry.arrivalTerminal)
    }

    private static func code(_ code: String, terminal: String?) -> String {
        let base = code.uppercased()
        let terminalValue = terminal?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard base == "SVO",
              let terminalValue,
              ["D", "E", "F"].contains(terminalValue) else {
            return base
        }
        return "\(base)/\(terminalValue)"
    }
}


@MainActor
final class FlightScheduleStoreV129: ObservableObject {
    static let shared = FlightScheduleStoreV129()

    private static let entriesKey = "aerouchet.v129.flightSchedule.entries"
    private static let importsKey = "aerouchet.v129.flightSchedule.imports"

    @Published private(set) var entries: [FlightScheduleEntryV129] = []
    @Published private(set) var imports: [FlightScheduleImportRecordV129] = []
    private var entriesByFlightNumber: [String: [FlightScheduleEntryV129]] = [:]

    private init() {
        load()
        rebuildIndex()
    }

    var coverageText: String {
        guard let first = entries.map(\.validFrom).min(),
              let last = entries.map(\.validTo).max() else {
            return "Расписание ещё не загружено"
        }
        return "\(Self.shortDay(first)) — \(Self.shortDay(last))"
    }

    @discardableResult
    func importXLS(data: Data, sourceName: String) throws -> FlightScheduleImportSummaryV134 {
        let parsed = try FlightScheduleXLSParserV129.parse(data)
        guard let from = parsed.map(\.validFrom).min(),
              let to = parsed.map(\.validTo).max() else {
            throw FlightScheduleXLSParserV129.ImportError.invalid("В расписании нет строк")
        }

        let fingerprint = Self.scheduleFingerprint(parsed)
        let alreadyLoaded = imports.contains { record in
            if record.fingerprint == fingerprint { return true }
            guard record.fingerprint == nil else { return false }
            let keys = importKeys(for: record)
            let values = entries.filter { keys.contains($0.identityKey) }
            return !values.isEmpty && Self.scheduleFingerprint(values) == fingerprint
        }
        if alreadyLoaded {
            return FlightScheduleImportSummaryV134(
                added: 0,
                updated: 0,
                removed: 0,
                total: entries.count,
                unchanged: true
            )
        }

        // D40: новый снимок заменяет строки только внутри своего периода.
        // Строки старых снимков до его начала и после конца остаются в базе.
        let overlapping = entries.filter { $0.validFrom <= to && $0.validTo >= from }
        var byKey = Dictionary(
            entries.map { ($0.identityKey, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var replacementKeys: [String: [String]] = [:]
        for entry in overlapping {
            byKey.removeValue(forKey: entry.identityKey)
            var pieces: [String] = []
            if entry.validFrom < from,
               let headEnd = Calendar.gregorianUTC.date(byAdding: .day, value: -1, to: from),
               let head = entry.clipped(from: entry.validFrom, to: headEnd) {
                byKey[head.identityKey] = head
                pieces.append(head.identityKey)
            }
            if entry.validTo > to,
               let tailStart = Calendar.gregorianUTC.date(byAdding: .day, value: 1, to: to),
               let tail = entry.clipped(from: tailStart, to: entry.validTo) {
                byKey[tail.identityKey] = tail
                pieces.append(tail.identityKey)
            }
            replacementKeys[entry.identityKey] = pieces
        }

        let oldOverlap = Dictionary(
            overlapping.map { ($0.identityKey, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let newKeys = Set(parsed.map(\.identityKey))
        var added = 0
        var updated = 0
        for value in parsed {
            if let old = oldOverlap[value.identityKey] {
                if old != value { updated += 1 }
            } else {
                added += 1
            }
        }
        let removed = oldOverlap.keys.filter { !newKeys.contains($0) }.count
        for value in parsed {
            byKey[value.identityKey] = value
        }

        // Прежние снимки: ключи обрезанных строк заменяются, пустые снимки исчезают.
        var keptImports: [FlightScheduleImportRecordV129] = []
        for record in imports {
            var keys: [String] = []
            for key in importKeys(for: record) {
                if let pieces = replacementKeys[key] {
                    keys.append(contentsOf: pieces)
                } else if byKey[key] != nil, !newKeys.contains(key) {
                    keys.append(key)
                }
            }
            let values = keys.compactMap { byKey[$0] }
            guard let first = values.map(\.validFrom).min(),
                  let last = values.map(\.validTo).max() else { continue }
            keptImports.append(
                FlightScheduleImportRecordV129(
                    id: record.id,
                    importedAt: record.importedAt,
                    validFrom: first,
                    validTo: last,
                    rowCount: values.count,
                    sourceName: record.sourceName,
                    fingerprint: record.fingerprint,
                    entryKeys: Array(Set(keys)).sorted()
                )
            )
        }

        let record = FlightScheduleImportRecordV129(
            id: UUID(),
            importedAt: Date(),
            validFrom: from,
            validTo: to,
            rowCount: parsed.count,
            sourceName: sourceName,
            fingerprint: fingerprint,
            entryKeys: newKeys.sorted()
        )
        imports = [record] + keptImports
        entries = sortedEntries(Array(byKey.values))
        rebuildIndex()
        save()

        return FlightScheduleImportSummaryV134(
            added: added,
            updated: updated,
            removed: removed,
            total: entries.count,
            unchanged: false
        )
    }

    func deleteImport(id: UUID) {
        guard let index = imports.firstIndex(where: { $0.id == id }) else { return }
        let targetKeys = importKeys(for: imports[index])
        let protectedKeys = Set(
            imports.enumerated()
                .filter { $0.offset != index }
                .flatMap { Array(importKeys(for: $0.element)) }
        )
        entries.removeAll { entry in
            targetKeys.contains(entry.identityKey) && !protectedKeys.contains(entry.identityKey)
        }
        imports.remove(at: index)
        entries = sortedEntries(entries)
        rebuildIndex()
        save()
    }

    func deleteAll() {
        entries = []
        imports = []
        rebuildIndex()
        save()
    }

    private func importKeys(for record: FlightScheduleImportRecordV129) -> Set<String> {
        if let keys = record.entryKeys { return Set(keys) }
        return Set(entries.filter { entry in
            entry.validFrom >= record.validFrom && entry.validTo <= record.validTo
        }.map(\.identityKey))
    }

    private func sortedEntries(_ values: [FlightScheduleEntryV129]) -> [FlightScheduleEntryV129] {
        values.sorted {
            if $0.flightNumber == $1.flightNumber {
                if $0.validFrom == $1.validFrom { return $0.departure < $1.departure }
                return $0.validFrom < $1.validFrom
            }
            return $0.flightNumber.localizedStandardCompare($1.flightNumber) == .orderedAscending
        }
    }

    private static func scheduleFingerprint(_ values: [FlightScheduleEntryV129]) -> String {
        let canonical = values.sorted { $0.identityKey < $1.identityKey }.map { value in
            [
                value.identityKey,
                value.departureTerminal ?? "",
                String(value.departureMinutesUTC),
                value.arrivalTerminal ?? "",
                String(value.arrivalMinutesUTC),
                value.rawAircraftCode,
                value.configuration ?? "",
                String(value.flightMinutes)
            ].joined(separator: "|")
        }.joined(separator: "\n")

        var hash = UInt64(1469598103934665603)
        for byte in canonical.utf8 {
            hash = (hash ^ UInt64(byte)) &* 1099511628211
        }
        return String(format: "%016llx", hash)
    }

    func matches(
        flightNumber rawNumber: String,
        moscowDate: Date,
        departureHint: String? = nil,
        arrivalHint: String? = nil
    ) -> [FlightScheduleMatchV129] {
        let number = Self.normalizedFlightNumber(rawNumber)
        guard !number.isEmpty else { return [] }
        let depHint = Self.airportCode(departureHint)
        let arrHint = Self.airportCode(arrivalHint)
        let candidates = entriesByFlightNumber[number] ?? []

        var matches: [FlightScheduleMatchV129] = []
        for entry in candidates {
            for delta in -1...0 {
                guard let probe = moscowCalendar.date(byAdding: .day, value: delta, to: moscowDate) else {
                    continue
                }
                let parts = moscowCalendar.dateComponents([.year, .month, .day], from: probe)
                var utcParts = DateComponents()
                utcParts.timeZone = TimeZone(secondsFromGMT: 0)
                utcParts.year = parts.year
                utcParts.month = parts.month
                utcParts.day = parts.day
                guard let operatingDate = Calendar.gregorianUTC.date(from: utcParts),
                      operatingDate >= entry.validFrom,
                      operatingDate <= entry.validTo else {
                    continue
                }

                let weekday = Calendar.gregorianUTC.component(.weekday, from: operatingDate)
                let isoWeekday = weekday == 1 ? 7 : weekday - 1
                guard entry.operatingWeekdays.contains(isoWeekday) else { continue }

                guard let engineOn = Calendar.gregorianUTC.date(
                    byAdding: .minute,
                    value: entry.departureMinutesUTC,
                    to: operatingDate
                ) else { continue }
                let arrivalOffset = entry.arrivalMinutesUTC < entry.departureMinutesUTC ? 24 * 60 : 0
                guard let engineOff = Calendar.gregorianUTC.date(
                    byAdding: .minute,
                    value: entry.arrivalMinutesUTC + arrivalOffset,
                    to: operatingDate
                ) else { continue }
                guard moscowCalendar.isDate(engineOn, inSameDayAs: moscowDate) else { continue }

                if let depHint, depHint != entry.departure { continue }
                if let arrHint, arrHint != entry.arrival { continue }

                matches.append(
                    FlightScheduleMatchV129(
                        entry: entry,
                        operatingDateUTC: operatingDate,
                        engineOn: engineOn,
                        engineOff: engineOff
                    )
                )
            }
        }
        return matches.sorted { $0.engineOn < $1.engineOn }
    }

    nonisolated static func normalizedFlightNumber(_ raw: String) -> String {
        canonicalFlightNumber(raw)
    }

    nonisolated static func displayFlightNumber(_ raw: String) -> String {
        let normalized = normalizedFlightNumber(raw)
        guard let number = Int(normalized) else { return raw }
        if number < 1000 { return String(format: "%03d", number) }
        return String(number)
    }

    private static var airportCodeCache: [String: String] = [:]
    private static let airportCodeMissing = "\u{0}"
    private static let airportCodeRegex = try? NSRegularExpression(
        pattern: #"\(([A-Z]{3})(?:/[A-Z0-9]+)?\)"#
    )

    /// Код аэропорта из подсказки плана. Результат запоминается: раньше на каждый
    /// вызов компилировалась регулярка и перебирался справочник (п. 16).
    static func airportCode(_ raw: String?) -> String? {
        guard let raw else { return nil }
        if let cached = airportCodeCache[raw] {
            return cached == airportCodeMissing ? nil : cached
        }
        let value = resolveAirportCode(raw)
        if airportCodeCache.count > 2048 { airportCodeCache.removeAll(keepingCapacity: true) }
        airportCodeCache[raw] = value ?? airportCodeMissing
        return value
    }

    private static func resolveAirportCode(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let upper = trimmed.uppercased()

        if upper.contains("ШЕРЕМЕТЬЕВО") || upper == "Ш" { return "SVO" }

        if let slash = upper.firstIndex(of: "/") {
            let value = String(upper[..<slash]).filter(\.isLetter)
            if value.count == 3 { return AirportDatabase.airport(for: value)?.iata ?? value }
        }

        if let regex = airportCodeRegex,
           let match = regex.firstMatch(
                in: upper,
                range: NSRange(location: 0, length: (upper as NSString).length)
           ),
           match.numberOfRanges >= 2 {
            let value = (upper as NSString).substring(with: match.range(at: 1))
            return AirportDatabase.airport(for: value)?.iata ?? value
        }

        let letters = upper.filter(\.isLetter)
        if letters.count == 3 { return AirportDatabase.airport(for: letters)?.iata ?? letters }

        let byName = AirportDatabase.airports.filter { airport in
            airport.name.caseInsensitiveCompare(trimmed) == .orderedSame
        }
        if byName.count == 1 { return byName[0].iata }
        return nil
    }

    // Форматтеры создаются один раз: раньше — на каждый вызов, а ключ строки
    // расписания строится десятки тысяч раз (аудит 05.10, п. 16).
    nonisolated static func dayKey(_ date: Date) -> String {
        scheduleDayKeyFormatter.string(from: date)
    }

    nonisolated static func shortDay(_ date: Date) -> String {
        scheduleShortDayFormatter.string(from: date)
    }

    private struct StoredSchedule: Codable {
        var entries: [FlightScheduleEntryV129]
        var imports: [FlightScheduleImportRecordV129]
    }

    private static let fileName = "flight-schedule.json"
    static let generationKey = "aerouchet.flightSchedule.generation"

    /// Метка версии загруженного расписания. Меняется при каждом импорте или удалении.
    /// Читается без загрузки самого расписания — по ней сохранённые результаты
    /// перспективного плана понимают, что их пора пересчитать (D35).
    nonisolated static var generation: String {
        UserDefaults.standard.string(forKey: "aerouchet.flightSchedule.generation") ?? "none"
    }

    private func load() {
        // Расписание хранится файлом, а не в UserDefaults: UserDefaults переписывает
        // весь свой файл при любой записи (п. 16). Нечитаемое — в резерв (п. 17).
        if let stored = StorageSafety.decodeFile(
            StoredSchedule.self, name: Self.fileName, title: "Расписание рейсов"
        ) {
            entries = stored.entries
            imports = stored.imports
            return
        }
        let legacyEntries = StorageSafety.decode(
            [FlightScheduleEntryV129].self, key: Self.entriesKey, title: "Расписание рейсов"
        )
        let legacyImports = StorageSafety.decode(
            [FlightScheduleImportRecordV129].self, key: Self.importsKey, title: "Импорты расписания"
        )
        guard legacyEntries != nil || legacyImports != nil else { return }
        entries = legacyEntries ?? []
        imports = legacyImports ?? []
        if StorageSafety.storeFile(
            StoredSchedule(entries: entries, imports: imports),
            name: Self.fileName,
            title: "Расписание рейсов"
        ) {
            UserDefaults.standard.removeObject(forKey: Self.entriesKey)
            UserDefaults.standard.removeObject(forKey: Self.importsKey)
        }
    }

    private func rebuildIndex() {
        entriesByFlightNumber = Dictionary(grouping: entries) { entry in
            Self.normalizedFlightNumber(entry.flightNumber)
        }
    }

    private func save() {
        StorageSafety.storeFile(
            StoredSchedule(entries: entries, imports: imports),
            name: Self.fileName,
            title: "Расписание рейсов"
        )
        UserDefaults.standard.set(UUID().uuidString, forKey: Self.generationKey)
    }
}


private let scheduleDayKeyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

private let scheduleShortDayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ru_RU")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "dd.MM.yyyy"
    return formatter
}()


private extension Calendar {
    static let gregorianUTC: Calendar = {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }()
}


enum FlightScheduleXLSParserV129 {
    enum ImportError: LocalizedError {
        case invalid(String)

        var errorDescription: String? {
            switch self {
            case .invalid(let text): return text
            }
        }
    }

    static func parse(_ data: Data) throws -> [FlightScheduleEntryV129] {
        let book = try workbookStream(data)
        let records = try records(in: book)
        var sheetOffset: Int?
        var strings: [String] = []
        var index = 0

        while index < records.count {
            let record = records[index]
            if record.id == 0x0085, record.bytes.count >= 8 {
                let length = Int(record.bytes[6])
                let unicode = record.bytes[7] & 1 != 0
                let start = 8
                let count = length * (unicode ? 2 : 1)
                guard record.bytes.count >= start + count else {
                    throw ImportError.invalid("Повреждён список листов XLS")
                }
                let nameData = record.bytes.subdata(in: start..<(start + count))
                let name = unicode
                    ? String(data: nameData, encoding: .utf16LittleEndian)
                    : String(data: nameData, encoding: .windowsCP1252)
                if name == "UTC" { sheetOffset = record.bytes.v129U32(0) }
            }
            if record.id == 0x00FC {
                var pieces = [record.bytes]
                while index + 1 < records.count && records[index + 1].id == 0x003C {
                    index += 1
                    pieces.append(records[index].bytes)
                }
                strings = try sharedStrings(pieces)
            }
            index += 1
        }

        guard let offset = sheetOffset,
              offset >= 0,
              offset < book.count else {
            throw ImportError.invalid("В расписании не найден лист «UTC»")
        }

        var cells: [Int: [Int: Cell]] = [:]
        var position = offset
        while position + 4 <= book.count {
            guard let id = book.v129U16(position),
                  let length = book.v129U16(position + 2) else { break }
            position += 4
            guard position + length <= book.count else {
                throw ImportError.invalid("Повреждён лист расписания")
            }
            let raw = book.subdata(in: position..<(position + length))
            position += length
            if id == 0x000A { break }
            guard raw.count >= 6,
                  let row = raw.v129U16(0),
                  let column = raw.v129U16(2) else { continue }

            if id == 0x00FD,
               let stringIndex = raw.v129U32(6),
               stringIndex < strings.count {
                cells[row, default: [:]][column] = .text(strings[stringIndex])
            } else if id == 0x0203,
                      let number = raw.v129F64(6) {
                cells[row, default: [:]][column] = .number(number)
            } else if id == 0x027E,
                      let rk = raw.v129U32(6) {
                cells[row, default: [:]][column] = .number(decodeRK(rk))
            } else if id == 0x00BD, raw.count >= 10,
                      let last = raw.v129U16(raw.count - 2),
                      last >= column,
                      last - column < 256 {
                for col in column...last {
                    if let rk = raw.v129U32(6 + (col - column) * 6) {
                        cells[row, default: [:]][col] = .number(decodeRK(rk))
                    }
                }
            }
        }

        let expected = [
            0: "Номер рейса",
            1: "Начало периода",
            2: "Конец периода",
            3: "Дни выполнения",
            4: "А/п вылета",
            6: "Время вылета",
            7: "А/п прилета",
            9: "Время прилета",
            10: "Тип ВС",
            12: "Полетное время"
        ]
        for (column, title) in expected {
            let actual = normalizedHeader(cells[0]?[column]?.stringValue ?? "")
            guard actual == normalizedHeader(title) else {
                throw ImportError.invalid("Неожиданный формат расписания: нет столбца «\(title)»")
            }
        }

        var result: [FlightScheduleEntryV129] = []
        for row in cells.keys.sorted() where row > 0 {
            guard let values = cells[row], values[0] != nil else { continue }
            let flight = normalizedFlight(values[0]?.stringValue ?? "")
            guard !flight.isEmpty,
                  let fromSerial = values[1]?.numberValue,
                  let toSerial = values[2]?.numberValue,
                  let from = excelDay(fromSerial),
                  let to = excelDay(toSerial),
                  from <= to else {
                throw ImportError.invalid("Строка \(row + 1): неверный номер рейса или период")
            }

            let weekdays = operatingDays(values[3]?.stringValue ?? "")
            let departure = (values[4]?.stringValue ?? "").uppercased()
            let arrival = (values[7]?.stringValue ?? "").uppercased()
            guard !weekdays.isEmpty,
                  departure.count == 3,
                  arrival.count == 3,
                  let departureMinutes = clockMinutes(values[6]),
                  let arrivalMinutes = clockMinutes(values[9]),
                  let listedFlightMinutes = durationMinutes(values[12]) else {
                throw ImportError.invalid("Строка \(row + 1): не удалось прочитать дни, маршрут или время")
            }

            let recalculated = (arrivalMinutes - departureMinutes + 24 * 60) % (24 * 60)
            guard listedFlightMinutes == recalculated else {
                throw ImportError.invalid(
                    "Строка \(row + 1): полётное время \(listedFlightMinutes) мин не совпадает с интервалом \(recalculated) мин"
                )
            }

            result.append(
                FlightScheduleEntryV129(
                    flightNumber: flight,
                    validFrom: from,
                    validTo: to,
                    operatingWeekdays: weekdays,
                    departure: departure,
                    departureTerminal: terminal(values[5]),
                    departureMinutesUTC: departureMinutes,
                    arrival: arrival,
                    arrivalTerminal: terminal(values[8]),
                    arrivalMinutesUTC: arrivalMinutes,
                    rawAircraftCode: cleanedCell(values[10]),
                    configuration: optionalCell(values[11]),
                    flightMinutes: listedFlightMinutes
                )
            )
        }

        guard !result.isEmpty else {
            throw ImportError.invalid("На листе «UTC» не найдено строк расписания")
        }
        return result
    }

    private static func normalizedHeader(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func normalizedFlight(_ value: String) -> String {
        let digits = value.filter(\.isNumber)
        if !digits.isEmpty {
            return FlightScheduleStoreV129.normalizedFlightNumber(digits)
        }
        if let number = Double(value), number.isFinite {
            return FlightScheduleStoreV129.normalizedFlightNumber(String(Int(number.rounded())))
        }
        return ""
    }

    private static func operatingDays(_ value: String) -> [Int] {
        Array(Set(value.compactMap { character in
            guard let number = character.wholeNumberValue,
                  (1...7).contains(number) else { return nil }
            return number
        })).sorted()
    }

    private static func excelDay(_ serial: Double) -> Date? {
        guard serial.isFinite, serial >= 1, serial < 200_000 else { return nil }
        let days = Int(floor(serial))
        var components = DateComponents()
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 1899
        components.month = 12
        components.day = 30
        guard let epoch = Calendar.gregorianUTC.date(from: components) else { return nil }
        return Calendar.gregorianUTC.date(byAdding: .day, value: days, to: epoch)
    }

    private static func clockMinutes(_ cell: Cell?) -> Int? {
        guard let cell else { return nil }
        switch cell {
        case .number(let value):
            guard value.isFinite else { return nil }
            let fraction = value - floor(value)
            return Int((fraction * 1440).rounded()) % 1440
        case .text(let value):
            let parts = value.split(separator: ":")
            guard parts.count == 2,
                  let hour = Int(parts[0]),
                  let minute = Int(parts[1]),
                  (0...23).contains(hour),
                  (0...59).contains(minute) else { return nil }
            return hour * 60 + minute
        }
    }

    private static func durationMinutes(_ cell: Cell?) -> Int? {
        guard let cell else { return nil }
        switch cell {
        case .number(let value):
            let fraction = value - floor(value)
            return Int((fraction * 1440).rounded())
        case .text(let value):
            if let groups = value.range(
                of: #"^\s*(\d+)\s*ч\s*(\d+)\s*мин\s*$"#,
                options: .regularExpression
            ) {
                let text = String(value[groups])
                let numbers = text.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
                if numbers.count >= 2 { return numbers[0] * 60 + numbers[1] }
            }
            let parts = value.split(separator: ":")
            if parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) {
                return hour * 60 + minute
            }
            return nil
        }
    }

    private static func terminal(_ cell: Cell?) -> String? {
        guard let cell else { return nil }
        let value: String
        switch cell {
        case .text(let text): value = text
        case .number(let number):
            value = number.rounded() == number ? String(Int(number)) : String(number)
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func cleanedCell(_ cell: Cell?) -> String {
        optionalCell(cell) ?? ""
    }

    private static func optionalCell(_ cell: Cell?) -> String? {
        guard let cell else { return nil }
        let value: String
        switch cell {
        case .text(let text): value = text
        case .number(let number):
            value = number.rounded() == number ? String(Int(number)) : String(number)
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private enum Cell {
        case text(String)
        case number(Double)

        var stringValue: String {
            switch self {
            case .text(let value): return value
            case .number(let value):
                return value.rounded() == value ? String(Int(value)) : String(value)
            }
        }

        var numberValue: Double? {
            if case .number(let value) = self { return value }
            return Double(stringValue)
        }
    }

    private typealias Record = BIFFWorkbook.Record

    // Чтение .xls — общее с историей полётов (аудит 05.10, п. 20).
    private static func records(in data: Data) throws -> [Record] {
        try BIFFWorkbook.records(in: data)
    }

    private static func workbookStream(_ file: Data) throws -> Data {
        try BIFFWorkbook.workbookStream(file, notWorkbook: "Выберите файл расписания .xls")
    }

    private static func sharedStrings(_ pieces: [Data]) throws -> [String] {
        try BIFFWorkbook.sharedStrings(pieces)
    }

    private static func decodeRK(_ raw: Int) -> Double {
        BIFFWorkbook.decodeRK(raw)
    }
}


private extension Data {
    func v129U16(_ offset: Int) -> Int? {
        guard offset >= 0, offset + 2 <= count else { return nil }
        return withUnsafeBytes { raw in
            Int(UInt16(littleEndian: raw.loadUnaligned(fromByteOffset: offset, as: UInt16.self)))
        }
    }

    func v129U32(_ offset: Int) -> Int? {
        guard offset >= 0, offset + 4 <= count else { return nil }
        return withUnsafeBytes { raw in
            Int(UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: offset, as: UInt32.self)))
        }
    }

    func v129F64(_ offset: Int) -> Double? {
        guard offset >= 0, offset + 8 <= count else { return nil }
        return withUnsafeBytes { raw in
            Double(bitPattern: UInt64(littleEndian: raw.loadUnaligned(fromByteOffset: offset, as: UInt64.self)))
        }
    }
}


struct AircraftReferenceSettingsV129View: View {
    @ObservedObject private var store = AircraftReferenceStoreV129.shared
    @State private var search = ""

    private var values: [AircraftReferenceV129] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.aircraft }
        return store.aircraft.filter {
            $0.registration.localizedCaseInsensitiveContains(query)
                || $0.surname.localizedCaseInsensitiveContains(query)
                || $0.type.rawValue.localizedCaseInsensitiveContains(query)
                || ($0.oldRegistration?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        List {
            Section {
                TextField("Борт, фамилия или тип ВС", text: $search)
            }

            Section("Воздушные суда · \(values.count)") {
                ForEach(values) { aircraft in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(aircraft.type.rawValue)
                                .font(.subheadline.weight(.semibold))
                            Text(aircraft.registration)
                                .font(.subheadline.monospacedDigit())
                            Spacer()
                            Text(aircraft.surname)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 12) {
                            Text("Старый: \(aircraft.oldRegistration ?? "—")")
                            if let msn = aircraft.msn { Text("MSN: \(msn)") }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Воздушные суда")
        .navigationBarTitleDisplayMode(.inline)
    }
}


struct FlightScheduleDatabaseV130View: View {
    @ObservedObject private var store = FlightScheduleStoreV129.shared
    /// Номер рейса (до 4 цифр).
    @State private var search = ""
    @State private var departureQuery = ""
    @State private var arrivalQuery = ""
    /// Галочка в поле «Прилёт». Выключена — левое поле ищет аэропорт и в вылете, и в прилёте.
    @State private var arrivalEnabled = true
    /// Какая крутилка часов сейчас крутится: "from" / "to".
    @State private var activeHourField: String?
    @State private var highlightMemo = HighlightMemo()
    @State private var typeMenuOpen = false
    @State private var fromFieldFrame: CGRect = .zero
    @State private var toFieldFrame: CGRect = .zero
    /// Вкладка «Тест» (07.10): та же таблица, шрифт крупнее, вся таблица в общей карточке.
    private let cardStyle: Bool

    /// Сортировка по столбцу (тап по заголовку). При входе — по времени UTC по возрастанию.
    private enum SortColumn { case flight, route, time, type, duration }
    @State private var sortColumn: SortColumn = .time
    @State private var sortAscending = true

    init(cardStyle: Bool = true) {
        // Денис 07.10 05:11: основная база — как во «Тесте» (карточка, шрифт крупнее).
        self.cardStyle = cardStyle
    }
    @State private var typeButtonFrame: CGRect = .zero
    /// Часы вылета по UTC: с `fromHour` до `toHour` (24 — до конца суток).
    @State private var fromHour = 0
    @State private var toHour = 24
    @State private var selectedDate = moscowCalendar.startOfDay(for: Date())
    @AppStorage(ScheduleAircraftFilterButton.storageKey) private var groupsRaw = ""
    /// Выбранный рейс: номер + маршрут. Держится при смене дня, пока его не снимут.
    @State private var selectedFlightKey: String?
    /// Запись расписания, раскрытая последней (её дни — сплошной круг).
    @State private var selectedRecordID: String?
    @State private var showCalendarPopover = false
    /// Маршрут, для которого календарь открыли кнопкой «Календарь выполнения» (узкий экран).
    @State private var calendarRouteID: String?

    /// Ширина, с которой календарь стоит справа от таблицы, а не всплывает.
    private static let sideCalendarMinWidth: CGFloat = 860

    private var groups: Set<FlightScheduleAircraftGroupV131> {
        ScheduleAircraftFilterButton.decode(groupsRaw)
    }

    private var groupsBinding: Binding<Set<FlightScheduleAircraftGroupV131>> {
        Binding(
            get: { groups },
            set: { groupsRaw = ScheduleAircraftFilterButton.encode($0) }
        )
    }

    private func passesFilter(_ entry: FlightScheduleEntryV129) -> Bool {
        ScheduleAircraftFilterButton.matches(groups, rawAircraftCode: entry.rawAircraftCode)
    }

    private var exactSearchNumber: String? {
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains(where: \.isNumber) else { return nil }
        let normalized = FlightScheduleStoreV129.normalizedFlightNumber(trimmed)
        return normalized.isEmpty ? nil : normalized
    }

    private var globallyMatchingFlightEntries: [FlightScheduleEntryV129] {
        guard let number = exactSearchNumber else { return [] }
        return store.entries.filter {
            FlightScheduleStoreV129.normalizedFlightNumber($0.flightNumber) == number
                && passesFilter($0)
                && routeMatches($0)
        }
    }

    /// Маршрут по полям: «Вылет → Прилёт» или, без галочки, один аэропорт в любую сторону.
    private func routeMatches(_ entry: FlightScheduleEntryV129) -> Bool {
        if arrivalEnabled {
            return Self.airport(entry.departure, matches: departureQuery)
                && Self.airport(entry.arrival, matches: arrivalQuery)
        }
        let query = departureQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return Self.airport(entry.departure, matches: query) || Self.airport(entry.arrival, matches: query)
    }

    /// Номер, маршрут и часы — то же, что фильтрует список (без даты и типа ВС).
    private func matchesFields(_ entry: FlightScheduleEntryV129) -> Bool {
        if let number = exactSearchNumber,
           FlightScheduleStoreV129.normalizedFlightNumber(entry.flightNumber) != number {
            return false
        }
        guard routeMatches(entry) else { return false }
        let departure = entry.departureMinutesUTC % 1440
        return departure >= fromHour * 60 && departure < toHour * 60
    }

    private var fieldsAreFilled: Bool {
        !search.isEmpty
            || !departureQuery.trimmingCharacters(in: .whitespaces).isEmpty
            || (arrivalEnabled && !arrivalQuery.trimmingCharacters(in: .whitespaces).isEmpty)
            || fromHour != 0 || toHour != 24
    }

    /// Пустое поле — любой аэропорт; иначе начало кода или название/город.
    private static func airport(_ code: String, matches rawQuery: String) -> Bool {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        if code.uppercased().hasPrefix(query.uppercased()) { return true }
        return AirportDatabase.airport(for: code)?.matches(query) ?? false
    }


    private var values: [FlightScheduleEntryV129] {
        store.entries.filter { entry in
            passesFilter(entry)
                && Self.entryDepartsOn(utcDay: selectedUTCDay, entry)
                && matchesFields(entry)
        }
        // Всё по UTC (Денис 07.10 03:50): дни недели расписания заданы по UTC.
        .sorted(by: sortsBefore)
    }

    private static func flightNumberValue(_ entry: FlightScheduleEntryV129) -> Int {
        Int(FlightScheduleStoreV129.normalizedFlightNumber(entry.flightNumber).filter(\.isNumber)) ?? Int.max
    }

    private static func airportName(_ code: String) -> String {
        AirportDatabase.airport(for: code)?.name ?? code
    }

    private func sortsBefore(_ left: FlightScheduleEntryV129, _ right: FlightScheduleEntryV129) -> Bool {
        let order: ComparisonResult
        switch sortColumn {
        case .flight:
            let l = Self.flightNumberValue(left), r = Self.flightNumberValue(right)
            order = l == r ? .orderedSame : (l < r ? .orderedAscending : .orderedDescending)
        case .route:
            // По названиям аэропортов (городов), не по кодам: сначала вылет, потом прилёт.
            let l = Self.airportName(left.departure) + " " + Self.airportName(left.arrival)
            let r = Self.airportName(right.departure) + " " + Self.airportName(right.arrival)
            order = l.localizedCompare(r)
        case .time:
            let l = left.departureMinutesUTC % 1440, r = right.departureMinutesUTC % 1440
            order = l == r ? .orderedSame : (l < r ? .orderedAscending : .orderedDescending)
        case .type:
            order = AircraftFamilyV129.display(left.rawAircraftCode)
                .localizedStandardCompare(AircraftFamilyV129.display(right.rawAircraftCode))
        case .duration:
            let l = left.flightMinutes, r = right.flightMinutes
            order = l == r ? .orderedSame : (l < r ? .orderedAscending : .orderedDescending)
        }
        if order != .orderedSame {
            return sortAscending ? order == .orderedAscending : order == .orderedDescending
        }
        // При равенстве — по времени вылета, затем по номеру.
        let lt = left.departureMinutesUTC % 1440, rt = right.departureMinutesUTC % 1440
        if lt != rt { return lt < rt }
        return Self.flightNumberValue(left) < Self.flightNumberValue(right)
    }

    private func sortHeader(_ title: String, _ column: SortColumn) -> some View {
        Button {
            if sortColumn == column {
                sortAscending.toggle()
            } else {
                sortColumn = column
                sortAscending = true
            }
        } label: {
            HStack(spacing: 3) {
                Text(title)
                if sortColumn == column {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.bold))
                }
            }
            .foregroundStyle(sortColumn == column ? Color.teal : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    private var routeCandidates: [FlightScheduleRouteCandidateV131] {
        let grouped = Dictionary(grouping: globallyMatchingFlightEntries) {
            "\($0.departure)|\($0.arrival)"
        }
        return grouped.values.compactMap { entries in
            guard let first = entries.first else { return nil }
            return FlightScheduleRouteCandidateV131(
                flightNumber: first.flightNumber,
                departure: first.departure,
                arrival: first.arrival,
                entries: entries
            )
        }
        .sorted { ($0.departure, $0.arrival) < ($1.departure, $1.arrival) }
    }

    // MARK: Выбранный рейс и подсветка дней выполнения

    private static func flightKey(_ entry: FlightScheduleEntryV129) -> String {
        "\(FlightScheduleStoreV129.normalizedFlightNumber(entry.flightNumber))|\(entry.departure)|\(entry.arrival)"
    }

    /// Строка выбранного рейса в списке выбранного дня (если в этот день он летает).
    private func selectedRow(in rows: [FlightScheduleEntryV129]) -> FlightScheduleEntryV129? {
        guard let key = selectedFlightKey else { return nil }
        return rows.first { $0.id == selectedRecordID && Self.flightKey($0) == key }
            ?? rows.first { Self.flightKey($0) == key }
    }

    private struct Highlight {
        let title: String
        let primary: Set<String>
        let secondary: Set<String>
        /// Дни, когда рейс летает на неотмеченных в фильтре типах ВС.
        let tertiary: Set<String>
        let legend: String?
    }

    /// Запоминает последнюю подсветку: пересчёт только при смене полей, выбора или расписания.
    private final class HighlightMemo {
        var key = ""
        var value: Highlight?
    }

    private func highlight(rows: [FlightScheduleEntryV129]) -> Highlight? {
        let base = "\(groupsRaw)|\(store.entries.count)|\(FlightScheduleStoreV129.generation)"
        let key: String
        if let flight = selectedFlightKey {
            let record = selectedRow(in: rows)?.id ?? selectedRecordID ?? ""
            key = "1|\(flight)|\(record)|\(base)"
        } else if let route = calendarRouteID {
            key = "R|\(route)|\(search)|\(base)"
        } else if fieldsAreFilled {
            key = "2|\(search)|\(departureQuery)|\(arrivalEnabled)|\(arrivalQuery)|\(fromHour)|\(toHour)|\(base)"
        } else {
            return nil
        }
        if highlightMemo.key == key { return highlightMemo.value }
        let value = computeHighlight(rows: rows)
        highlightMemo.key = key
        highlightMemo.value = value
        return value
    }

    /// Режим 1 (выбранный рейс, главный) → маршрут кнопкой у подсказки → режим 2 (поля фильтра).
    private func computeHighlight(rows: [FlightScheduleEntryV129]) -> Highlight? {
        let allTypes = groups.count >= ScheduleAircraftFilterButton.choices.count
        if let key = selectedFlightKey {
            let sameFlight = store.entries.filter { Self.flightKey($0) == key }
            let entries = sameFlight.filter(passesFilter)
            guard let sample = entries.first ?? sameFlight.first else { return nil }
            let record = selectedRow(in: rows)
                ?? entries.first { $0.id == selectedRecordID }
            let recordDays = record.map { Self.dayKeys(Self.executionDays([$0])) } ?? []
            let allDays = Self.dayKeys(Self.executionDays(entries))
            let otherTypes = allTypes ? [] : Self.dayKeys(Self.executionDays(sameFlight.filter { !passesFilter($0) }))
            let legend = record.map {
                "эта запись \(FlightScheduleStoreV129.shortDay($0.validFrom))–\(FlightScheduleStoreV129.shortDay($0.validTo)), дни \($0.operatingWeekdays.map(String.init).joined())"
            }
            return Highlight(
                title: routeTitle(sample.flightNumber, sample.departure, sample.arrival),
                primary: recordDays,
                secondary: allDays.subtracting(recordDays),
                tertiary: otherTypes.subtracting(allDays),
                legend: legend
            )
        }
        if let id = calendarRouteID, let route = routeCandidates.first(where: { $0.id == id }) {
            return Highlight(
                title: routeTitle(route.flightNumber, route.departure, route.arrival),
                primary: Self.dayKeys(Self.executionDays(route.entries)),
                secondary: [],
                tertiary: [],
                legend: nil
            )
        }
        // Режим 2: всё, что подходит под поля, считается одной записью.
        let matching = store.entries.filter(matchesFields)
        let shown = Self.dayKeys(Self.executionDays(matching.filter(passesFilter)))
        let hidden = allTypes ? [] : Self.dayKeys(Self.executionDays(matching.filter { !passesFilter($0) }))
        return Highlight(
            title: fieldsTitle,
            primary: shown,
            secondary: [],
            tertiary: hidden.subtracting(shown),
            legend: shown.isEmpty ? nil : "по фильтру"
        )
    }

    private var fieldsTitle: String {
        var parts: [String] = []
        if !search.isEmpty { parts.append("Рейс \(search)") }
        let departure = departureQuery.trimmingCharacters(in: .whitespaces).uppercased()
        let arrival = arrivalQuery.trimmingCharacters(in: .whitespaces).uppercased()
        if arrivalEnabled {
            if !departure.isEmpty || !arrival.isEmpty {
                parts.append("\(departure.isEmpty ? "любой" : departure) → \(arrival.isEmpty ? "любой" : arrival)")
            }
        } else if !departure.isEmpty {
            parts.append("\(departure) ⇄")
        }
        if fromHour != 0 || toHour != 24 {
            parts.append(String(format: "%02d–%02d", fromHour, toHour))
        }
        return parts.isEmpty ? "Календарь" : parts.joined(separator: " · ")
    }

    /// Дни вылета по UTC — номера суток от 1970-01-01 (быстро, без календаря).
    /// Запись хранит даты действия в UTC (полночь) и дни недели ISO (1 = пн).
    private static func executionDays(_ entries: [FlightScheduleEntryV129]) -> Set<Int> {
        var result = Set<Int>()
        for entry in entries {
            let first = Int((entry.validFrom.timeIntervalSince1970 / 86_400).rounded(.down))
            let last = Int((entry.validTo.timeIntervalSince1970 / 86_400).rounded(.down))
            guard last >= first else { continue }
            let shift = entry.departureMinutesUTC / 1440
            var weekdays = [Bool](repeating: false, count: 8)
            for day in entry.operatingWeekdays where (1...7).contains(day) { weekdays[day] = true }
            for day in first...last {
                // 01.01.1970 — четверг (ISO 4).
                let iso = ((day + 3) % 7 + 7) % 7 + 1
                if weekdays[iso] { result.insert(day + shift) }
            }
        }
        return result
    }

    private static var dayKeyCache: [Int: String] = [:]

    /// Выбранная дата календаря как сутки UTC (число и месяц те же).
    private var selectedUTCDay: Int {
        let parts = moscowCalendar.dateComponents([.year, .month, .day], from: selectedDate)
        guard let date = Calendar.gregorianUTC.date(
            from: DateComponents(year: parts.year, month: parts.month, day: parts.day)
        ) else { return 0 }
        return Int((date.timeIntervalSince1970 / 86_400).rounded(.down))
    }

    /// Вылетает ли рейс записи в эти сутки UTC.
    private static func entryDepartsOn(utcDay: Int, _ entry: FlightScheduleEntryV129) -> Bool {
        let operating = utcDay - entry.departureMinutesUTC / 1440
        let first = Int((entry.validFrom.timeIntervalSince1970 / 86_400).rounded(.down))
        let last = Int((entry.validTo.timeIntervalSince1970 / 86_400).rounded(.down))
        guard operating >= first, operating <= last else { return false }
        let iso = ((operating + 3) % 7 + 7) % 7 + 1
        return entry.operatingWeekdays.contains(iso)
    }

    private static func dayKeys(_ days: Set<Int>) -> Set<String> {
        Set(days.map { day in
            if let cached = dayKeyCache[day] { return cached }
            let date = Date(timeIntervalSince1970: TimeInterval(day) * 86_400)
            let parts = Calendar.gregorianUTC.dateComponents([.year, .month, .day], from: date)
            let key = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
            dayKeyCache[day] = key
            return key
        })
    }


    private func routeTitle(_ number: String, _ departure: String, _ arrival: String) -> String {
        "Рейс \(FlightScheduleStoreV129.displayFlightNumber(number)) · \(AirportDatabase.displayName(for: departure)) → \(AirportDatabase.displayName(for: arrival))"
    }

    private func calendarView(_ highlight: Highlight?) -> some View {
        ScheduleMonthsCalendarView(
            selectedDate: $selectedDate,
            primaryDays: highlight?.primary ?? [],
            secondaryDays: highlight?.secondary ?? [],
            tertiaryDays: highlight?.tertiary ?? [],
            title: highlight?.title,
            legend: highlight?.legend
        )
    }

    private var fullDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = moscowTimeZone
        formatter.dateFormat = "EE, d MMMM yyyy"
        let text = formatter.string(from: selectedDate)
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    private func flightsCountText(_ count: Int) -> String {
        let tail = count % 100
        let last = count % 10
        let word: String
        if (11...14).contains(tail) { word = "рейсов" }
        else if last == 1 { word = "рейс" }
        else if (2...4).contains(last) { word = "рейса" }
        else { word = "рейсов" }
        return "\(count) \(word)"
    }

    private var selectedDateButtonTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = moscowTimeZone
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: selectedDate).replacingOccurrences(of: ".", with: "")
    }

    var body: some View {
        GeometryReader { geometry in
            let isWide = geometry.size.width >= Self.sideCalendarMinWidth
            let rows = values
            let route = highlight(rows: rows)
            HStack(spacing: 0) {
                tablePane(isWide: isWide, route: route, rows: rows)
                    .contentShape(Rectangle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                if isWide {
                    Divider()
                    calendarView(route)
                        .padding(12)
                        .frame(width: 380)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .overlay {
            // Своё окно типов ВС: под кнопкой; тап мимо — закрыть.
            if typeMenuOpen {
                GeometryReader { geometry in
                    let origin = geometry.frame(in: .global).origin
                    ZStack(alignment: .topLeading) {
                        Color.black.opacity(0.001)
                            .onTapGesture { typeMenuOpen = false }
                        ScheduleAircraftMenuPanel(selection: groupsBinding)
                            .offset(
                                x: typeButtonFrame.minX - origin.x,
                                y: typeButtonFrame.maxY - origin.y + 6
                            )
                    }
                }
            }
        }
        // Тап в любом месте мимо крутилок часов закрывает крутилку.
        .simultaneousGesture(
            SpatialTapGesture(coordinateSpace: .global).onEnded { value in
                guard activeHourField != nil else { return }
                let inside = [fromFieldFrame, toFieldFrame].contains {
                    $0.insetBy(dx: -4, dy: -14).contains(value.location)
                }
                if !inside { activeHourField = nil }
            }
        )
        // Строку «База расписания» не показываем (Денис 07.10 05:11).
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: search) { _, _ in calendarRouteID = nil }
        .onChange(of: fromHour) { _, value in if toHour <= value { toHour = value + 1 } }
        .onChange(of: toHour) { _, value in if fromHour >= value { fromHour = value - 1 } }
    }

    private func tablePane(
        isWide: Bool,
        route: Highlight?,
        rows values: [FlightScheduleEntryV129]
    ) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                if !isWide {
                    Button {
                        showCalendarPopover = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                            Text(selectedDateButtonTitle)
                                .font(.subheadline.monospacedDigit())
                        }
                    }
                    .buttonStyle(.bordered)
                    .popover(isPresented: $showCalendarPopover) {
                        calendarView(route)
                            .padding(12)
                            .frame(width: 380, height: 520)
                            .background(Color(uiColor: .systemBackground))
                            .presentationBackground(Color(uiColor: .systemBackground))
                            .presentationCompactAdaptation(.popover)
                            .onChange(of: selectedDate) { _, _ in showCalendarPopover = false }
                    }
                }

                TextField("Рейс", text: $search)
                    .keyboardType(.numberPad)
                    .scheduleFilterTile()
                    .frame(width: 66)
                    .onChange(of: search) { _, value in
                        let digits = String(value.filter(\.isNumber).prefix(4))
                        if digits != value { search = digits }
                    }

                TextField(arrivalEnabled ? "Вылет" : "Аэропорт", text: $departureQuery)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .scheduleFilterTile()
                    .frame(width: 124)
                // Стрелка меняет вылет и прилёт местами.
                Button {
                    let value = departureQuery
                    departureQuery = arrivalQuery
                    arrivalQuery = value
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                }
                .buttonStyle(.borderless)
                .disabled(!arrivalEnabled)
                TextField("Прилёт", text: $arrivalQuery)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .scheduleFilterTile()
                    .disabled(!arrivalEnabled)
                    .opacity(arrivalEnabled ? 1 : 0.45)
                    .padding(.trailing, 0)
                    .overlay(alignment: .trailing) {
                        // Галочка: выключена — поле серое, пустое, а левое ищет в обе стороны.
                        Button {
                            arrivalEnabled.toggle()
                            arrivalQuery = ""
                        } label: {
                            Image(systemName: arrivalEnabled ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(arrivalEnabled ? Color.teal : Color.secondary)
                        }
                        .buttonStyle(.borderless)
                        .padding(.trailing, 6)
                    }
                    .frame(width: 124)

                ScheduleHourWheelField(
                    title: "с",
                    hour: $fromHour,
                    range: 0...23,
                    isActive: activeHourField == "from",
                    onActivate: { activeHourField = activeHourField == "from" ? nil : "from" },
                    frame: $fromFieldFrame
                )
                ScheduleHourWheelField(
                    title: "до",
                    hour: $toHour,
                    range: 1...24,
                    isActive: activeHourField == "to",
                    onActivate: { activeHourField = activeHourField == "to" ? nil : "to" },
                    frame: $toFieldFrame
                )

                ScheduleAircraftFilterButton(
                    selection: groupsBinding,
                    isOpen: $typeMenuOpen,
                    frame: $typeButtonFrame
                )

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            HStack {
                Text(isWide
                    ? "\(fullDateTitle) · дата вылета по UTC · \(flightsCountText(values.count))"
                    : "Дата вылета по UTC · \(flightsCountText(values.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)

            if values.isEmpty,
               exactSearchNumber != nil,
               !routeCandidates.isEmpty {
                VStack(spacing: 6) {
                    ForEach(routeCandidates) { candidate in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(routeTitle(candidate.flightNumber, candidate.departure, candidate.arrival))
                                    .font(.subheadline.weight(.semibold))
                                Text("В выбранную дату не выполняется")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isWide {
                                if routeCandidates.count > 1 {
                                    Button(calendarRouteID == candidate.id ? "Подсвечено" : "Показать дни") {
                                        calendarRouteID = candidate.id
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            } else {
                                Button("Календарь выполнения") {
                                    calendarRouteID = candidate.id
                                    showCalendarPopover = true
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        )
                    }
                }
                .padding(.horizontal, 12)
            }

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    sortHeader("Рейс", .flight).frame(width: numberWidth, alignment: .leading)
                    sortHeader("Маршрут", .route).frame(maxWidth: .infinity, alignment: .leading)
                    sortHeader("Время UTC", .time).frame(width: timeWidth, alignment: .leading)
                    sortHeader("Тип ВС", .type).frame(width: typeWidth, alignment: .leading)
                    sortHeader("Полётное время", .duration).frame(width: durationWidth, alignment: .center)
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(cardStyle ? Color.clear : Color(uiColor: .secondarySystemGroupedBackground))
                if cardStyle { Divider() }

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if let key = selectedFlightKey,
                               selectedRow(in: values) == nil,
                               let sample = store.entries.first(where: { Self.flightKey($0) == key }) {
                                HStack(spacing: 10) {
                                    Text("\(routeTitle(sample.flightNumber, sample.departure, sample.arrival)) в этот день не выполняется")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button("Снять выделение") {
                                        selectedFlightKey = nil
                                        selectedRecordID = nil
                                    }
                                    .controlSize(.small)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.teal.opacity(0.10))
                                Divider()
                            }
                            ForEach(values) { entry in
                                VStack(spacing: 0) {
                                    scheduleRow(entry, expanded: selectedRow(in: values)?.id == entry.id)
                                }
                                .id(entry.id)
                            }
                        }
                    }
                    .onChange(of: selectedDate) { _, _ in
                        // Выбранный рейс в новом дне: раскрыть его запись и прокрутить к нему.
                        guard let row = selectedRow(in: self.values) else { return }
                        selectedRecordID = row.id
                        DispatchQueue.main.async {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                proxy.scrollTo(row.id, anchor: .center)
                            }
                        }
                    }
                }
            }
            // «Тест»: вся таблица — в общей карточке.
            .background {
                if cardStyle {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cardStyle ? 14 : 0, style: .continuous))
            .padding(cardStyle ? 12 : 0)
        }
    }

    // Ширины столбцов и шрифты — прежние (Денис 07.10 05:23: шрифт не трогать, только карточка).
    private var numberWidth: CGFloat { 54 }
    private var timeWidth: CGFloat { 104 }
    private var typeWidth: CGFloat { 70 }
    private var durationWidth: CGFloat { 104 }
    private var mainFont: Font { .subheadline }
    private var cellFont: Font { .caption }

    @ViewBuilder
    private func scheduleRow(_ entry: FlightScheduleEntryV129, expanded isExpanded: Bool) -> some View {
        Button {
            if isExpanded {
                selectedFlightKey = nil
                selectedRecordID = nil
            } else {
                selectedFlightKey = Self.flightKey(entry)
                selectedRecordID = entry.id
            }
        } label: {
            HStack(spacing: 8) {
                Text(FlightScheduleStoreV129.displayFlightNumber(entry.flightNumber))
                    .font(mainFont.weight(.semibold).monospacedDigit())
                    .frame(width: numberWidth, alignment: .leading)
                Text("\(AirportDatabase.displayName(for: entry.departure)) → \(AirportDatabase.displayName(for: entry.arrival))")
                    .font(mainFont)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("\(clock(entry.departureMinutesUTC))–\(clock(entry.arrivalMinutesUTC))")
                    .font(cellFont.monospacedDigit())
                    .frame(width: timeWidth, alignment: .leading)
                Text(AircraftFamilyV129.display(entry.rawAircraftCode))
                    .font(cellFont.weight(.semibold))
                    .frame(width: typeWidth, alignment: .leading)
                Text(timeText(entry.flightMinutes))
                    .font(cellFont.weight(.semibold).monospacedDigit())
                    .frame(width: durationWidth, alignment: .center)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(isExpanded ? Color.teal.opacity(0.10) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if isExpanded {
            // Доп. информация — по тем же столбцам: МСК под UTC, код и компоновка под типом ВС.
            HStack(spacing: 8) {
                Color.clear.frame(width: numberWidth, height: 1)
                Text("\(FlightScheduleStoreV129.shortDay(entry.validFrom))–\(FlightScheduleStoreV129.shortDay(entry.validTo)) · дни \(entry.operatingWeekdays.map(String.init).joined())")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(moscowClock(entry.departureMinutesUTC))–\(moscowClock(entry.arrivalMinutesUTC))")
                    .monospacedDigit()
                    .frame(width: timeWidth, alignment: .leading)
                    .overlay(alignment: .leading) {
                        Text("МСК")
                            .fixedSize()
                            .offset(x: -30)
                    }
                Text(entry.rawAircraftCode + (entry.configuration.map { "  ·  \($0)" } ?? ""))
                    .lineLimit(1)
                    .frame(width: typeWidth + 8 + durationWidth, alignment: .leading)
            }
            .font(cellFont)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.bottom, 5)
            .background(Color.teal.opacity(0.10))
        }
        Divider()
    }

    private func clock(_ minutes: Int) -> String {
        String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }

    /// Время по Москве из минут UTC (Москва — UTC+3 круглый год).
    private func moscowClock(_ utcMinutes: Int) -> String {
        let offset = moscowTimeZone.secondsFromGMT() / 60
        let value = ((utcMinutes + offset) % 1440 + 1440) % 1440
        return clock(value)
    }
}


private struct FlightScheduleRouteCandidateV131: Identifiable {
    let flightNumber: String
    let departure: String
    let arrival: String
    let entries: [FlightScheduleEntryV129]
    var id: String { "\(FlightScheduleStoreV129.normalizedFlightNumber(flightNumber))|\(departure)|\(arrival)" }
}


struct FlightScheduleSettingsV129View: View {
    @ObservedObject private var store = FlightScheduleStoreV129.shared

    /// Коды из расписания, которых нет в справочнике аэропортов (пришли скрин — допишем).
    private var unknownAirports: [String] {
        var codes = Set<String>()
        for entry in store.entries {
            codes.insert(entry.departure)
            codes.insert(entry.arrival)
        }
        return codes.filter { !AirportDatabase.isKnown($0) }.sorted()
    }
    @State private var showImporter = false
    @State private var message = ""
    @State private var showMessage = false
    @State private var showDelete = false
    @State private var pendingDeleteImport: FlightScheduleImportRecordV129?

    var body: some View {
        List {
            Section("Состояние") {
                LabeledContent("Строк в базе", value: String(store.entries.count))
                LabeledContent("Покрытие", value: store.coverageText)
                LabeledContent("Импортов", value: String(store.imports.count))
                LabeledContent("Аэропорты без названия", value: String(unknownAirports.count))
                if !unknownAirports.isEmpty {
                    Text(unknownAirports.joined(separator: ", "))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                NavigationLink {
                    FlightScheduleDatabaseV130View()
                } label: {
                    Label("Открыть базу расписания", systemImage: "list.bullet.rectangle")
                }
                .disabled(store.entries.isEmpty)
            }

            Section {
                Button {
                    showImporter = true
                } label: {
                    Label("Импортировать расписание", systemImage: "square.and.arrow.down")
                }

                Button("Удалить все расписания", role: .destructive) {
                    showDelete = true
                }
                .disabled(store.entries.isEmpty)
            } footer: {
                Text("Загружается .xls с листом «UTC». Вид перевозки игнорируется; данные используются только как плановое расписание.")
            }

            if !store.imports.isEmpty {
                Section("Загруженные расписания") {
                    ForEach(store.imports) { value in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(FlightScheduleStoreV129.shortDay(value.validFrom))–\(FlightScheduleStoreV129.shortDay(value.validTo))")
                            .font(.subheadline.weight(.semibold))
                        Text("\(value.rowCount.formatted(.number.grouping(.automatic))) строк · импорт \(importDate(value.importedAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(role: .destructive) {
                        pendingDeleteImport = value
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
                }
            }
        }
        .navigationTitle("Расписание рейсов")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType(filenameExtension: "xls") ?? .data]
        ) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                let summary = try store.importXLS(data: data, sourceName: url.lastPathComponent)
        if summary.unchanged {
            message = "Это расписание уже загружено. Обновлений нет."
        } else {
            message = "Импорт завершён. Добавлено: \(summary.added), обновлено: \(summary.updated), удалено устаревших: \(summary.removed). В базе: \(summary.total) строк."
        }
            } catch {
                message = error.localizedDescription
            }
            showMessage = true
        }
        .alert("Расписание рейсов", isPresented: $showMessage) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(message)
        }
        .alert("Удалить всё расписание?", isPresented: $showDelete) {
            Button("Отмена", role: .cancel) { }
            Button("Удалить", role: .destructive) { store.deleteAll() }
        } message: {
            Text("Будет очищена только локальная база расписания рейсов. История и планы не изменятся.")
        }
    .alert(
        "Удалить выбранное расписание?",
        isPresented: Binding(
            get: { pendingDeleteImport != nil },
            set: { if !$0 { pendingDeleteImport = nil } }
        )
    ) {
        Button("Отмена", role: .cancel) { pendingDeleteImport = nil }
        Button("Удалить", role: .destructive) {
            if let value = pendingDeleteImport {
                store.deleteImport(id: value.id)
            }
            pendingDeleteImport = nil
        }
    } message: {
        if let value = pendingDeleteImport {
            Text("\(FlightScheduleStoreV129.shortDay(value.validFrom))–\(FlightScheduleStoreV129.shortDay(value.validTo)) будет удалено из локальной базы.")
        }
    }

    }

    private func importDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = moscowTimeZone
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter.string(from: date)
    }
}
