import Foundation
import SwiftUI
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
        case "A320A", "A320S": return .a320S
        case "A320N": return .a320N
        case "A321", "321": return .a321
        case "A321B", "A321S": return .a321S
        case "A321Q", "A321N": return .a321N
        default: return nil
        }
    }

    static func display(_ raw: String) -> String {
        normalized(raw)?.rawValue ?? raw
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
            flightNumber,
            FlightScheduleStoreV129.dayKey(validFrom),
            FlightScheduleStoreV129.dayKey(validTo),
            operatingWeekdays.map(String.init).joined(separator: ","),
            departure,
            arrival
        ].joined(separator: "|")
    }
}


struct FlightScheduleImportRecordV129: Identifiable, Codable, Hashable {
    let id: UUID
    let importedAt: Date
    let validFrom: Date
    let validTo: Date
    let rowCount: Int
    let sourceName: String
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
    func importXLS(data: Data, sourceName: String) throws -> (added: Int, updated: Int, total: Int) {
        let parsed = try FlightScheduleXLSParserV129.parse(data)
        var byKey = Dictionary(uniqueKeysWithValues: entries.map { ($0.identityKey, $0) })
        var added = 0
        var updated = 0

        for value in parsed {
            if let old = byKey[value.identityKey] {
                if old != value {
                    byKey[value.identityKey] = value
                    updated += 1
                }
            } else {
                byKey[value.identityKey] = value
                added += 1
            }
        }

        entries = byKey.values.sorted {
            if $0.flightNumber == $1.flightNumber {
                if $0.validFrom == $1.validFrom { return $0.departure < $1.departure }
                return $0.validFrom < $1.validFrom
            }
            return ($0.flightNumber.localizedStandardCompare($1.flightNumber) == .orderedAscending)
        }

        if let from = parsed.map(\.validFrom).min(),
           let to = parsed.map(\.validTo).max() {
            let signature = "\(Self.dayKey(from))|\(Self.dayKey(to))|\(parsed.count)|\(sourceName)"
            imports.removeAll {
                "\(Self.dayKey($0.validFrom))|\(Self.dayKey($0.validTo))|\($0.rowCount)|\($0.sourceName)" == signature
            }
            imports.insert(
                FlightScheduleImportRecordV129(
                    id: UUID(),
                    importedAt: Date(),
                    validFrom: from,
                    validTo: to,
                    rowCount: parsed.count,
                    sourceName: sourceName
                ),
                at: 0
            )
        }
        rebuildIndex()
        save()
        return (added, updated, entries.count)
    }

    func deleteAll() {
        entries = []
        imports = []
        rebuildIndex()
        save()
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

    func uniqueMatch(
        flightNumber: String,
        moscowDate: Date,
        departureHint: String? = nil,
        arrivalHint: String? = nil
    ) -> FlightScheduleMatchV129? {
        let exact = matches(
            flightNumber: flightNumber,
            moscowDate: moscowDate,
            departureHint: departureHint,
            arrivalHint: arrivalHint
        )
        if exact.count == 1 { return exact[0] }
        if departureHint != nil || arrivalHint != nil { return nil }

        let withoutRoute = matches(
            flightNumber: flightNumber,
            moscowDate: moscowDate,
            departureHint: nil,
            arrivalHint: nil
        )
        return withoutRoute.count == 1 ? withoutRoute[0] : nil
    }

    static func normalizedFlightNumber(_ raw: String) -> String {
        let digits = raw.uppercased()
            .replacingOccurrences(of: "SU", with: "")
            .filter(\.isNumber)
        guard let value = Int(digits) else { return "" }
        return String(value)
    }

    static func airportCode(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let upper = trimmed.uppercased()

        if upper.contains("ШЕРЕМЕТЬЕВО") || upper == "Ш" { return "SVO" }

        if let slash = upper.firstIndex(of: "/") {
            let value = String(upper[..<slash]).filter(\.isLetter)
            if value.count == 3 { return value }
        }

        if let regex = try? NSRegularExpression(pattern: #"\(([A-Z]{3})(?:/[A-Z0-9]+)?\)"#),
           let match = regex.firstMatch(
                in: upper,
                range: NSRange(location: 0, length: (upper as NSString).length)
           ),
           match.numberOfRanges >= 2 {
            return (upper as NSString).substring(with: match.range(at: 1))
        }

        let letters = upper.filter(\.isLetter)
        if letters.count == 3 { return letters }

        let byName = AirportDatabase.airports.filter { airport in
            airport.name.caseInsensitiveCompare(trimmed) == .orderedSame
        }
        if byName.count == 1 { return byName[0].iata }
        return nil
    }

    nonisolated static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    nonisolated static func shortDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: Self.entriesKey),
           let values = try? JSONDecoder().decode([FlightScheduleEntryV129].self, from: data) {
            entries = values
        }
        if let data = UserDefaults.standard.data(forKey: Self.importsKey),
           let values = try? JSONDecoder().decode([FlightScheduleImportRecordV129].self, from: data) {
            imports = values
        }
    }

