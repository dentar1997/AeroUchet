import Foundation

// The pilot portal exports BIFF8 .xls files (an OLE compound document).
// Decode only the records needed for the "Рейсы" sheet; reject other formats.
enum PortalFlightHistory {
    enum ImportError: LocalizedError {
        case invalid(String)

        var errorDescription: String? {
            switch self {
            case .invalid(let reason): return reason
            }
        }
    }

    static func parse(_ data: Data) throws -> [FlightLeg] {
        let book = try workbookStream(data)
        let records = try records(in: book)
        var sheetOffset: Int?
        var strings: [String] = []
        var date1904 = false
        var index = 0
        while index < records.count {
            let record = records[index]
            if record.id == 0x0085, record.bytes.count >= 8 {
                let nameLength = Int(record.bytes[6])
                let unicode = record.bytes[7] & 1 != 0
                let nameStart = 8
                let nameSize = nameLength * (unicode ? 2 : 1)
                guard record.bytes.count >= nameStart + nameSize else { throw ImportError.invalid("Повреждён список листов XLS") }
                let nameData = record.bytes.subdata(in: nameStart..<(nameStart + nameSize))
                let name = unicode ? String(data: nameData, encoding: .utf16LittleEndian) : String(data: nameData, encoding: .windowsCP1252)
                if name == "Рейсы" { sheetOffset = Int(record.bytes.u32(0)!) }
            }
            if record.id == 0x0022 { date1904 = record.bytes.u16(0) == 1 }
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
        guard !date1904, let offset = sheetOffset else { throw ImportError.invalid("Не найден лист «Рейсы» с обычными датами Excel") }
        guard offset >= 0, offset < book.count else { throw ImportError.invalid("Неверный адрес листа «Рейсы»") }
        var cells: [Int: [Int: Cell]] = [:]
        var position = offset
        while position + 4 <= book.count {
            let id = book.u16(position)!
            let length = book.u16(position + 2)!
            position += 4
            guard position + length <= book.count else { throw ImportError.invalid("Повреждён лист XLS") }
            let raw = book.subdata(in: position..<(position + length))
            position += length
            if id == 0x000A { break }
            guard raw.count >= 6 else { continue }
            let row = raw.u16(0)!
            let column = raw.u16(2)!
            if id == 0x00FD, let stringIndex = raw.u32(6), stringIndex < strings.count {
                cells[row, default: [:]][column] = .text(strings[stringIndex])
            } else if id == 0x0203, let number = raw.f64(6) {
                cells[row, default: [:]][column] = .number(number)
            } else if id == 0x027E, let rk = raw.u32(6) {
                cells[row, default: [:]][column] = .number(decodeRK(rk))
            } else if id == 0x00BD, raw.count >= 10 {
                let first = column
                let last = raw.u16(raw.count - 2)!
                if last >= first && last - first < 256 {
                    for col in first...last {
                        if let rk = raw.u32(6 + (col - first) * 6) {
                            cells[row, default: [:]][col] = .number(decodeRK(rk))
                        }
                    }
                }
            }
        }
        let expected = [3: "Номер рейса", 5: "Аэропорт взлёта", 6: "Аэропорт посадки", 9: "Фактическое начало работы", 10: "Время включения двигателей", 11: "Фактическая дата взлёта", 12: "Фактическая дата посадки", 13: "Время выключения двигателей", 14: "Фактическое завершение работы"]
        for (col, title) in expected where cells[0]?[col]?.text != title {
            throw ImportError.invalid("Неожиданный формат выгрузки: нет столбца «\(title)»")
        }
        var flights: [FlightLeg] = []
        for row in cells.keys.sorted() where row > 0 {
            guard let values = cells[row], values[3] != nil else { continue }
            func text(_ col: Int) -> String { values[col]?.text ?? "" }
            var dates: [Date] = []
            for col in 9...14 {
                guard let serial = values[col]?.number, serial.isFinite, serial >= 1, serial < 200_000 else {
                    throw ImportError.invalid("Строка \(row + 1): отсутствует дата в столбце \(col + 1)")
                }
                let minutes = Int((serial * 1440).rounded())
                let utc = excelEpoch.addingTimeInterval(TimeInterval(minutes * 60))
                var components = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: utc)
                components.timeZone = moscowTimeZone
                guard let date = moscowCalendar.date(from: components) else {
                    throw ImportError.invalid("Строка \(row + 1): неверная дата")
                }
                dates.append(date)
            }
            guard zip(dates, dates.dropFirst()).allSatisfy({ $0.0 <= $0.1 }),
                  !text(5).isEmpty, !text(6).isEmpty else {
                throw ImportError.invalid("Строка \(row + 1): неверная последовательность времени или аэропорт")
            }
            let times = PortalFlightTimes(workStart: dates[0], engineOn: dates[1], takeoff: dates[2], landing: dates[3], engineOff: dates[4], workEnd: dates[5])
            flights.append(FlightLeg(
                date: formatDate(dates[1]), flightNumber: text(3),
                departure: text(5), arrival: text(6), aircraft: text(1),
                registration: text(2), plannedDeparture: "",
                workStart: formatClock(dates[0]), engineOn: formatClock(dates[1]),
                takeoff: formatClock(dates[2]), landing: formatClock(dates[3]),
                engineOff: formatClock(dates[4]), portalTimes: times
            ))
        }
        guard !flights.isEmpty else { throw ImportError.invalid("На листе «Рейсы» нет рейсов") }
        return flights
    }

