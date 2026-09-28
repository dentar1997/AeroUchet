import Foundation
import PDFKit


enum AssignmentPlanSource: String, Codable, CaseIterable {
    case subscribedCalendar = "Подписной календарь"
    case importedFile = "Файл плана"
}


enum AssignmentPlanKind: String, Codable {
    case flight
    case passenger
    case ground
    case dayOff
}


struct AssignmentPlanItem: Identifiable, Codable, Equatable {
    var id: String
    var source: AssignmentPlanSource
    var externalUID: String?
    var kind: AssignmentPlanKind
    var start: Date
    var end: Date
    var title: String
    var flightNumber: String?
    var departure: String?
    var arrival: String?
    var aircraft: String?
    var assignmentGroup: String?
    var importedAt: Date

    var durationMinutes: Int {
        max(0, Int(end.timeIntervalSince(start) / 60))
    }

    var isFlightLike: Bool {
        kind == .flight || kind == .passenger
    }

    var monthKey: Int {
        let parts = moscowCalendar.dateComponents([.year, .month], from: start)
        return (parts.year ?? 0) * 100 + (parts.month ?? 0)
    }

    var logicalKey: String {
        if isFlightLike {
            return [
                "flight",
                flightNumber.map(normalizedFlightNumber) ?? "",
                normalizedAirport(departure ?? ""),
                normalizedAirport(arrival ?? ""),
                String(dayKey(start))
            ].joined(separator: "|")
        }

        return [
            "event",
            String(dayKey(start)),
            String(Int(start.timeIntervalSince1970 / 60)),
            String(Int(end.timeIntervalSince1970 / 60)),
            normalizedText(title)
        ].joined(separator: "|")
    }
}


struct AssignmentPlanSnapshot {
    var items: [AssignmentPlanItem]
    var generatedAt: Date?
}


enum AssignmentPlanImportError: LocalizedError {
    case invalidURL
    case emptyCalendar
    case unsupportedFile
    case unreadableFile
    case noAssignments

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "В настройках не указана корректная ссылка подписного календаря."
        case .emptyCalendar:
            return "Подписной календарь вернул пустой ответ."
        case .unsupportedFile:
            return "Поддерживаются файлы .ics и PDF «Скачать план»."
        case .unreadableFile:
            return "Не удалось прочитать файл плана."
        case .noAssignments:
            return "В файле не удалось найти назначения."
        }
    }
}


@MainActor
final class AssignmentPlanStore: ObservableObject {
    static let calendarURLKey = "pilotPlanCalendarURL"

    @Published private(set) var items: [AssignmentPlanItem] = []
    @Published private(set) var lastCalendarRefresh: Date?
    @Published private(set) var lastFileImport: Date?

    private let itemsKey = "assignmentPlanItemsV1"
    private let calendarRefreshKey = "assignmentPlanCalendarRefreshV1"
    private let fileImportKey = "assignmentPlanFileImportV1"

    init() {
        load()
    }

    var calendarURLString: String {
        UserDefaults.standard.string(forKey: Self.calendarURLKey) ?? ""
    }