    private func rebuildIndex() {
        entriesByFlightNumber = Dictionary(grouping: entries) { entry in
            Self.normalizedFlightNumber(entry.flightNumber)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Self.entriesKey)
        }
        if let data = try? JSONEncoder().encode(imports) {
            UserDefaults.standard.set(data, forKey: Self.importsKey)
        }
    }
}


private extension Calendar {
    static var gregorianUTC: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
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

    private struct Record {
        let id: Int
        let bytes: Data
    }

    private static func records(in data: Data) throws -> [Record] {
        var result: [Record] = []
        var position = 0
        while position + 4 <= data.count {
            guard let id = data.v129U16(position),
                  let length = data.v129U16(position + 2) else { break }
            position += 4
            guard position + length <= data.count else {
                throw ImportError.invalid("Повреждены записи XLS")
            }
            result.append(
                Record(
                    id: id,
                    bytes: data.subdata(in: position..<(position + length))
                )
            )
            position += length
        }
        return result
    }

    private static func workbookStream(_ file: Data) throws -> Data {
        guard file.count >= 512,
              Array(file.prefix(8)) == [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1],
              let sectorShift = file.v129U16(30),
              sectorShift == 9 || sectorShift == 12,
              let fatCount = file.v129U32(44),
              let directory = file.v129U32(48),
              let difatStart = file.v129U32(68),
              let difatCount = file.v129U32(72) else {
            throw ImportError.invalid("Выберите файл расписания .xls")
        }

        let size = 1 << sectorShift
        func sector(_ sid: Int) throws -> Data {
            guard sid >= 0, sid < 0xFFFFFFF0 else {
                throw ImportError.invalid("Повреждена цепочка секторов XLS")
            }
            let start = 512 + sid * size
            guard start >= 512, start + size <= file.count else {
                throw ImportError.invalid("Не хватает данных в XLS")
            }
            return file.subdata(in: start..<(start + size))
        }

        var fatSectors: [Int] = []
        for value in 0..<109 {
            if let sid = file.v129U32(76 + value * 4), sid != 0xFFFFFFFF {
                fatSectors.append(sid)
            }
        }
        var nextDifat = difatStart
        for _ in 0..<difatCount {
            let block = try sector(nextDifat)
            for value in 0..<(size / 4 - 1) {
                if let sid = block.v129U32(value * 4), sid != 0xFFFFFFFF {
                    fatSectors.append(sid)
                }
            }
            nextDifat = block.v129U32(size - 4) ?? 0xFFFFFFFE
        }
        guard fatSectors.count >= fatCount, fatCount < 100_000 else {
            throw ImportError.invalid("Повреждена таблица секторов XLS")
        }

        var fat: [Int] = []
        for sid in fatSectors.prefix(fatCount) {
            let block = try sector(sid)
            for value in 0..<(size / 4) {
                fat.append(block.v129U32(value * 4) ?? 0xFFFFFFFF)
            }
        }

        func chain(_ first: Int, limit: Int) throws -> Data {
            var output = Data()
            var sid = first
            var visited = Set<Int>()
            while sid != 0xFFFFFFFE {
                guard sid >= 0,
                      sid < fat.count,
                      !visited.contains(sid),
                      visited.count < limit else {
                    throw ImportError.invalid("Повреждена цепочка XLS")
                }
                visited.insert(sid)
                output.append(try sector(sid))
                sid = fat[sid]
            }
            return output
        }

        let entries = try chain(directory, limit: file.count / size + 1)
        for offset in stride(from: 0, to: max(0, entries.count - 127), by: 128) {
            guard let length = entries.v129U16(offset + 64),
                  length >= 2,
                  length <= 64,
                  entries[offset + 66] == 2 else { continue }
            let name = String(
                data: entries.subdata(in: offset..<(offset + length - 2)),
                encoding: .utf16LittleEndian
            )
            if name == "Workbook" || name == "Book" {
                guard let first = entries.v129U32(offset + 116),
                      let byteCount = entries.v129U32(offset + 120),
                      byteCount >= 4096 else {
                    throw ImportError.invalid("Повреждена книга XLS")
                }
                let stream = try chain(first, limit: byteCount / size + 2)
                guard stream.count >= byteCount else {
                    throw ImportError.invalid("Книга XLS обрезана")
                }
                return stream.prefix(byteCount)
            }
        }
        throw ImportError.invalid("Книга Excel не найдена")
    }

    private static func sharedStrings(_ pieces: [Data]) throws -> [String] {
        var cursor = StringCursor(pieces: pieces)
        guard let total = cursor.u32(),
              let unique = cursor.u32(),
              total >= unique,
              unique < 1_000_000 else {
            throw ImportError.invalid("Повреждён словарь строк XLS")
        }
        var result: [String] = []
        for _ in 0..<unique {
            guard let count = cursor.u16(),
                  let flags = cursor.u8() else {
                throw ImportError.invalid("Повреждена строка XLS")
            }
            let rich = flags & 8 != 0 ? cursor.u16() : 0
            let phonetic = flags & 4 != 0 ? cursor.u32() : 0
            guard let runs = rich,
                  let extra = phonetic,
                  let value = cursor.characters(count, unicode: flags & 1 != 0),
                  cursor.skip(runs * 4 + extra) else {
                throw ImportError.invalid("Повреждена строка XLS")
            }
            result.append(value)
        }
        return result
    }