    private static let excelEpoch: Date = {
        var parts = DateComponents()
        parts.timeZone = TimeZone(secondsFromGMT: 0)
        parts.year = 1899; parts.month = 12; parts.day = 30
        return moscowCalendar.date(from: parts)!
    }()

    private enum Cell {
        case text(String), number(Double)
        var text: String? { if case .text(let value) = self { return value }; return nil }
        var number: Double? { if case .number(let value) = self { return value }; return nil }
    }

    private struct Record { let id: Int; let bytes: Data }

    private static func records(in data: Data) throws -> [Record] {
        var result: [Record] = []
        var pos = 0
        while pos + 4 <= data.count {
            let id = data.u16(pos)!
            let length = data.u16(pos + 2)!
            pos += 4
            guard pos + length <= data.count else { throw ImportError.invalid("Повреждены записи XLS") }
            result.append(Record(id: id, bytes: data.subdata(in: pos..<(pos + length))))
            pos += length
        }
        return result
    }

    private static func workbookStream(_ file: Data) throws -> Data {
        guard file.count >= 512, Array(file.prefix(8)) == [0xD0,0xCF,0x11,0xE0,0xA1,0xB1,0x1A,0xE1],
              let sectorShift = file.u16(30), sectorShift == 9 || sectorShift == 12,
              let fatCount = file.u32(44), let directory = file.u32(48),
              let difatStart = file.u32(68), let difatCount = file.u32(72) else {
            throw ImportError.invalid("Выберите файл истории рейсов .xls с портала пилотов")
        }
        let size = 1 << sectorShift
        func sector(_ sid: Int) throws -> Data {
            guard sid >= 0, sid < 0xFFFFFFF0 else { throw ImportError.invalid("Повреждена цепочка секторов XLS") }
            let start = 512 + sid * size
            guard start >= 512, start + size <= file.count else { throw ImportError.invalid("Не хватает данных в XLS") }
            return file.subdata(in: start..<(start + size))
        }
        var fatSectors: [Int] = []
        for n in 0..<109 {
            if let sid = file.u32(76 + n * 4), sid != 0xFFFFFFFF { fatSectors.append(sid) }
        }
        var nextDifat = difatStart
        for _ in 0..<difatCount {
            let data = try sector(nextDifat)
            for n in 0..<(size / 4 - 1) {
                let sid = data.u32(n * 4)!
                if sid != 0xFFFFFFFF { fatSectors.append(sid) }
            }
            nextDifat = data.u32(size - 4)!
        }
        guard fatSectors.count >= fatCount, fatCount < 100_000 else { throw ImportError.invalid("Повреждена таблица секторов XLS") }
        var fat: [Int] = []
        for sid in fatSectors.prefix(fatCount) {
            let data = try sector(sid)
            for n in 0..<(size / 4) { fat.append(data.u32(n * 4)!) }
        }
        func chain(_ first: Int, limit: Int) throws -> Data {
            var output = Data()
            var sid = first
            var visited = Set<Int>()
            while sid != 0xFFFFFFFE {
                guard sid >= 0, sid < fat.count, !visited.contains(sid), visited.count < limit else {
                    throw ImportError.invalid("Повреждена цепочка XLS")
                }
                visited.insert(sid)
                output.append(try sector(sid))
                sid = fat[sid]
            }
            return output
        }
        let entries = try chain(directory, limit: file.count / size + 1)
        for offset in stride(from: 0, to: entries.count - 127, by: 128) {
            guard let length = entries.u16(offset + 64), length >= 2, length <= 64,
                  entries[offset + 66] == 2 else { continue }
            let name = String(data: entries.subdata(in: offset..<(offset + length - 2)), encoding: .utf16LittleEndian)
            if name == "Workbook" || name == "Book" {
                guard let first = entries.u32(offset + 116), let bytes = entries.u32(offset + 120), bytes >= 4096 else {
                    throw ImportError.invalid("Слишком короткая или повреждённая книга XLS")
                }
                let stream = try chain(first, limit: (bytes + size - 1) / size + 1)
                guard stream.count >= bytes else { throw ImportError.invalid("Книга XLS обрезана") }
                return stream.prefix(bytes)
            }
        }
        throw ImportError.invalid("Книга Excel не найдена в файле")
    }