    var hasCalendarURL: Bool {
        guard let url = URL(string: calendarURLString),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            return false
        }
        return true
    }

    func visibleItems(actualFlights: [FlightLeg]) -> [AssignmentPlanItem] {
        let withoutFacts = items.filter { !isSupersededByHistory($0, actualFlights: actualFlights) }
        let calendarKeys = Set(
            withoutFacts
                .filter { $0.source == .subscribedCalendar }
                .map(\.logicalKey)
        )

        return withoutFacts
            .filter { item in
                item.source == .subscribedCalendar || !calendarKeys.contains(item.logicalKey)
            }
            .sorted { $0.start < $1.start }
    }

    func visibleFlights(actualFlights: [FlightLeg]) -> [AssignmentPlanItem] {
        visibleItems(actualFlights: actualFlights).filter(\.isFlightLike)
    }

    func visibleGroundItems(actualFlights: [FlightLeg]) -> [AssignmentPlanItem] {
        visibleItems(actualFlights: actualFlights).filter { !$0.isFlightLike }
    }

    func refreshSubscribedCalendar(actualFlights: [FlightLeg]) async throws -> Int {
        guard let url = URL(string: calendarURLString),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            throw AssignmentPlanImportError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse,
           !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        guard !data.isEmpty else {
            throw AssignmentPlanImportError.emptyCalendar
        }

        let snapshot = try AssignmentPlanImporter.parseICS(data: data)
        let count = apply(
            snapshot: snapshot,
            source: .subscribedCalendar,
            actualFlights: actualFlights
        )
        lastCalendarRefresh = Date()
        saveMetadata()
        return count
    }

    func importPlanFile(url: URL, actualFlights: [FlightLeg]) throws -> Int {
        let snapshot = try AssignmentPlanImporter.parseFile(url: url)
        let count = apply(
            snapshot: snapshot,
            source: .importedFile,
            actualFlights: actualFlights
        )
        lastFileImport = Date()
        saveMetadata()
        return count
    }

    func removeFlightsSuperseded(by actualFlights: [FlightLeg]) {
        let oldCount = items.count
        items.removeAll { isSupersededByHistory($0, actualFlights: actualFlights) }
        if items.count != oldCount {
            saveItems()
        }
    }

    @discardableResult
    private func apply(
        snapshot: AssignmentPlanSnapshot,
        source: AssignmentPlanSource,
        actualFlights: [FlightLeg]
    ) -> Int {
        let stamped = snapshot.items.map { item -> AssignmentPlanItem in
            var value = item
            value.source = source
            value.importedAt = Date()
            return value
        }
        .filter { !isSupersededByHistory($0, actualFlights: actualFlights) }

        guard !stamped.isEmpty else {
            return 0
        }

        if source == .subscribedCalendar {
            let representedMonths = Set(stamped.map(\.monthKey))
            let incomingUIDs = Set(stamped.compactMap(\.externalUID))
            let incomingKeys = Set(stamped.map(\.logicalKey))

            items.removeAll { old in
                guard old.source == .subscribedCalendar,
                      representedMonths.contains(old.monthKey) else {
                    return false
                }

                if let uid = old.externalUID {
                    return !incomingUIDs.contains(uid)
                }
                return !incomingKeys.contains(old.logicalKey)
            }
        }

        var indexByID = Dictionary(uniqueKeysWithValues: items.enumerated().map { ($0.element.id, $0.offset) })
        var indexByUID: [String: Int] = [:]
        for (index, item) in items.enumerated() {
            if let uid = item.externalUID, item.source == source {
                indexByUID[uid] = index
            }
        }

        for incoming in stamped {
            if let uid = incoming.externalUID,
               let index = indexByUID[uid] {
                items[index] = incoming
            } else if let index = indexByID[incoming.id] {
                items[index] = incoming
            } else {
                items.append(incoming)
                indexByID[incoming.id] = items.count - 1
                if let uid = incoming.externalUID {
                    indexByUID[uid] = items.count - 1
                }
            }
        }

        if source == .subscribedCalendar {
            let calendarKeys = Set(
                items
                    .filter { $0.source == .subscribedCalendar }
                    .map(\.logicalKey)
            )
            items.removeAll { $0.source == .importedFile && calendarKeys.contains($0.logicalKey) }
        }

        items.removeAll { isSupersededByHistory($0, actualFlights: actualFlights) }
        items.sort { $0.start < $1.start }
        saveItems()
        return stamped.count
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: itemsKey),
           let decoded = try? JSONDecoder().decode([AssignmentPlanItem].self, from: data) {
            items = decoded
        }
        lastCalendarRefresh = UserDefaults.standard.object(forKey: calendarRefreshKey) as? Date
        lastFileImport = UserDefaults.standard.object(forKey: fileImportKey) as? Date
    }

    private func saveItems() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: itemsKey)
    }

    private func saveMetadata() {
        UserDefaults.standard.set(lastCalendarRefresh, forKey: calendarRefreshKey)
        UserDefaults.standard.set(lastFileImport, forKey: fileImportKey)
    }
}


private func isSupersededByHistory(
    _ item: AssignmentPlanItem,
    actualFlights: [FlightLeg]
) -> Bool {
    guard item.kind == .flight,
          let plannedNumber = item.flightNumber else {
        return false
    }

    let wantedNumber = normalizedFlightNumber(plannedNumber)
    let wantedDeparture = normalizedAirport(item.departure ?? "")
    let wantedArrival = normalizedAirport(item.arrival ?? "")

    return actualFlights.contains { flight in
        guard flight.portalTimes != nil,
              moscowCalendar.isDate(flight.timeline.engineOn, inSameDayAs: item.start),
              normalizedAirport(flight.departure) == wantedDeparture,
              normalizedAirport(flight.arrival) == wantedArrival else {
            return false
        }

        var numbers: [String] = []
        if let leg = flight.legNumber {
            numbers.append(normalizedFlightNumber(leg))
        }
        numbers.append(contentsOf: flight.flightNumber
            .split(separator: "/")
            .map { normalizedFlightNumber(String($0)) })
        return numbers.contains(wantedNumber)
    }
}


