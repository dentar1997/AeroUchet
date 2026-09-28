import Foundation
import PDFKit


enum AssignmentPlanSource: String, Codable, CaseIterable {
    case subscribedCalendar = "Подписной календарь"
    case importedFile = "Импортированный план"
}


enum AssignmentPlanKind: String, Codable {
    case flight
    case passenger
    case ground
    case dayOff
}


enum CalendarFeedHealth: String, Codable {
    case notChecked
    case working
    case failed
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
    var flightNumbers: [String]?
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

    var normalizedFlightNumbers: Set<String> {
        let values = flightNumbers ?? flightNumber.map { [$0] } ?? []
        return Set(values.flatMap(extractFlightNumbers).map(normalizedFlightNumber))
    }

    var logicalKey: String {
        if isFlightLike {
            let numbers = normalizedFlightNumbers.sorted().joined(separator: ",")
            return ["flight", String(dayKey(start)), numbers].joined(separator: "|")
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
            return "Поддерживаются файлы .ics и PDF плана."
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
    @Published private(set) var calendarHealth: CalendarFeedHealth = .notChecked
    @Published private(set) var lastCalendarCheck: Date?
    @Published private(set) var calendarCheckMessage: String?

    private let itemsKey = "assignmentPlanItemsV2"
    private let legacyItemsKey = "assignmentPlanItemsV1"
    private let calendarRefreshKey = "assignmentPlanCalendarRefreshV1"
    private let fileImportKey = "assignmentPlanFileImportV1"
    private let calendarHealthKey = "assignmentPlanCalendarHealthV1"
    private let calendarCheckKey = "assignmentPlanCalendarCheckV1"
    private let calendarMessageKey = "assignmentPlanCalendarMessageV1"

    init() {
        load()
    }

    var calendarURLString: String {
        UserDefaults.standard.string(forKey: Self.calendarURLKey) ?? ""
    }

    var hasCalendarURL: Bool {
        validatedCalendarURL() != nil
    }

    var calendarSourceItems: [AssignmentPlanItem] {
        items
            .filter { $0.source == .subscribedCalendar }
            .sorted { $0.start < $1.start }
    }

    var importedSourceItems: [AssignmentPlanItem] {
        items
            .filter { $0.source == .importedFile }
            .sorted { $0.start < $1.start }
    }

    func sourceItems(
        _ source: AssignmentPlanSource,
        actualFlights: [FlightLeg],
        hideSuperseded: Bool = false
    ) -> [AssignmentPlanItem] {
        let sourceItems = items.filter { $0.source == source }
        let filtered = hideSuperseded
            ? sourceItems.filter { !isSupersededByHistory($0, actualFlights: actualFlights) }
            : sourceItems
        return filtered.sorted { $0.start < $1.start }
    }

    func visibleItems(actualFlights: [FlightLeg]) -> [AssignmentPlanItem] {
        let calendar = sourceItems(
            .subscribedCalendar,
            actualFlights: actualFlights,
            hideSuperseded: true
        )
        let imported = sourceItems(
            .importedFile,
            actualFlights: actualFlights,
            hideSuperseded: true
        )
        .filter { importedItem in
            !calendar.contains { calendarItem in
                assignmentsOverlap(importedItem, calendarItem)
            }
        }
        return (calendar + imported).sorted { $0.start < $1.start }
    }

    func visibleFlights(actualFlights: [FlightLeg]) -> [AssignmentPlanItem] {
        visibleItems(actualFlights: actualFlights).filter(\.isFlightLike)
    }

    func visibleGroundItems(actualFlights: [FlightLeg]) -> [AssignmentPlanItem] {
        visibleItems(actualFlights: actualFlights).filter { !$0.isFlightLike }
    }

    func calendarOverlap(for item: AssignmentPlanItem) -> Bool {
        calendarSourceItems.contains { calendarItem in
            assignmentsOverlap(item, calendarItem)
        }
    }

    func historySupersedes(_ item: AssignmentPlanItem, actualFlights: [FlightLeg]) -> Bool {
        isSupersededByHistory(item, actualFlights: actualFlights)
    }

    func validateSubscribedCalendar() async throws -> Int {
        do {
            let snapshot = try await fetchSubscribedSnapshot()
            calendarHealth = .working
            lastCalendarCheck = Date()
            calendarCheckMessage = "Календарь доступен. Найдено назначений: \(snapshot.items.count)."
            saveMetadata()
            return snapshot.items.count
        } catch {
            calendarHealth = .failed
            lastCalendarCheck = Date()
            calendarCheckMessage = error.localizedDescription
            saveMetadata()
            throw error
        }
    }

    func resetCalendarValidation() {
        calendarHealth = .notChecked
        lastCalendarCheck = nil
        calendarCheckMessage = nil
        saveMetadata()
    }

    func refreshSubscribedCalendar(actualFlights: [FlightLeg]) async throws -> Int {
        do {
            let snapshot = try await fetchSubscribedSnapshot()
            let count = apply(snapshot: snapshot, source: .subscribedCalendar)
            lastCalendarRefresh = Date()
            calendarHealth = .working
            lastCalendarCheck = Date()
            calendarCheckMessage = "Календарь работает. Получено назначений: \(count)."
            saveMetadata()
            return count
        } catch {
            calendarHealth = .failed
            lastCalendarCheck = Date()
            calendarCheckMessage = error.localizedDescription
            saveMetadata()
            throw error
        }
    }

    func importPlanFile(url: URL, actualFlights: [FlightLeg]) throws -> Int {
        let snapshot = try AssignmentPlanImporter.parseFile(url: url)
        let count = apply(snapshot: snapshot, source: .importedFile)
        lastFileImport = Date()
        saveMetadata()
        return count
    }

    func deleteCurrentPlan() {
        items.removeAll { $0.source == .subscribedCalendar }
        lastCalendarRefresh = nil
        saveItems()
        saveMetadata()
    }

    func deleteImportedPlan() {
        items.removeAll { $0.source == .importedFile }
        lastFileImport = nil
        saveItems()
        saveMetadata()
    }

    func removeFlightsSuperseded(by actualFlights: [FlightLeg]) {
        _ = actualFlights
        // Источники теперь хранятся независимо. Факт имеет приоритет только
        // в объединённом представлении и не уничтожает исходный снимок плана.
    }

    private func validatedCalendarURL() -> URL? {
        let value = calendarURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            return nil
        }
        return url
    }

    private func fetchSubscribedSnapshot() async throws -> AssignmentPlanSnapshot {
        guard let url = validatedCalendarURL() else {
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
        return try AssignmentPlanImporter.parseICS(data: data)
    }

    @discardableResult
    private func apply(
        snapshot: AssignmentPlanSnapshot,
        source: AssignmentPlanSource
    ) -> Int {
        let stamped = snapshot.items.map { item -> AssignmentPlanItem in
            var value = item
            value.source = source
            value.importedAt = Date()
            return value
        }
        guard !stamped.isEmpty else { return 0 }

        let representedMonths = Set(stamped.map(\.monthKey))
        items.removeAll { old in
            old.source == source && representedMonths.contains(old.monthKey)
        }

        var knownIDs = Set(items.map(\.id))
        for incoming in stamped where knownIDs.insert(incoming.id).inserted {
            items.append(incoming)
        }

        items.sort { $0.start < $1.start }
        saveItems()
        return stamped.count
    }

    private func load() {
        let defaults = UserDefaults.standard
        let data = defaults.data(forKey: itemsKey) ?? defaults.data(forKey: legacyItemsKey)
        if let data,
           let decoded = try? JSONDecoder().decode([AssignmentPlanItem].self, from: data) {
            items = decoded
            saveItems()
        }
        lastCalendarRefresh = defaults.object(forKey: calendarRefreshKey) as? Date
        lastFileImport = defaults.object(forKey: fileImportKey) as? Date
        lastCalendarCheck = defaults.object(forKey: calendarCheckKey) as? Date
        calendarCheckMessage = defaults.string(forKey: calendarMessageKey)
        if let raw = defaults.string(forKey: calendarHealthKey),
           let value = CalendarFeedHealth(rawValue: raw) {
            calendarHealth = value
        }
    }

    private func saveItems() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: itemsKey)
    }

