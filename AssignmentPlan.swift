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
    case hotelReserve
    case homeReserve
    case leave
    case medical
    case simulator
    case training
}


enum AssignmentFlightRole: String, Codable {
    case workingPilot
    case passenger
}


enum CalendarFeedHealth: String, Codable {
    case notChecked
    case working
    case failed
}


struct AssignmentPlanLeg: Identifiable, Codable, Equatable {
    var id: String
    var flightNumber: String
    var role: AssignmentFlightRole
    var departure: String?
    var arrival: String?
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

    var detail: String?
    var flightLegs: [AssignmentPlanLeg]?
    var plannedFlightMinutes: Int?
    var isAllDayRange: Bool?
    var originMonthKey: Int?

    var durationMinutes: Int {
        max(0, Int(end.timeIntervalSince(start) / 60))
    }

    var creditedWorkMinutes: Int {
        switch kind {
        case .homeReserve:
            return durationMinutes / 4
        case .hotelReserve:
            return durationMinutes
        default:
            return durationMinutes
        }
    }

    var isFlightLike: Bool {
        kind == .flight || kind == .passenger
    }

    var isAllDay: Bool {
        isAllDayRange == true
    }

    var monthKey: Int {
        let parts = moscowCalendar.dateComponents([.year, .month], from: start)
        return (parts.year ?? 0) * 100 + (parts.month ?? 0)
    }

    var normalizedFlightNumbers: Set<String> {
        var values = flightLegs?.map(\.flightNumber) ?? []
        if values.isEmpty {
            if let flightNumbers {
                values = flightNumbers
            } else if let flightNumber {
                values = [flightNumber]
            }
        }

        return Set(
            values
                .flatMap { extractFlightNumbers($0) }
                .map { normalizedFlightNumber($0) }
        )
    }

    var normalizedWorkingFlightNumbers: Set<String> {
        if let legs = flightLegs, !legs.isEmpty {
            return Set(
                legs
                    .filter { $0.role == .workingPilot }
                    .map { normalizedFlightNumber($0.flightNumber) }
            )
        }
        guard kind == .flight else { return [] }
        return normalizedFlightNumbers
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
            normalizedText(title),
            normalizedText(detail ?? "")
        ].joined(separator: "|")
    }
}


struct AssignmentPlanSnapshot {
    var items: [AssignmentPlanItem]
    var generatedAt: Date?
    var scopeMonthKey: Int?

    init(
        items: [AssignmentPlanItem],
        generatedAt: Date?,
        scopeMonthKey: Int? = nil
    ) {
        self.items = items
        self.generatedAt = generatedAt
        self.scopeMonthKey = scopeMonthKey
    }
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