private func normalizedFlightNumber(_ value: String) -> String {
    let upper = value.uppercased().replacingOccurrences(of: " ", with: "")
    let withoutSU = upper.hasPrefix("SU") ? String(upper.dropFirst(2)) : upper
    return withoutSU.filter(\.isNumber)
}


private func normalizedAirport(_ value: String) -> String {
    value.uppercased().split(separator: "/").first.map(String.init) ?? value.uppercased()
}


private func normalizedText(_ value: String) -> String {
    value
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ru_RU"))
        .replacingOccurrences(of: " ", with: "")
}


enum AssignmentPlanImporter {
    static func parseFile(url: URL) throws -> AssignmentPlanSnapshot {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "ics":
            return try parseICS(data: Data(contentsOf: url))
        case "pdf":
            return try parsePDF(url: url)
        default:
            throw AssignmentPlanImportError.unsupportedFile
        }
    }

    static func parseICS(data: Data) throws -> AssignmentPlanSnapshot {
        guard let raw = String(data: data, encoding: .utf8) else {
            throw AssignmentPlanImportError.unreadableFile
        }

        let lines = unfoldICSLines(raw)
        var event: [String: String] = [:]
        var items: [AssignmentPlanItem] = []
        var generatedAt: Date?
        var insideEvent = false

        for line in lines {
            if line == "BEGIN:VEVENT" {
                insideEvent = true
                event = [:]
                continue
            }
            if line == "END:VEVENT" {
                if let item = makeICSItem(event) {
                    items.append(item)
                }
                insideEvent = false
                event = [:]
                continue
            }
            guard insideEvent,
                  let colon = line.firstIndex(of: ":") else {
                continue
            }

            let rawKey = String(line[..<colon])
            let key = rawKey.split(separator: ";").first.map(String.init) ?? rawKey
            let value = unescapeICS(String(line[line.index(after: colon)...]))
            event[key] = value

            if key == "DTSTAMP", generatedAt == nil {
                generatedAt = parseICSDate(value, utcWhenZ: true)
            }
        }

        guard !items.isEmpty else {
            throw AssignmentPlanImportError.noAssignments
        }
        return AssignmentPlanSnapshot(items: items, generatedAt: generatedAt)
    }

    static func parsePDF(url: URL) throws -> AssignmentPlanSnapshot {
        guard let document = PDFDocument(url: url) else {
            throw AssignmentPlanImportError.unreadableFile
        }

        var text = ""
        for index in 0..<document.pageCount {
            if let pageText = document.page(at: index)?.string {
                text += pageText + "\n"
            }
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AssignmentPlanImportError.unreadableFile
        }

        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var items: [AssignmentPlanItem] = []
        var year = moscowCalendar.component(.year, from: Date())
        var index = 0

        while index < lines.count {
            if let foundYear = firstMatch(in: lines[index], pattern: #"(?:20)\d{2}"#).flatMap(Int.init),
               lines[index].localizedCaseInsensitiveContains("график работ") {
                year = foundYear
            }

            guard let dayMonth = parsePDFDayMonth(lines[index]) else {
                index += 1
                continue
            }

            let blockDateLine = lines[index]
            var next = index + 1
            while next < lines.count,
                  parsePDFDayMonth(lines[next]) == nil,
                  !lines[next].localizedCaseInsensitiveContains("График работ на") {
                next += 1
            }
            let block = Array(lines[index..<next])
            items.append(contentsOf: parsePDFBlock(
                block,
                day: dayMonth.day,
                month: dayMonth.month,
                year: year,
                dateLine: blockDateLine
            ))
            index = next
        }

        guard !items.isEmpty else {
            throw AssignmentPlanImportError.noAssignments
        }
        return AssignmentPlanSnapshot(items: items, generatedAt: nil)
    }

    private static func makeICSItem(_ event: [String: String]) -> AssignmentPlanItem? {
        guard let startText = event["DTSTART"],
              let endText = event["DTEND"],
              let start = parseICSDate(startText, utcWhenZ: true),
              let end = parseICSDate(endText, utcWhenZ: true),
              end >= start else {
            return nil
        }

        let summary = event["SUMMARY"] ?? "Назначение"
        let description = event["DESCRIPTION"] ?? ""
        let uid = event["UID"]
        let passenger = summary.contains("🧳")
            || description.localizedCaseInsensitiveContains("назначение в качестве пассажира")
        let flightNumber = extractFlightNumber(summary)
        let isFlight = flightNumber != nil
        let kind: AssignmentPlanKind
        if isFlight {
            kind = passenger ? .passenger : .flight
        } else if summary.localizedCaseInsensitiveContains("выходн") {
            kind = .dayOff
        } else {
            kind = .ground
        }

        let airports = extractAirports(summary)
        let aircraft = extractAircraft(description)
        let group = extractAssignmentGroup(description)
        let title = cleanSummary(summary)
        let baseID = uid ?? [
            String(Int(start.timeIntervalSince1970 / 60)),
            title,
            flightNumber ?? ""
        ].joined(separator: "|")

        return AssignmentPlanItem(
            id: "ics|" + baseID,
            source: .subscribedCalendar,
            externalUID: uid,
            kind: kind,
            start: start,
            end: end,
            title: title,
            flightNumber: flightNumber,
            departure: airports.first,
            arrival: airports.count > 1 ? airports[1] : nil,
            aircraft: aircraft,
            assignmentGroup: group,
            importedAt: Date()
        )
    }

    private static func parsePDFBlock(
        _ lines: [String],
        day: Int,
        month: Int,
        year: Int,
        dateLine: String
    ) -> [AssignmentPlanItem] {
        guard let baseDate = makeDate(day: day, month: month, year: year) else {
            return []
        }

        if lines.joined(separator: " ").localizedCaseInsensitiveContains("выходной") {
            let end = moscowCalendar.date(byAdding: .day, value: 1, to: baseDate) ?? baseDate
            return [AssignmentPlanItem(
                id: "pdf|dayoff|\(dayKey(baseDate))",
                source: .importedFile,
                externalUID: nil,
                kind: .dayOff,
                start: baseDate,
                end: end,
                title: "Выходной",
                flightNumber: nil,
                departure: nil,
                arrival: nil,
                aircraft: nil,
                assignmentGroup: nil,
                importedAt: Date()
            )]
        }

        var result: [AssignmentPlanItem] = []
        var pendingRoute: (start: String, departure: String, end: String, arrival: String)?

        for line in lines {
            if let route = parsePDFRoute(line) {
                pendingRoute = route
                continue
            }

            if let details = parsePDFFlightDetails(line),
               let route = pendingRoute,
               let start = dateWithTime(route.start, baseDate: baseDate),
               var end = dateWithTime(route.end, baseDate: baseDate) {
                if end < start {
                    end = moscowCalendar.date(byAdding: .day, value: 1, to: end) ?? end
                }
                let passenger = line.localizedCaseInsensitiveContains("пассаж")
                let number = details.number
                result.append(AssignmentPlanItem(
                    id: "pdf|flight|\(dayKey(start))|\(normalizedFlightNumber(number))|\(normalizedAirport(route.departure))|\(normalizedAirport(route.arrival))",
                    source: .importedFile,
                    externalUID: nil,
                    kind: passenger ? .passenger : .flight,
                    start: start,
                    end: end,
                    title: "\(number) \(route.departure) → \(route.arrival)",
                    flightNumber: number,
                    departure: route.departure,
                    arrival: route.arrival,
                    aircraft: details.aircraft,
                    assignmentGroup: nil,
                    importedAt: Date()
                ))
                pendingRoute = nil
            }
        }

        if result.isEmpty,
           let ground = parsePDFGroundBlock(lines, baseDate: baseDate, dateLine: dateLine) {
            result.append(ground)
        }

        return result
    }

    private static func parsePDFGroundBlock(
        _ lines: [String],
        baseDate: Date,
        dateLine: String
    ) -> AssignmentPlanItem? {
        let combined = ([dateLine] + lines).joined(separator: " ")
        let times = allMatches(in: combined, pattern: #"\b(?:[01]?\d|2[0-3]):[0-5]\d\b"#)
        guard times.count >= 2,
              let start = dateWithTime(times[0], baseDate: baseDate),
              var end = dateWithTime(times[1], baseDate: baseDate) else {
            return nil
        }
        if end < start {
            end = moscowCalendar.date(byAdding: .day, value: 1, to: end) ?? end
        }

        let title = lines
            .filter {
                firstMatch(in: $0, pattern: #"^\d+\s*ч\s*\d+\s*мин$"#) == nil
                    && parsePDFRoute($0) == nil
                    && parsePDFFlightDetails($0) == nil
                    && firstMatch(in: $0, pattern: #"^\d{1,2}:\d{2}$"#) == nil
            }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !title.isEmpty else { return nil }
        return AssignmentPlanItem(
            id: "pdf|ground|\(Int(start.timeIntervalSince1970 / 60))|\(normalizedText(title))",
            source: .importedFile,
            externalUID: nil,
            kind: .ground,
            start: start,
            end: end,
            title: title,
            flightNumber: nil,
            departure: nil,
            arrival: nil,
            aircraft: nil,
            assignmentGroup: nil,
            importedAt: Date()
        )
    }

    private static func parsePDFRoute(_ line: String) -> (start: String, departure: String, end: String, arrival: String)? {
        guard let groups = captureGroups(
            in: line,
            pattern: #"(\d{1,2}:\d{2})\s+([A-Z]{3}(?:/[A-Z])?)\s+-.*?(\d{1,2}:\d{2})\s+([A-Z]{3}(?:/[A-Z])?)\s+-"#
        ), groups.count >= 5 else {
            return nil
        }
        return (groups[1], groups[2], groups[3], groups[4])
    }

    private static func parsePDFFlightDetails(_ line: String) -> (aircraft: String, number: String)? {
        guard let groups = captureGroups(
            in: line,
            pattern: #"\d+\s*ч\s*\d+\s*мин\s+([A-Z]-?\d{3}[A-Z]?)\s+-\s*(SU\d+)"#
        ), groups.count >= 3 else {
            return nil
        }
        return (groups[1], groups[2])
    }

    private static func parsePDFDayMonth(_ line: String) -> (day: Int, month: Int)? {
        guard let groups = captureGroups(in: line, pattern: #"^(\d{2})\.(\d{2}),"#),
              groups.count >= 3,
              let day = Int(groups[1]),
              let month = Int(groups[2]) else {
            return nil
        }
        return (day, month)
    }

    private static func makeDate(day: Int, month: Int, year: Int) -> Date? {
        var components = DateComponents()
        components.timeZone = moscowTimeZone
        components.year = year
        components.month = month
        components.day = day
        return moscowCalendar.date(from: components)
    }

    private static func dateWithTime(_ time: String, baseDate: Date) -> Date? {
        let parts = time.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return nil
        }
        return moscowCalendar.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate)
    }

    private static func unfoldICSLines(_ text: String) -> [String] {
        let rawLines = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
        var result: [String] = []
        for line in rawLines {
            if (line.hasPrefix(" ") || line.hasPrefix("\t")), !result.isEmpty {
                result[result.count - 1] += String(line.dropFirst())
            } else {
                result.append(line)
            }
        }
        return result
    }

    private static func unescapeICS(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    private static func parseICSDate(_ value: String, utcWhenZ: Bool) -> Date? {
        let isUTC = utcWhenZ && value.hasSuffix("Z")
        let clean = isUTC ? String(value.dropLast()) : value
        let formats = ["yyyyMMdd'T'HHmmss", "yyyyMMdd'T'HHmm", "yyyyMMdd"]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = isUTC ? TimeZone(secondsFromGMT: 0) : moscowTimeZone
            formatter.dateFormat = format
            if let date = formatter.date(from: clean) {
                return date
            }
        }
        return nil
    }

    private static func extractFlightNumber(_ summary: String) -> String? {
        guard let value = firstMatch(in: summary.uppercased(), pattern: #"\bSU\s?\d{2,4}\b"#) else {
            return nil
        }
        return value.replacingOccurrences(of: " ", with: "")
    }

    private static func extractAirports(_ summary: String) -> [String] {
        allMatches(in: summary.uppercased(), pattern: #"\(([A-Z]{3})\s*\|"#, capture: 1)
    }

    private static func extractAircraft(_ description: String) -> String? {
        firstMatch(in: description.uppercased(), pattern: #"\bA-?32[01][A-Z]?\b"#)
            ?? firstMatch(in: description.uppercased(), pattern: #"\bA-?\d{3}[A-Z]?\b"#)
    }

    private static func extractAssignmentGroup(_ description: String) -> String? {
        guard let groups = captureGroups(in: description, pattern: #"\[([^,\]]+),"#),
              groups.count > 1 else {
            return nil
        }
        return groups[1]
    }

    private static func cleanSummary(_ summary: String) -> String {
        summary
            .replacingOccurrences(of: "✈️", with: "")
            .replacingOccurrences(of: "🧳", with: "")
            .replacingOccurrences(of: "📋", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        allMatches(in: text, pattern: pattern).first
    }

    private static func allMatches(
        in text: String,
        pattern: String,
        capture: Int = 0
    ) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard capture < match.numberOfRanges else { return nil }
            let range = match.range(at: capture)
            guard range.location != NSNotFound else { return nil }
            return ns.substring(with: range)
        }
    }

    private static func captureGroups(in text: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        return (0..<match.numberOfRanges).map { index in
            let range = match.range(at: index)
            return range.location == NSNotFound ? "" : ns.substring(with: range)
        }
    }
}