    private func saveMetadata() {
        let defaults = UserDefaults.standard
        defaults.set(lastCalendarRefresh, forKey: calendarRefreshKey)
        defaults.set(lastFileImport, forKey: fileImportKey)
        defaults.set(calendarHealth.rawValue, forKey: calendarHealthKey)
        defaults.set(lastCalendarCheck, forKey: calendarCheckKey)
        defaults.set(calendarCheckMessage, forKey: calendarMessageKey)
    }
}


private func assignmentsOverlap(
    _ lhs: AssignmentPlanItem,
    _ rhs: AssignmentPlanItem
) -> Bool {
    guard moscowCalendar.isDate(lhs.start, inSameDayAs: rhs.start) else {
        return false
    }

    if lhs.isFlightLike && rhs.isFlightLike {
        let left = lhs.normalizedFlightNumbers
        let right = rhs.normalizedFlightNumbers
        return !left.isEmpty && !right.isEmpty && !left.isDisjoint(with: right)
    }

    return lhs.logicalKey == rhs.logicalKey
}


private func isSupersededByHistory(
    _ item: AssignmentPlanItem,
    actualFlights: [FlightLeg]
) -> Bool {
    guard item.kind == .flight, !item.normalizedFlightNumbers.isEmpty else {
        return false
    }

    return actualFlights.contains { flight in
        guard flight.portalTimes != nil,
              moscowCalendar.isDate(flight.timeline.engineOn, inSameDayAs: item.start) else {
            return false
        }

        var numbers = extractFlightNumbers(flight.flightNumber)
        if let leg = flight.legNumber {
            numbers.append(contentsOf: extractFlightNumbers(leg))
        }
        let actual = Set(numbers.map(normalizedFlightNumber))
        return !actual.isEmpty && !actual.isDisjoint(with: item.normalizedFlightNumbers)
    }
}