    private static func sharedStrings(_ pieces: [Data]) throws -> [String] {
        var cursor = StringCursor(pieces: pieces)
        guard let total = cursor.u32(), let unique = cursor.u32(), total >= unique, unique < 1_000_000 else {
            throw ImportError.invalid("Повреждён словарь строк XLS")
        }
        var result: [String] = []
        for _ in 0..<unique {
            guard let count = cursor.u16(), let flags = cursor.u8() else { throw ImportError.invalid("Повреждена строка XLS") }
            let rich = flags & 8 != 0 ? cursor.u16() : 0
            let phonetic = flags & 4 != 0 ? cursor.u32() : 0
            guard let runs = rich, let extra = phonetic, let value = cursor.characters(count, unicode: flags & 1 != 0),
                  cursor.skip(runs * 4 + extra) else { throw ImportError.invalid("Повреждена строка XLS") }
            result.append(value)
        }
        return result
    }

    private struct StringCursor {
        let pieces: [Data]
        var part = 0
        var offset = 0

        mutating func u8() -> Int? {
            while part < pieces.count && offset >= pieces[part].count { part += 1; offset = 0 }
            guard part < pieces.count else { return nil }
            defer { offset += 1 }
            return Int(pieces[part][offset])
        }
        mutating func u16() -> Int? { guard let a = u8(), let b = u8() else { return nil }; return a | b << 8 }
        mutating func u32() -> Int? { guard let a = u16(), let b = u16() else { return nil }; return a | b << 16 }
        mutating func skip(_ bytes: Int) -> Bool {
            guard bytes >= 0, bytes < 10_000_000 else { return false }
            for _ in 0..<bytes { if u8() == nil { return false } }
            return true
        }
        mutating func characters(_ count: Int, unicode initial: Bool) -> String? {
            var unicode = initial
            var units: [UInt16] = []
            for _ in 0..<count {
                if part < pieces.count && offset == pieces[part].count {
                    part += 1; offset = 0
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
        if raw & 2 != 0 { value = Double(Int32(bitPattern: UInt32(raw)) >> 2) }
        else { value = Double(bitPattern: UInt64(raw & ~3) << 32) }
        return raw & 1 != 0 ? value / 100 : value
    }
}

private extension Data {
    func u16(_ at: Int) -> Int? {
        guard at >= 0, at + 2 <= count else { return nil }
        return Int(self[at]) | Int(self[at + 1]) << 8
    }
    func u32(_ at: Int) -> Int? {
        guard let low = u16(at), let high = u16(at + 2) else { return nil }
        return low | high << 16
    }
    func f64(_ at: Int) -> Double? {
        guard at >= 0, at + 8 <= count else { return nil }
        var bits: UInt64 = 0
        for n in 0..<8 { bits |= UInt64(self[at + n]) << (n * 8) }
        return Double(bitPattern: bits)
    }
}