    private struct StringCursor {
        let pieces: [Data]
        var part = 0
        var offset = 0

        mutating func u8() -> Int? {
            while part < pieces.count && offset >= pieces[part].count {
                part += 1
                offset = 0
            }
            guard part < pieces.count else { return nil }
            defer { offset += 1 }
            return Int(pieces[part][offset])
        }

        mutating func u16() -> Int? {
            guard let a = u8(), let b = u8() else { return nil }
            return a | b << 8
        }

        mutating func u32() -> Int? {
            guard let a = u16(), let b = u16() else { return nil }
            return a | b << 16
        }

        mutating func skip(_ bytes: Int) -> Bool {
            guard bytes >= 0, bytes < 10_000_000 else { return false }
            for _ in 0..<bytes where u8() == nil { return false }
            return true
        }

        mutating func characters(_ count: Int, unicode initial: Bool) -> String? {
            var unicode = initial
            var units: [UInt16] = []
            for _ in 0..<count {
                if part < pieces.count && offset == pieces[part].count {
                    part += 1
                    offset = 0
                    guard let flag = u8() else { return nil }
                    unicode = flag & 1 != 0
                }
                guard let first = u8() else { return nil }
                if unicode {
                    guard let second = u8() else { return nil }
                    units.append(UInt16(first | second << 8))
                } else {
                    units.append(UInt16(first))
                }
            }
            return String(decoding: units, as: UTF16.self)
        }
    }

    private static func decodeRK(_ raw: Int) -> Double {
        let value: Double
        if raw & 2 != 0 {
            value = Double(Int32(bitPattern: UInt32(raw)) >> 2)
        } else {
            value = Double(bitPattern: UInt64(raw & ~3) << 32)
        }
        return raw & 1 != 0 ? value / 100 : value
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
    @State private var search = ""

    private var values: [FlightScheduleEntryV129] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.entries }
        let normalizedNumber = FlightScheduleStoreV129.normalizedFlightNumber(query)
        return store.entries.filter { entry in
            (!normalizedNumber.isEmpty
                && FlightScheduleStoreV129.normalizedFlightNumber(entry.flightNumber) == normalizedNumber)
                || entry.departure.localizedCaseInsensitiveContains(query)
                || entry.arrival.localizedCaseInsensitiveContains(query)
                || (AirportDatabase.airport(for: entry.departure)?.name.localizedCaseInsensitiveContains(query) ?? false)
                || (AirportDatabase.airport(for: entry.arrival)?.name.localizedCaseInsensitiveContains(query) ?? false)
                || entry.rawAircraftCode.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        List {
            Section {
                TextField("Рейс, аэропорт или тип ВС", text: $search)
                    .textInputAutocapitalization(.characters)
            }

            Section("Строки · \(values.count)") {
                ForEach(values) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(FlightScheduleStoreV129.normalizedFlightNumber(entry.flightNumber))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                            Text("\(entry.departure) → \(entry.arrival)")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(timeText(entry.flightMinutes))
                                .font(.caption.monospacedDigit())
                        }
                        Text("\(FlightScheduleStoreV129.shortDay(entry.validFrom))–\(FlightScheduleStoreV129.shortDay(entry.validTo)) · дни \(entry.operatingWeekdays.map(String.init).joined()) · UTC \(clock(entry.departureMinutesUTC))–\(clock(entry.arrivalMinutesUTC)) · \(entry.rawAircraftCode)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("База расписания")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func clock(_ minutes: Int) -> String {
        String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }
}


struct FlightScheduleSettingsV129View: View {
    @ObservedObject private var store = FlightScheduleStoreV129.shared
    @State private var showImporter = false
    @State private var message = ""
    @State private var showMessage = false
    @State private var showDelete = false

    var body: some View {
        List {
            Section("Состояние") {
                LabeledContent("Строк в базе", value: String(store.entries.count))
                LabeledContent("Покрытие", value: store.coverageText)
                LabeledContent("Импортов", value: String(store.imports.count))

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

                Button("Удалить расписание", role: .destructive) {
                    showDelete = true
                }
                .disabled(store.entries.isEmpty)
            } footer: {
                Text("Загружается .xls с листом «UTC». Вид перевозки игнорируется; данные используются только как плановое расписание.")
            }

            if !store.imports.isEmpty {
                Section("Загруженные расписания") {
                    ForEach(store.imports) { value in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(FlightScheduleStoreV129.shortDay(value.validFrom))–\(FlightScheduleStoreV129.shortDay(value.validTo))")
                                .font(.subheadline.weight(.semibold))
                            Text("\(value.rowCount.formatted(.number.grouping(.automatic))) строк · импорт \(importDate(value.importedAt))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                message = "Импорт завершён. Добавлено: \(summary.added), обновлено: \(summary.updated). В базе: \(summary.total) строк."
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
    }

    private func importDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = moscowTimeZone
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter.string(from: date)
    }
}