private func normalizedFlightNumber(_ value: String) -> String {
    let upper = value.uppercased().replacingOccurrences(of: " ", with: "")
    let withoutSU = upper.hasPrefix("SU") ? String(upper.dropFirst(2)) : upper
    return withoutSU.filter(\.isNumber)
}


private func normalizedText(_ value: String) -> String {
    value
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ru_RU"))
        .replacingOccurrences(of: " ", with: "")
}


private func extractFlightNumbers(_ value: String) -> [String] {
    regexMatches(in: value.uppercased(), pattern: #"SU\s*\d{2,4}"#)
        .map { $0.replacingOccurrences(of: " ", with: "") }
}


enum AssignmentPlanImporter {
    static func parseFile(url: URL) throws -> AssignmentPlanSnapshot {
        switch url.pathExtension.lowercased() {
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
            guard insideEvent, let colon = line.firstIndex(of: ":") else { continue }
            let rawKey = String(line[..<colon])
            let key = rawKey.split(separator: ";").first.map(String.init) ?? rawKey
            let value = unescapeICS(String(line[line.index(after: colon)...]))
            event[key] = value
            if key == "DTSTAMP", generatedAt == nil {
                generatedAt = parseICSDate(value)
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
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else {
            throw AssignmentPlanImportError.unreadableFile
        }

        let header = lines.prefix(8).joined(separator: " ")
        let year = firstIntegerMatch(in: header, pattern: #"20\d{2}"#)
            ?? moscowCalendar.component(.year, from: Date())

        let items: [AssignmentPlanItem]
        if header.localizedCaseInsensitiveContains("перспективный план") {
            items = parsePerspectivePDF(lines: lines, defaultYear: year)
        } else {
            items = parseOfficialPDF(lines: lines, defaultYear: year)
        }

        guard !items.isEmpty else {
            throw AssignmentPlanImportError.noAssignments
        }
        return AssignmentPlanSnapshot(items: items, generatedAt: nil)
    }

    private static func makeICSItem(_ event: [String: String]) -> AssignmentPlanItem? {
        guard let startText = event["DTSTART"],
              let endText = event["DTEND"],
              let start = parseICSDate(startText),
              let end = parseICSDate(endText),
              end >= start else {
            return nil
        }

        let summary = event["SUMMARY"] ?? "Назначение"
        let description = event["DESCRIPTION"] ?? ""
        let uid = event["UID"]
        let numbers = extractFlightNumbers(summary)
        let passenger = summary.contains("🧳")
            || description.localizedCaseInsensitiveContains("назначение в качестве пассажира")
        let kind: AssignmentPlanKind
        if !numbers.isEmpty {
            kind = passenger ? .passenger : .flight
        } else if summary.localizedCaseInsensitiveContains("выходн") {
            kind = .dayOff
        } else {
            kind = .ground
        }

        let airports = extractAirports(summary)
        let aircraft = regexMatches(in: description, pattern: #"A-?3(?:19|20|21)[A-Z]?"#).first
        let group = extractAssignmentGroup(description)
        let title = cleanICSText(summary)
        let baseID = uid ?? [String(Int(start.timeIntervalSince1970 / 60)), title].joined(separator: "|")

        return AssignmentPlanItem(
            id: "ics|" + baseID,
            source: .subscribedCalendar,
            externalUID: uid,
            kind: kind,
            start: start,
            end: end,
            title: title,
            flightNumber: numbers.first,
            flightNumbers: numbers,
            departure: airports.first,
            arrival: airports.count > 1 ? airports.last : nil,
            aircraft: aircraft,
            assignmentGroup: group,
            importedAt: Date()
        )
    }

    private static func parsePerspectivePDF(
        lines: [String],
        defaultYear: Int
    ) -> [AssignmentPlanItem] {
        var result: [AssignmentPlanItem] = []
        var index = 0

        while index < lines.count {
            guard let date = parseDateLine(lines[index], year: defaultYear) else {
                index += 1
                continue
            }

            if index + 2 < lines.count,
               let endDate = parseDateLine(lines[index + 1], year: defaultYear),
               lines[index + 2].hasPrefix("–") || lines[index + 2].hasPrefix("-") {
                var next = index + 3
                var titleParts = [lines[index + 2].trimmingCharacters(in: CharacterSet(charactersIn: "-–— "))]
                while next < lines.count, parseDateLine(lines[next], year: defaultYear) == nil {
                    titleParts.append(lines[next])
                    next += 1
                }
                let title = titleParts.joined(separator: " ")
                let finalEnd = moscowCalendar.date(byAdding: .day, value: 1, to: endDate.date) ?? endDate.date
                result.append(makeImportedItem(
                    id: "perspective|range|\(dayKey(date.date))|\(dayKey(endDate.date))|\(normalizedText(title))",
                    kind: title.localizedCaseInsensitiveContains("выход") ? .dayOff : .ground,
                    start: date.date,
                    end: finalEnd,
                    title: title
                ))
                index = next
                continue
            }

            var next = index + 1
            while next < lines.count, parseDateLine(lines[next], year: defaultYear) == nil {
                next += 1
            }
            let block = Array(lines[index..<next])
            if let item = parsePerspectiveBlock(block, date: date.date, firstTime: date.time) {
                result.append(item)
            }
            index = next
        }

        return result
    }

    private static func parsePerspectiveBlock(
        _ lines: [String],
        date: Date,
        firstTime: String?
    ) -> AssignmentPlanItem? {
        let combined = lines.joined(separator: " ")
        let numbers = extractFlightNumbers(combined)
        var times: [String] = []
        if let firstTime { times.append(firstTime) }
        for line in lines.dropFirst() {
            if let value = exactTime(line) {
                times.append(value)
            }
        }

        if !numbers.isEmpty, times.count >= 2,
           let start = dateWithTime(times[0], baseDate: date),
           var end = dateWithTime(times[1], baseDate: date) {
            if end < start {
                end = moscowCalendar.date(byAdding: .day, value: 1, to: end) ?? end
            }
            let passenger = combined.localizedCaseInsensitiveContains("пассаж")
            let route = perspectiveRoute(in: lines)
            let aircraft = regexMatches(in: combined, pattern: #"A-?3(?:19|20|21)[A-Z]?"#).first
            let numberText = numbers.joined(separator: " / ")
            return makeImportedItem(
                id: "perspective|flight|\(dayKey(start))|\(numbers.map(normalizedFlightNumber).joined(separator: "-"))",
                kind: passenger ? .passenger : .flight,
                start: start,
                end: end,
                title: route ?? numberText,
                flightNumber: numberText,
                flightNumbers: numbers,
                aircraft: aircraft,
                assignmentGroup: route
            )
        }

        if combined.localizedCaseInsensitiveContains("выходной") {
            let end = moscowCalendar.date(byAdding: .day, value: 1, to: date) ?? date
            return makeImportedItem(
                id: "perspective|dayoff|\(dayKey(date))",
                kind: .dayOff,
                start: date,
                end: end,
                title: "Выходной"
            )
        }

        if times.count >= 2,
           let start = dateWithTime(times[0], baseDate: date),
           var end = dateWithTime(times[1], baseDate: date) {
            if end < start {
                end = moscowCalendar.date(byAdding: .day, value: 1, to: end) ?? end
            }
            let title = perspectiveGroundTitle(lines)
            guard !title.isEmpty else { return nil }
            return makeImportedItem(
                id: "perspective|ground|\(Int(start.timeIntervalSince1970 / 60))|\(normalizedText(title))",
                kind: .ground,
                start: start,
                end: end,
                title: title
            )
        }

        return nil
    }

    private static func parseOfficialPDF(
        lines: [String],
        defaultYear: Int
    ) -> [AssignmentPlanItem] {
        var result: [AssignmentPlanItem] = []
        var year = defaultYear
        var index = 0

        while index < lines.count {
            if lines[index].localizedCaseInsensitiveContains("график работ"),
               let found = firstIntegerMatch(in: lines[index], pattern: #"20\d{2}"#) {
                year = found
            }
            guard let date = parseDateLine(lines[index], year: year) else {
                index += 1
                continue
            }
            var next = index + 1
            while next < lines.count,
                  parseDateLine(lines[next], year: year) == nil,
                  !lines[next].localizedCaseInsensitiveContains("график работ") {
                next += 1
            }
            let block = Array(lines[index..<next])
            result.append(contentsOf: parseOfficialBlock(block, date: date.date, firstTime: date.time))
            index = next
        }
        return result
    }

    private static func parseOfficialBlock(
        _ lines: [String],
        date: Date,
        firstTime: String?
    ) -> [AssignmentPlanItem] {
        let combined = lines.joined(separator: " ")
        let numbers = extractFlightNumbers(combined)
        let allTimes = regexMatches(in: combined, pattern: #"\b(?:[01]?\d|2[0-3]):[0-5]\d\b"#)
        var times = allTimes
        if let firstTime, times.first != firstTime {
            times.insert(firstTime, at: 0)
        }

        if !numbers.isEmpty, times.count >= 2,
           let start = dateWithTime(times[0], baseDate: date),
           var end = dateWithTime(times[1], baseDate: date) {
            if end < start {
                end = moscowCalendar.date(byAdding: .day, value: 1, to: end) ?? end
            }
            let passenger = combined.localizedCaseInsensitiveContains("пассаж")
            let airports = extractAirports(combined)
            let aircraft = regexMatches(in: combined, pattern: #"A-?3(?:19|20|21)[A-Z]?"#).first
            let numberText = numbers.joined(separator: " / ")
            return [makeImportedItem(
                id: "official|flight|\(dayKey(start))|\(numbers.map(normalizedFlightNumber).joined(separator: "-"))",
                kind: passenger ? .passenger : .flight,
                start: start,
                end: end,
                title: numberText,
                flightNumber: numberText,
                flightNumbers: numbers,
                departure: airports.first,
                arrival: airports.count > 1 ? airports.last : nil,
                aircraft: aircraft
            )]
        }

        if combined.localizedCaseInsensitiveContains("выходной") {
            let end = moscowCalendar.date(byAdding: .day, value: 1, to: date) ?? date
            return [makeImportedItem(
                id: "official|dayoff|\(dayKey(date))",
                kind: .dayOff,
                start: date,
                end: end,
                title: "Выходной"
            )]
        }

        if times.count >= 2,
           let start = dateWithTime(times[0], baseDate: date),
           var end = dateWithTime(times[1], baseDate: date) {
            if end < start {
                end = moscowCalendar.date(byAdding: .day, value: 1, to: end) ?? end
            }
            let title = perspectiveGroundTitle(lines)
            guard !title.isEmpty else { return [] }
            return [makeImportedItem(
                id: "official|ground|\(Int(start.timeIntervalSince1970 / 60))|\(normalizedText(title))",
                kind: .ground,
                start: start,
                end: end,
                title: title
            )]
        }

        return []
    }

    private static func makeImportedItem(
        id: String,
        kind: AssignmentPlanKind,
        start: Date,
        end: Date,
        title: String,
        flightNumber: String? = nil,
        flightNumbers: [String]? = nil,
        departure: String? = nil,
        arrival: String? = nil,
        aircraft: String? = nil,
        assignmentGroup: String? = nil
    ) -> AssignmentPlanItem {
        AssignmentPlanItem(
            id: id,
            source: .importedFile,
            externalUID: nil,
            kind: kind,
            start: start,
            end: end,
            title: title,
            flightNumber: flightNumber,
            flightNumbers: flightNumbers,
            departure: departure,
            arrival: arrival,
            aircraft: aircraft,
            assignmentGroup: assignmentGroup,
            importedAt: Date()
        )
    }

    private static func parseDateLine(
        _ line: String,
        year: Int
    ) -> (date: Date, time: String?)? {
        guard let groups = captureGroups(
            in: line,
            pattern: #"^(\d{1,2})\.(\d{1,2}),.*?(?:(\d{1,2}:\d{2}))?$"#
        ), groups.count >= 4,
        let day = Int(groups[1]),
        let month = Int(groups[2]) else {
            return nil
        }
        var components = DateComponents()
        components.timeZone = moscowTimeZone
        components.year = year
        components.month = month
        components.day = day
        guard let date = moscowCalendar.date(from: components) else { return nil }
        return (date, groups[3].isEmpty ? nil : groups[3])
    }

    private static func exactTime(_ line: String) -> String? {
        let value = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard regexMatches(in: value, pattern: #"^(?:[01]?\d|2[0-3]):[0-5]\d$"#).first != nil else {
            return nil
        }
        return value
    }

    private static func perspectiveRoute(in lines: [String]) -> String? {
        lines.first { line in
            let value = line.lowercased()
            return line.contains("-")
                && !value.contains("a-320")
                && !value.contains("a-321")
                && !value.contains("ч ")
                && !value.contains("планируемое")
                && !value.contains(" - su")
        }
    }

    private static func perspectiveGroundTitle(_ lines: [String]) -> String {
        lines
            .dropFirst()
            .filter { exactTime($0) == nil }
            .filter { extractFlightNumbers($0).isEmpty }
            .filter { !$0.localizedCaseInsensitiveContains("планируемое полётное время") }
            .joined(separator: " ")
            .replacingOccurrences(of: #"\s*\(A-?3(?:19|20|21)[A-Z]?\)\s*"#,
                                  with: " ",
                                  options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func dateWithTime(_ value: String, baseDate: Date) -> Date? {
        let parts = value.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return nil
        }
        return moscowCalendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: baseDate
        )
    }

    private static func unfoldICSLines(_ text: String) -> [String] {
        let raw = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
        var result: [String] = []
        for line in raw {
            if (line.hasPrefix(" ") || line.hasPrefix("\t")), !result.isEmpty {
                result[result.count - 1] += String(line.dropFirst())
            } else {
                result.append(line)
            }
        }
        return result
    }

    private static func parseICSDate(_ value: String) -> Date? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.count == 8 {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = moscowTimeZone
            formatter.dateFormat = "yyyyMMdd"
            return formatter.date(from: clean)
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = clean.hasSuffix("Z") ? TimeZone(secondsFromGMT: 0) : moscowTimeZone
        formatter.dateFormat = clean.hasSuffix("Z") ? "yyyyMMdd'T'HHmmss'Z'" : "yyyyMMdd'T'HHmmss"
        return formatter.date(from: clean)
    }

    private static func unescapeICS(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    private static func extractAirports(_ text: String) -> [String] {
        let matches = regexMatches(in: text.uppercased(), pattern: #"\b[A-Z]{3}(?:/[A-Z])?\b"#)
        var result: [String] = []
        for value in matches where !result.contains(value) {
            result.append(value)
        }
        return result
    }

    private static func extractAssignmentGroup(_ description: String) -> String? {
        guard let groups = captureGroups(
            in: description,
            pattern: #"\[([^\]]+),\s*A-?3(?:19|20|21)[A-Z]?\]"#
        ), groups.count >= 2 else {
            return nil
        }
        return groups[1]
    }

    private static func cleanICSText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "🧳", with: "")
            .replacingOccurrences(of: "✈️", with: "")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}


private func regexMatches(in text: String, pattern: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let ns = text as NSString
    return regex.matches(
        in: text,
        range: NSRange(location: 0, length: ns.length)
    ).map { ns.substring(with: $0.range) }
}


private func captureGroups(in text: String, pattern: String) -> [String]? {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let ns = text as NSString
    guard let match = regex.firstMatch(
        in: text,
        range: NSRange(location: 0, length: ns.length)
    ) else {
        return nil
    }
    return (0..<match.numberOfRanges).map { index in
        let range = match.range(at: index)
        return range.location == NSNotFound ? "" : ns.substring(with: range)
    }
}


private func firstIntegerMatch(in text: String, pattern: String) -> Int? {
    regexMatches(in: text, pattern: pattern).first.flatMap(Int.init)
}