    private let itemsKey = "assignmentPlanItemsV3"
    private let legacyV2ItemsKey = "assignmentPlanItemsV2"
    private let legacyV1ItemsKey = "assignmentPlanItemsV1"
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
                assignmentsRepresentSame(importedItem, calendarItem)
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
            assignmentsRepresentSame(item, calendarItem)
        }
    }

    func historySupersedes(_ item: AssignmentPlanItem, actualFlights: [FlightLeg]) -> Bool {
        isSupersededByHistory(item, actualFlights: actualFlights)
    }

    func conflicts(
        for item: AssignmentPlanItem,
        in source: AssignmentPlanSource
    ) -> [AssignmentPlanItem] {
        items
            .filter { candidate in
                candidate.source == source
                    && candidate.id != item.id
                    && assignmentsConflict(item, candidate)
            }
            .sorted { $0.start < $1.start }
    }

    func conflictPairCount(in source: AssignmentPlanSource) -> Int {
        let sourceItems = items.filter { $0.source == source }
        var count = 0
        for leftIndex in sourceItems.indices {
            for rightIndex in sourceItems.indices where rightIndex > leftIndex {
                if assignmentsConflict(sourceItems[leftIndex], sourceItems[rightIndex]) {
                    count += 1
                }
            }
        }
        return count
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
        _ = actualFlights
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
        _ = actualFlights
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
        // Источники хранятся независимо. Приоритет применяется только при показе.
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
            if value.originMonthKey == nil {
                value.originMonthKey = snapshot.scopeMonthKey
            }
            return value
        }
        guard !stamped.isEmpty else { return 0 }

        if source == .importedFile, let scopeMonthKey = snapshot.scopeMonthKey {
            items.removeAll { old in
                guard old.source == .importedFile else { return false }
                if let origin = old.originMonthKey {
                    return origin == scopeMonthKey
                }
                return old.monthKey == scopeMonthKey
            }
        } else {
            let representedMonths = Set(stamped.map(\.monthKey))
            items.removeAll { old in
                old.source == source && representedMonths.contains(old.monthKey)
            }
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
        var migratedLegacyPlan = false

        if let decoded = StorageSafety.decode(
            [AssignmentPlanItem].self, key: itemsKey, title: "Назначения"
        ) {
            items = decoded
        } else {
            let legacyData = defaults.data(forKey: legacyV2ItemsKey)
                ?? defaults.data(forKey: legacyV1ItemsKey)
            if let legacyData,
               let decoded = try? JSONDecoder().decode([AssignmentPlanItem].self, from: legacyData) {
                // Старый импортированный PDF был разобран прежним парсером с неверными
                // границами диапазонов. Его просим импортировать заново, календарь сохраняем.
                items = decoded.filter { $0.source == .subscribedCalendar }
                migratedLegacyPlan = decoded.contains { $0.source == .importedFile }
                if migratedLegacyPlan {
                    defaults.removeObject(forKey: fileImportKey)
                }
                saveItems()
            }
        }

        lastCalendarRefresh = defaults.object(forKey: calendarRefreshKey) as? Date
        lastFileImport = migratedLegacyPlan
            ? nil
            : defaults.object(forKey: fileImportKey) as? Date
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


private func assignmentsRepresentSame(
    _ lhs: AssignmentPlanItem,
    _ rhs: AssignmentPlanItem
) -> Bool {
    if lhs.isFlightLike && rhs.isFlightLike {
        guard moscowCalendar.isDate(lhs.start, inSameDayAs: rhs.start) else {
            return false
        }
        let left = lhs.normalizedFlightNumbers
        let right = rhs.normalizedFlightNumbers
        return !left.isEmpty && !right.isEmpty && !left.isDisjoint(with: right)
    }

    guard moscowCalendar.isDate(lhs.start, inSameDayAs: rhs.start) else {
        return false
    }

    if normalizedText(lhs.title) == normalizedText(rhs.title) {
        return true
    }

    if let leftDetail = lhs.detail,
       let rightDetail = rhs.detail,
       !leftDetail.isEmpty,
       !rightDetail.isEmpty,
       normalizedText(leftDetail) == normalizedText(rightDetail) {
        return true
    }

    return false
}


private func assignmentsConflict(
    _ lhs: AssignmentPlanItem,
    _ rhs: AssignmentPlanItem
) -> Bool {
    guard lhs.start < rhs.end, rhs.start < lhs.end else {
        return false
    }
    return !assignmentsRepresentSame(lhs, rhs)
}


private func isSupersededByHistory(
    _ item: AssignmentPlanItem,
    actualFlights: [FlightLeg]
) -> Bool {
    let plannedNumbers = item.normalizedWorkingFlightNumbers
    guard !plannedNumbers.isEmpty else { return false }

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
        return !actual.isEmpty && !actual.isDisjoint(with: plannedNumbers)
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
        .replacingOccurrences(
            of: #"[^a-zа-я0-9]"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
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

        let header = lines.prefix(10).joined(separator: " ")
        let year = firstIntegerMatch(in: header, pattern: #"20\d{2}"#)
            ?? moscowCalendar.component(.year, from: Date())
        let scopeMonthKey = planScopeMonthKey(lines: lines, defaultYear: year)

        let items: [AssignmentPlanItem]
        if header.localizedCaseInsensitiveContains("перспективный план") {
            items = parsePerspectivePDF(
                lines: lines,
                defaultYear: year,
                scopeMonthKey: scopeMonthKey
            )
        } else {
            items = parseOfficialPDF(
                lines: lines,
                defaultYear: year,
                scopeMonthKey: scopeMonthKey
            )
        }

        guard !items.isEmpty else {
            throw AssignmentPlanImportError.noAssignments
        }
        return AssignmentPlanSnapshot(
            items: items,
            generatedAt: nil,
            scopeMonthKey: scopeMonthKey
        )
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
        let title = cleanICSText(summary)
        let kind = classifyKind(
            title + " " + description,
            hasFlights: !numbers.isEmpty,
            passengerOnly: passenger
        )
        let airports = extractAirports(summary)
        let aircraft = regexMatches(in: description, pattern: #"A-?3(?:19|20|21)[A-Z]?"#).first
        let group = extractAssignmentGroup(description)
        let baseID = uid ?? [String(Int(start.timeIntervalSince1970 / 60)), title].joined(separator: "|")
        let legs = numbers.map { number in
            AssignmentPlanLeg(
                id: "ics-leg|\(baseID)|\(normalizedFlightNumber(number))",
                flightNumber: number,
                role: passenger ? .passenger : .workingPilot,
                departure: airports.first,
                arrival: airports.count > 1 ? airports.last : nil
            )
        }

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
            importedAt: Date(),
            detail: cleanICSDescription(description, summary: title),
            flightLegs: legs.isEmpty ? nil : legs,
            plannedFlightMinutes: nil,
            isAllDayRange: startText.count == 8 && endText.count == 8,
            originMonthKey: nil
        )
    }

    private static func parsePerspectivePDF(
        lines: [String],
        defaultYear: Int,
        scopeMonthKey: Int?
    ) -> [AssignmentPlanItem] {
        var result: [AssignmentPlanItem] = []
        var index = 0

        while index < lines.count {
            guard let date = parseDateLine(lines[index], year: defaultYear) else {
                index += 1
                continue
            }

            if date.time == nil,
               index + 2 < lines.count,
               let rawEndDate = parseDateLine(lines[index + 1], year: defaultYear),
               rawEndDate.time == nil,
               isRangeMarker(lines[index + 2]) {
                var next = index + 2
                while next < lines.count,
                      parseDateLine(lines[next], year: defaultYear) == nil {
                    next += 1
                }

                let rawContent = Array(lines[(index + 2)..<next])
                let firstTimedIndex = rawContent.firstIndex { exactTime($0) != nil }
                let rangeContent: [String]
                let timedContent: [String]
                if let firstTimedIndex {
                    rangeContent = Array(rawContent[..<firstTimedIndex])
                    timedContent = Array(rawContent[firstTimedIndex...])
                } else {
                    rangeContent = rawContent
                    timedContent = []
                }

                let endExclusive = adjustedRangeEnd(
                    rawEndDate.date,
                    start: date.date
                )
                if let rangeItem = makeRangeItem(
                    lines: rangeContent,
                    start: date.date,
                    endExclusive: endExclusive,
                    scopeMonthKey: scopeMonthKey
                ) {
                    result.append(rangeItem)
                }

                if !timedContent.isEmpty,
                   let overlappingTimedItem = parsePerspectiveTimedBlock(
                       timedContent,
                       date: date.date,
                       firstTime: nil,
                       scopeMonthKey: scopeMonthKey
                   ) {
                    result.append(overlappingTimedItem)
                }

                index = next
                continue
            }

            var next = index + 1
            while next < lines.count,
                  parseDateLine(lines[next], year: defaultYear) == nil {
                next += 1
            }
            let block = Array(lines[index..<next])
            if let item = parsePerspectiveTimedBlock(
                block,
                date: date.date,
                firstTime: date.time,
                scopeMonthKey: scopeMonthKey
            ) {
                result.append(item)
            }
            index = next
        }

        return result
    }

    private static func makeRangeItem(
        lines: [String],
        start: Date,
        endExclusive: Date,
        scopeMonthKey: Int?
    ) -> AssignmentPlanItem? {
        let labels = eventLabels(lines)
        guard !labels.title.isEmpty, endExclusive > start else { return nil }
        let kind = classifyKind(labels.title + " " + (labels.detail ?? ""))
        return makeImportedItem(
            id: "perspective|range|\(dayKey(start))|\(dayKey(endExclusive))|\(normalizedText(labels.title))",
            kind: kind,
            start: start,
            end: endExclusive,
            title: labels.title,
            detail: labels.detail,
            isAllDayRange: true,
            originMonthKey: scopeMonthKey
        )
    }

    private static func parsePerspectiveTimedBlock(
        _ lines: [String],
        date: Date,
        firstTime: String?,
        scopeMonthKey: Int?
    ) -> AssignmentPlanItem? {
        let usableLines = lines.filter { !isMonthlySummary($0) }
        let combined = usableLines.joined(separator: " ")
        let numbers = extractFlightNumbers(combined)
        var times: [String] = []
        if let firstTime {
            times.append(firstTime)
        }
        for line in usableLines.dropFirst(firstTime == nil ? 0 : 1) {
            if let value = exactTime(line) {
                times.append(value)
            }
        }

        if !numbers.isEmpty,
           times.count >= 2,
           let start = dateWithTime(times[0], baseDate: date),
           var end = dateWithTime(times[1], baseDate: date) {
            if end <= start {
                end = moscowCalendar.date(byAdding: .day, value: 1, to: end) ?? end
            }

            let route = perspectiveRoute(in: usableLines)
            let aircraft = regexMatches(in: combined, pattern: #"A-?3(?:19|20|21)[A-Z]?"#).first
            let legs = makePerspectiveLegs(
                lines: usableLines,
                numbers: numbers,
                route: route,
                baseID: "\(dayKey(start))"
            )
            let allPassenger = !legs.isEmpty && legs.allSatisfy { $0.role == .passenger }
            let plannedMinutes = plannedFlightMinutes(in: usableLines)
            let numberText = numbers.joined(separator: " / ")

            return makeImportedItem(
                id: "perspective|flight|\(dayKey(start))|\(numbers.map(normalizedFlightNumber).joined(separator: "-"))",
                kind: allPassenger ? .passenger : .flight,
                start: start,
                end: end,
                title: "Полётная смена",
                flightNumber: numberText,
                flightNumbers: numbers,
                aircraft: aircraft,
                assignmentGroup: route,
                detail: nil,
                flightLegs: legs,
                plannedFlightMinutes: plannedMinutes,
                isAllDayRange: false,
                originMonthKey: scopeMonthKey
            )
        }

        if times.count >= 2,
           let start = dateWithTime(times[0], baseDate: date),
           var end = dateWithTime(times[1], baseDate: date) {
            if end <= start {
                end = moscowCalendar.date(byAdding: .day, value: 1, to: end) ?? end
            }
            let labels = eventLabels(usableLines)
            guard !labels.title.isEmpty else { return nil }
            let kind = classifyKind(labels.title + " " + (labels.detail ?? ""))
            return makeImportedItem(
                id: "perspective|ground|\(Int(start.timeIntervalSince1970 / 60))|\(normalizedText(labels.title))",
                kind: kind,
                start: start,
                end: end,
                title: labels.title,
                detail: labels.detail,
                isAllDayRange: false,
                originMonthKey: scopeMonthKey
            )
        }

        return nil
    }

    private static func parseOfficialPDF(
        lines: [String],
        defaultYear: Int,
        scopeMonthKey: Int?
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

            if date.time == nil,
               index + 2 < lines.count,
               let rawEnd = parseDateLine(lines[index + 1], year: year),
               rawEnd.time == nil,
               isRangeMarker(lines[index + 2]) {
                var next = index + 2
                while next < lines.count,
                      parseDateLine(lines[next], year: year) == nil,
                      !lines[next].localizedCaseInsensitiveContains("график работ") {
                    next += 1
                }
                let content = Array(lines[(index + 2)..<next])
                if let item = makeRangeItem(
                    lines: content,
                    start: date.date,
                    endExclusive: adjustedRangeEnd(rawEnd.date, start: date.date),
                    scopeMonthKey: scopeMonthKey
                ) {
                    result.append(item)
                }
                index = next
                continue
            }

            var next = index + 1
            while next < lines.count,
                  parseDateLine(lines[next], year: year) == nil,
                  !lines[next].localizedCaseInsensitiveContains("график работ") {
                next += 1
            }
            let block = Array(lines[index..<next])
            result.append(contentsOf: parseOfficialBlock(
                block,
                date: date.date,
                firstTime: date.time,
                scopeMonthKey: scopeMonthKey
            ))
            index = next
        }
        return result
    }

    private static func parseOfficialBlock(
        _ lines: [String],
        date: Date,
        firstTime: String?,
        scopeMonthKey: Int?
    ) -> [AssignmentPlanItem] {
        let usableLines = lines.filter { !isMonthlySummary($0) }
        let combined = usableLines.joined(separator: " ")
        let numbers = extractFlightNumbers(combined)
        let allTimes = regexMatches(in: combined, pattern: #"\b(?:[01]?\d|2[0-3]):[0-5]\d\b"#)
        var times = allTimes
        if let firstTime, times.first != firstTime {
            times.insert(firstTime, at: 0)
        }

        if !numbers.isEmpty,
           times.count >= 2,
           let start = dateWithTime(times[0], baseDate: date),
           var end = dateWithTime(times[1], baseDate: date) {
            if end <= start {
                end = moscowCalendar.date(byAdding: .day, value: 1, to: end) ?? end
            }
            let passenger = combined.localizedCaseInsensitiveContains("пассаж")
            let airports = extractAirports(combined)
            let aircraft = regexMatches(in: combined, pattern: #"A-?3(?:19|20|21)[A-Z]?"#).first
            let numberText = numbers.joined(separator: " / ")
            let legs = numbers.enumerated().map { index, number in
                AssignmentPlanLeg(
                    id: "official-leg|\(dayKey(start))|\(normalizedFlightNumber(number))|\(index)",
                    flightNumber: number,
                    role: passenger ? .passenger : .workingPilot,
                    departure: nil,
                    arrival: nil
                )
            }
            return [makeImportedItem(
                id: "official|flight|\(dayKey(start))|\(numbers.map(normalizedFlightNumber).joined(separator: "-"))",
                kind: passenger ? .passenger : .flight,
                start: start,
                end: end,
                title: numbers.count > 1 ? "Полётная смена" : numberText,
                flightNumber: numberText,
                flightNumbers: numbers,
                departure: airports.first,
                arrival: airports.count > 1 ? airports.last : nil,
                aircraft: aircraft,
                detail: nil,
                flightLegs: legs,
                plannedFlightMinutes: plannedFlightMinutes(in: usableLines),
                isAllDayRange: false,
                originMonthKey: scopeMonthKey
            )]
        }

        if times.count >= 2,
           let start = dateWithTime(times[0], baseDate: date),
           var end = dateWithTime(times[1], baseDate: date) {
            if end <= start {
                end = moscowCalendar.date(byAdding: .day, value: 1, to: end) ?? end
            }
            let labels = eventLabels(usableLines)
            guard !labels.title.isEmpty else { return [] }
            return [makeImportedItem(
                id: "official|ground|\(Int(start.timeIntervalSince1970 / 60))|\(normalizedText(labels.title))",
                kind: classifyKind(labels.title + " " + (labels.detail ?? "")),
                start: start,
                end: end,
                title: labels.title,
                detail: labels.detail,
                isAllDayRange: false,
                originMonthKey: scopeMonthKey
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
        assignmentGroup: String? = nil,
        detail: String? = nil,
        flightLegs: [AssignmentPlanLeg]? = nil,
        plannedFlightMinutes: Int? = nil,
        isAllDayRange: Bool? = nil,
        originMonthKey: Int? = nil
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
            importedAt: Date(),
            detail: detail,
            flightLegs: flightLegs,
            plannedFlightMinutes: plannedFlightMinutes,
            isAllDayRange: isAllDayRange,
            originMonthKey: originMonthKey
        )
    }

    private static func parseDateLine(
        _ line: String,
        year: Int
    ) -> (date: Date, time: String?)? {
        guard let groups = captureGroups(
            in: line,
            pattern: #"^(\d{1,2})\.(\d{1,2}),"#
        ), groups.count >= 3,
        let day = Int(groups[1]),
        let month = Int(groups[2]),
        let date = makeDate(day: day, month: month, year: year) else {
            return nil
        }
        let time = regexMatches(
            in: line,
            pattern: #"\b(?:[01]?\d|2[0-3]):[0-5]\d\b"#
        ).first
        return (date, time)
    }

    private static func makeDate(day: Int, month: Int, year: Int) -> Date? {
        var components = DateComponents()
        components.timeZone = moscowTimeZone
        components.year = year
        components.month = month
        components.day = day
        return moscowCalendar.date(from: components)
    }

    private static func adjustedRangeEnd(_ rawEnd: Date, start: Date) -> Date {
        guard rawEnd <= start else { return rawEnd }
        return moscowCalendar.date(byAdding: .year, value: 1, to: rawEnd) ?? rawEnd
    }

    private static func isRangeMarker(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("–") || trimmed.hasPrefix("-") || trimmed.hasPrefix("—")
    }

    private static func exactTime(_ line: String) -> String? {
        let value = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard regexMatches(in: value, pattern: #"^(?:[01]?\d|2[0-3]):[0-5]\d$"#).first != nil else {
            return nil
        }
        return value
    }

    private static func eventLabels(_ lines: [String]) -> (title: String, detail: String?) {
        var cleaned: [String] = []
        for raw in lines {
            guard !isMonthlySummary(raw), exactTime(raw) == nil else { continue }
            guard regexMatches(in: raw, pattern: #"^\d{1,2}\.\d{1,2},"#).isEmpty else {
                continue
            }
            guard extractFlightNumbers(raw).isEmpty else { continue }
            guard perspectiveRoute(in: [raw]) == nil else { continue }

            let value = cleanEventLine(raw)
            guard !value.isEmpty else { continue }
            if cleaned.last.map(normalizedText) != normalizedText(value) {
                cleaned.append(value)
            }
        }

        guard let first = cleaned.first else { return ("", nil) }
        let title = canonicalEventTitle(first)
        let remaining = cleaned.dropFirst().filter { normalizedText($0) != normalizedText(title) }
        let detailText = remaining.joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (title, detailText.isEmpty ? nil : detailText)
    }

    private static func cleanEventLine(_ line: String) -> String {
        line
            .trimmingCharacters(in: CharacterSet(charactersIn: "-–—• "))
            .replacingOccurrences(
                of: #"\s*\(A-?3(?:19|20|21)[A-Z]?\)\s*"#,
                with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func canonicalEventTitle(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("резерв в месте жит") || lower.contains("резерв в месте житель") {
            return "Резерв в месте жительства"
        }
        if lower.hasPrefix("резерв") {
            return "Резерв"
        }
        if lower.contains("выходн") {
            return "Выходной"
        }
        if lower.contains("медкомисс") || lower.contains("влэк") {
            return "Медкомиссия"
        }
        if lower.hasPrefix("отпуск") || lower.contains(" отпуск") {
            return "Отпуск"
        }
        if lower.contains("тренаж") || lower.contains("ктс") {
            return raw
        }
        if lower.hasPrefix("явка") {
            return "Явка"
        }
        if lower.hasPrefix("обучение") {
            return "Обучение"
        }
        return raw
    }

    private static func classifyKind(
        _ text: String,
        hasFlights: Bool = false,
        passengerOnly: Bool = false
    ) -> AssignmentPlanKind {
        if hasFlights {
            return passengerOnly ? .passenger : .flight
        }

        let value = text.lowercased()
        if value.contains("резерв в месте жит") || value.contains("резерв в месте житель") {
            return .homeReserve
        }
        if value.contains("резерв") {
            return .hotelReserve
        }
        if value.contains("выходн") {
            return .dayOff
        }
        if value.contains("медкомисс") || value.contains("влэк") {
            return .medical
        }
        if value.contains("отпуск") {
            return .leave
        }
        if value.contains("тренаж") || value.contains("ктс") {
            return .simulator
        }
        if value.contains("обуч") || value.contains("явка") || value.contains("инструктаж") {
            return .training
        }
        return .ground
    }

    private static func plannedFlightMinutes(in lines: [String]) -> Int? {
        var total = 0
        var found = false
        for line in lines where !extractFlightNumbers(line).isEmpty {
            guard let groups = captureGroups(
                in: line,
                pattern: #"(\d+)\s*ч\s*(\d+)\s*мин"#
            ), groups.count >= 3,
            let hours = Int(groups[1]),
            let minutes = Int(groups[2]) else {
                continue
            }
            total += hours * 60 + minutes
            found = true
        }
        return found ? total : nil
    }

    private static func makePerspectiveLegs(
        lines: [String],
        numbers: [String],
        route: String?,
        baseID: String
    ) -> [AssignmentPlanLeg] {
        var roleByNumber: [String: AssignmentFlightRole] = [:]
        for line in lines {
            let lineNumbers = extractFlightNumbers(line)
            guard !lineNumbers.isEmpty else { continue }
            let passengerNumbers = explicitPassengerNumbers(in: line)
            for number in lineNumbers {
                let normalized = normalizedFlightNumber(number)
                roleByNumber[normalized] = passengerNumbers.contains(normalized)
                    ? .passenger
                    : .workingPilot
            }
        }

        let nodes = route.flatMap { routeNodes($0, expectedLegCount: numbers.count) }
        return numbers.enumerated().map { index, number in
            let normalized = normalizedFlightNumber(number)
            return AssignmentPlanLeg(
                id: "perspective-leg|\(baseID)|\(normalized)|\(index)",
                flightNumber: number,
                role: roleByNumber[normalized] ?? .workingPilot,
                departure: nodes?[safe: index],
                arrival: nodes?[safe: index + 1]
            )
        }
    }

    private static func explicitPassengerNumbers(in line: String) -> Set<String> {
        guard line.localizedCaseInsensitiveContains("пассаж") else { return [] }
        let numbers = extractFlightNumbers(line)
        guard !numbers.isEmpty else { return [] }
        if numbers.count == 1 {
            return [normalizedFlightNumber(numbers[0])]
        }

        if let groups = captureGroups(
            in: line,
            pattern: #"(SU\s*\d{2,4})[^S]{0,80}назначение\s+в\s+качестве\s+пассажира"#
        ), groups.count >= 2 {
            return [normalizedFlightNumber(groups[1])]
        }

        // Если исходник пометил пассажиром всю строку с несколькими номерами,
        // сохраняем эту информацию для всех рейсов этой строки.
        return Set(numbers.map(normalizedFlightNumber))
    }

    private static func routeNodes(
        _ route: String,
        expectedLegCount: Int
    ) -> [String]? {
        var protected = route
        let replacements: [(String, String)] = [
            ("Горно-Алтайск", "Горно§Алтайск"),
            ("Улан-Удэ", "Улан§Удэ"),
            ("Санкт-Петербург", "Санкт§Петербург")
        ]
        for pair in replacements {
            protected = protected.replacingOccurrences(of: pair.0, with: pair.1)
        }
        var parts = protected
            .split(separator: "-")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        for index in parts.indices {
            parts[index] = parts[index].replacingOccurrences(of: "§", with: "-")
        }
        return parts.count == expectedLegCount + 1 ? parts : nil
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
                && parseDateLine(line, year: 2000) == nil
                && exactTime(line) == nil
        }
    }

    private static func isMonthlySummary(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.contains("планируемое полётное время за")
            || lower.contains("планируемое полетное время за")
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

    private static func planScopeMonthKey(
        lines: [String],
        defaultYear: Int
    ) -> Int? {
        let header = lines.prefix(12).joined(separator: " ").lowercased()
        let months: [(String, Int)] = [
            ("январ", 1), ("феврал", 2), ("март", 3), ("апрел", 4),
            ("мая", 5), ("май", 5), ("июн", 6), ("июл", 7),
            ("август", 8), ("сентябр", 9), ("октябр", 10),
            ("ноябр", 11), ("декабр", 12)
        ]
        if let month = months.first(where: { header.contains($0.0) })?.1 {
            return defaultYear * 100 + month
        }
        for line in lines {
            if let parsed = parseDateLine(line, year: defaultYear) {
                let month = moscowCalendar.component(.month, from: parsed.date)
                return defaultYear * 100 + month
            }
        }
        return nil
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

    private static func cleanICSDescription(_ value: String, summary: String) -> String? {
        let lines = value
            .components(separatedBy: .newlines)
            .map { cleanICSText($0) }
            .filter { !$0.isEmpty }
            .filter { normalizedText($0) != normalizedText(summary) }
        let text = lines.joined(separator: " · ")
        return text.isEmpty ? nil : text
    }
}


private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
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
