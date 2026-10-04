import SwiftUI
import Foundation
import PDFKit
import UIKit


enum AssignmentImportDecision: String, Codable {
    case include
    case exclude
}


struct AssignmentImportRecord: Identifiable, Codable, Equatable {
    var original: AssignmentPlanItem
    var decision: AssignmentImportDecision = .include
    var edited: AssignmentPlanItem?

    var id: String { original.id }

    var effectiveItem: AssignmentPlanItem {
        edited ?? original
    }
}


struct AssignmentImportArchive: Codable {
    var records: [AssignmentImportRecord]
    var generatedAt: Date?
    var scopeMonthKeys: [Int]
    var hadInitialConflicts: Bool
    var savedAt: Date
}


struct AssignmentConflictPair: Identifiable, Equatable {
    var leftID: String
    var rightID: String

    var id: String {
        [leftID, rightID].sorted().joined(separator: "|")
    }
}


@MainActor
final class AssignmentImportArchiveStore: ObservableObject {
    static let shared = AssignmentImportArchiveStore()

    @Published private(set) var latestArchive: AssignmentImportArchive?

    private let key = "assignmentImportArchiveV119"

    private init() {
        load()
    }

    var hadConflicts: Bool {
        latestArchive?.hadInitialConflicts == true
    }

    func save(_ archive: AssignmentImportArchive) {
        latestArchive = archive
        guard let data = try? JSONEncoder().encode(archive) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func clear() {
        latestArchive = nil
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func load() {
        guard let decoded = StorageSafety.decode(
            AssignmentImportArchive.self, key: key, title: "Решения конфликтов импорта"
        ) else {
            return
        }
        latestArchive = decoded
    }
}


private enum PerspectivePlanImportEnricher {
    private struct RowKey: Hashable {
        let page: Int
        let row: Int
    }

    private struct GeometryRow {
        var top: CGFloat
        var bottom: CGFloat
        var tableLeft: CGFloat
        var dateRight: CGFloat
        var contentLeft: CGFloat
        var tableRight: CGFloat
    }

    static func enrich(
        snapshot: AssignmentPlanSnapshot,
        url: URL
    ) -> AssignmentPlanSnapshot {
        guard url.pathExtension.lowercased() == "pdf",
              let document = PDFDocument(url: url) else {
            return snapshot
        }

        let rowContent = rawContentByRow(document: document)
        guard !rowContent.isEmpty else { return snapshot }

        var result = snapshot
        result.items = snapshot.items.map { source in
            guard let key = rowKey(from: source.id),
                  let raw = rowContent[key] else {
                return source
            }
            return enrich(item: source, rawContent: raw)
        }
        return result
    }

    private static func enrich(
        item source: AssignmentPlanItem,
        rawContent: String
    ) -> AssignmentPlanItem {
        var item = source

        if item.isFlightLike {
            enrichRoute(item: &item, rawContent: rawContent)
            return item
        }

        let cleanedLines = rawContent
            .components(separatedBy: .newlines)
            .map(cleanGroundLine)
            .filter { !$0.isEmpty }

        if !cleanedLines.isEmpty {
            var detailLines = cleanedLines
            let titleKey = normalizedText(item.title)
            if let titleIndex = detailLines.firstIndex(where: { line in
                let value = normalizedText(line)
                return value == titleKey
                    || (!titleKey.isEmpty && value.hasPrefix(titleKey))
                    || (!value.isEmpty && titleKey.hasPrefix(value))
            }) {
                detailLines.remove(at: titleIndex)
            } else if !detailLines.isEmpty {
                detailLines.removeFirst()
            }

            let aircraftValues = aircraftTypes(in: rawContent)
            let aircraftKeys = Set(aircraftValues.map { normalizedText($0) })
            detailLines = detailLines.filter { line in
                let normalized = normalizedText(line)
                return !aircraftKeys.contains(normalized)
                    && flightNumbers(in: line).isEmpty
            }

            let detail = detailLines
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            item.detail = detail.isEmpty ? nil : detail
        }

        if item.kind == .simulator,
           let aircraft = aircraftTypes(in: rawContent).first {
            item.aircraft = normalizeAircraft(aircraft)
        }

        return item
    }

    private static func enrichRoute(
        item: inout AssignmentPlanItem,
        rawContent: String
    ) {
        let numbers = item.flightNumbers
            ?? item.flightLegs?.map(\.flightNumber)
            ?? item.flightNumber.map { [$0] }
            ?? []
        guard !numbers.isEmpty,
              let nodes = routeNodes(in: rawContent, expectedLegCount: numbers.count) else {
            return
        }

        let expanded = nodes.map(expandAirport)
        guard expanded.count == numbers.count + 1 else { return }

        item.departure = expanded.first
        item.arrival = expanded.last
        item.assignmentGroup = expanded.joined(separator: " - ")

        if var legs = item.flightLegs, legs.count == numbers.count {
            for index in legs.indices {
                legs[index].departure = expanded[index]
                legs[index].arrival = expanded[index + 1]
            }
            item.flightLegs = legs
        }

        if var metadata = AssignmentV119MetadataCodec.metadata(from: item.detail),
           metadata.legs.count == numbers.count {
            for index in metadata.legs.indices {
                metadata.legs[index].departure = expanded[index]
                metadata.legs[index].arrival = expanded[index + 1]
            }
            item.detail = AssignmentV119MetadataCodec.replacingMetadata(
                in: item.detail,
                with: metadata
            )
        }
    }

    private static func rowKey(from id: String) -> RowKey? {
        var value = id
        if value.hasPrefix("ics|") {
            value.removeFirst(4)
        }
        let parts = value.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count >= 3,
              parts[0] == "p119",
              let page = Int(parts[1]),
              let row = Int(parts[2]) else {
            return nil
        }
        return RowKey(page: page, row: row)
    }

    private static func rawContentByRow(
        document: PDFDocument
    ) -> [RowKey: String] {
        var result: [RowKey: String] = [:]

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            let rows = geometryRows(page: page)
            for (rowIndex, row) in rows.enumerated() {
                let content = text(
                    page: page,
                    topRect: CGRect(
                        x: row.contentLeft,
                        y: row.top,
                        width: row.tableRight - row.contentLeft,
                        height: row.bottom - row.top
                    )
                )
                if !content.isEmpty {
                    result[RowKey(page: pageIndex, row: rowIndex)] = content
                }
            }
        }
        return result
    }

    private static func geometryRows(page: PDFPage) -> [GeometryRow] {
        let pageBounds = page.bounds(for: .mediaBox)
        guard pageBounds.width > 0, pageBounds.height > 0 else { return [] }

        let separatorTops = renderedSeparatorTops(page: page, bounds: pageBounds)
        guard separatorTops.count >= 2 else { return [] }

        let left = pageBounds.width * (75.0 / 595.275)
        let dateRight = pageBounds.width * (136.5 / 595.275)
        let contentLeft = pageBounds.width * (180.0 / 595.275)
        let right = pageBounds.width * (520.275 / 595.275)

        var rows: [GeometryRow] = []
        for index in 0..<(separatorTops.count - 1) {
            let top = separatorTops[index]
            let bottom = separatorTops[index + 1]
            guard bottom - top > 8 else { continue }
            rows.append(
                GeometryRow(
                    top: top + 0.8,
                    bottom: bottom - 0.8,
                    tableLeft: left,
                    dateRight: dateRight,
                    contentLeft: contentLeft,
                    tableRight: right
                )
            )
        }
        return rows
    }

    private static func renderedSeparatorTops(
        page: PDFPage,
        bounds: CGRect
    ) -> [CGFloat] {
        let scale: CGFloat = 2
        let width = max(1, Int((bounds.width * scale).rounded()))
        let height = max(1, Int((bounds.height * scale).rounded()))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 255, count: height * bytesPerRow)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return []
        }

        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.saveGState()
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: scale, y: -scale)
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()

        let scanLeft = max(0, Int(bounds.width * (70.0 / 595.275) * scale))
        let scanRight = min(width - 1, Int(bounds.width * (525.0 / 595.275) * scale))
        let scanWidth = max(1, scanRight - scanLeft)
        var matchingRows: [Int] = []

        for y in 0..<height {
            var grayCount = 0
            var longestRun = 0
            var currentRun = 0
            let rowStart = y * bytesPerRow

            for x in scanLeft...scanRight {
                let offset = rowStart + x * bytesPerPixel
                let r = Int(pixels[offset])
                let g = Int(pixels[offset + 1])
                let b = Int(pixels[offset + 2])
                let maxChannel = max(r, max(g, b))
                let minChannel = min(r, min(g, b))
                let isSeparatorGray = r >= 215 && r <= 247
                    && g >= 215 && g <= 247
                    && b >= 215 && b <= 247
                    && maxChannel - minChannel <= 10

                if isSeparatorGray {
                    grayCount += 1
                    currentRun += 1
                    longestRun = max(longestRun, currentRun)
                } else {
                    currentRun = 0
                }
            }

            if grayCount > Int(Double(scanWidth) * 0.55)
                && longestRun > Int(Double(scanWidth) * 0.50) {
                matchingRows.append(y)
            }
        }

        guard !matchingRows.isEmpty else { return [] }
        var clusters: [[Int]] = []
        for value in matchingRows {
            if let last = clusters.indices.last,
               let previous = clusters[last].last,
               value - previous <= 2 {
                clusters[last].append(value)
            } else {
                clusters.append([value])
            }
        }

        return clusters.compactMap { cluster -> CGFloat? in
            guard let first = cluster.first, let last = cluster.last else { return nil }
            let renderedY = CGFloat(first + last) / 2 / scale
            return bounds.height - renderedY
        }
        .filter { $0 > 55 && $0 < bounds.height - 30 }
        .sorted()
    }

    private static func text(page: PDFPage, topRect: CGRect) -> String {
        let bounds = page.bounds(for: .mediaBox)
        let pdfRect = CGRect(
            x: topRect.minX,
            y: bounds.height - topRect.maxY,
            width: topRect.width,
            height: topRect.height
        )
        return page.selection(for: pdfRect)?.string?
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func routeNodes(
        in content: String,
        expectedLegCount: Int
    ) -> [String]? {
        for raw in content.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            let lower = line.lowercased()
            guard flightNumbers(in: line).isEmpty,
                  aircraftTypes(in: line).isEmpty,
                  !lower.contains("планируем"),
                  regex(in: line, pattern: #"\b\d{1,2}:\d{2}\b"#).isEmpty else {
                continue
            }

            let nodes = splitRoutePreservingCityHyphens(line)
            if nodes.count == expectedLegCount + 1 {
                return nodes
            }
        }
        return nil
    }

    private static func splitRoutePreservingCityHyphens(_ route: String) -> [String] {
        var protected = route.replacingOccurrences(
            of: #"(?<=\p{L})[-‐‑‒–—](?=\p{L})"#,
            with: "§",
            options: .regularExpression
        )
        protected = protected.replacingOccurrences(
            of: #"[‐‑‒–—]"#,
            with: "-",
            options: .regularExpression
        )
        return protected
            .split(separator: "-")
            .map { String($0).replacingOccurrences(of: "§", with: "-") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func cleanGroundLine(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: CharacterSet(charactersIn: "-–—• \n\r\t"))
            .replacingOccurrences(
                of: #"\s*\((?:A|B)-?\d{3,4}[A-Z]?\)\s*"#,
                with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func aircraftTypes(in text: String) -> [String] {
        regex(
            in: text.uppercased(),
            pattern: #"\b(?:A|B)-?\d{3,4}[A-Z]?\b"#
        )
    }

    private static func normalizeAircraft(_ value: String) -> String {
        value.replacingOccurrences(of: "-", with: "")
    }

    private static func flightNumbers(in text: String) -> [String] {
        regex(in: text.uppercased(), pattern: #"SU\s*\d{2,4}"#)
    }

    private static func expandAirport(_ value: String) -> String {
        value
            .replacingOccurrences(of: "Ш (B)", with: "Шереметьево (B)")
            .replacingOccurrences(of: "Ш (C)", with: "Шереметьево (C)")
            .replacingOccurrences(of: "Ш(B)", with: "Шереметьево (B)")
            .replacingOccurrences(of: "Ш(C)", with: "Шереметьево (C)")
    }

    private static func normalizedText(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ru_RU"))
            .replacingOccurrences(
                of: #"[^a-zа-я0-9]"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
    }

    private static func regex(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(
            in: text,
            range: NSRange(location: 0, length: ns.length)
        ).map { ns.substring(with: $0.range) }
    }
}


@MainActor
final class AssignmentImportDraft: ObservableObject, Identifiable {
    let id = UUID()

    @Published var records: [AssignmentImportRecord]

    let generatedAt: Date?
    let scopeMonthKeys: [Int]
    let hadInitialConflicts: Bool

    init(
        items: [AssignmentPlanItem],
        generatedAt: Date?,
        scopeMonthKeys: [Int],
        hadInitialConflicts: Bool? = nil,
        records: [AssignmentImportRecord]? = nil
    ) {
        let initialRecords = records ?? items.map {
            AssignmentImportRecord(original: $0)
        }
        self.records = initialRecords
        self.generatedAt = generatedAt
        self.scopeMonthKeys = scopeMonthKeys
        let initialPairs = Self.conflicts(in: initialRecords)
        self.hadInitialConflicts = hadInitialConflicts ?? !initialPairs.isEmpty
    }

    convenience init(archive: AssignmentImportArchive) {
        self.init(
            items: archive.records.map(\.original),
            generatedAt: archive.generatedAt,
            scopeMonthKeys: archive.scopeMonthKeys,
            hadInitialConflicts: archive.hadInitialConflicts,
            records: archive.records
        )
    }

    var includedItems: [AssignmentPlanItem] {
        records
            .filter { $0.decision == .include }
            .map(\.effectiveItem)
            .sorted { $0.start < $1.start }
    }

    var excludedRecords: [AssignmentImportRecord] {
        records.filter { $0.decision == .exclude }
    }

    var conflictPairs: [AssignmentConflictPair] {
        Self.conflicts(in: records)
    }

    var unresolvedConflictCount: Int {
        conflictPairs.count
    }

    var canSave: Bool {
        unresolvedConflictCount == 0 && !includedItems.isEmpty
    }

    func item(id: String) -> AssignmentPlanItem? {
        records.first(where: { $0.id == id })?.effectiveItem
    }

    func isEdited(_ id: String) -> Bool {
        records.first(where: { $0.id == id })?.edited != nil
    }

    func exclude(_ id: String) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].decision = .exclude
    }

    func include(_ id: String) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].decision = .include
    }

    func keep(_ keptID: String, exclude otherID: String) {
        include(keptID)
        exclude(otherID)
    }

    func edit(_ item: AssignmentPlanItem) {
        guard let index = records.firstIndex(where: { $0.id == item.id }) else { return }
        records[index].edited = item
        records[index].decision = .include
    }

    func restoreOriginal(_ id: String) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].edited = nil
        records[index].decision = .include
    }

    func archive() -> AssignmentImportArchive {
        AssignmentImportArchive(
            records: records,
            generatedAt: generatedAt,
            scopeMonthKeys: scopeMonthKeys,
            hadInitialConflicts: hadInitialConflicts,
            savedAt: Date()
        )
    }

    static func parse(urls: [URL]) throws -> AssignmentImportDraft {
        var items: [AssignmentPlanItem] = []
        var generatedAt: Date?
        var monthKeys: Set<Int> = []

        for url in urls {
            let parsed = try PerspectivePlanV119Parser.parseFile(url: url)
            let snapshot = PerspectivePlanImportEnricher.enrich(
                snapshot: parsed,
                url: url
            )
            items.append(contentsOf: snapshot.items)
            if generatedAt == nil {
                generatedAt = snapshot.generatedAt
            }
            if let key = snapshot.scopeMonthKey {
                monthKeys.insert(key)
            }
        }

        return AssignmentImportDraft(
            items: items,
            generatedAt: generatedAt,
            scopeMonthKeys: monthKeys.sorted()
        )
    }

    @discardableResult
    func commit(
        to planStore: AssignmentPlanStore,
        actualFlights: [FlightLeg]
    ) throws -> Int {
        guard unresolvedConflictCount == 0 else {
            throw AssignmentImportV119Error.unresolvedConflicts
        }
        let items = includedItems
        guard !items.isEmpty else {
            throw AssignmentImportV119Error.emptyResolvedPlan
        }

        let data = AssignmentImportICSBridge.makeICS(items: items)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AeroUchet-v119-resolved-\(UUID().uuidString).ics")
        try data.write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        let count = try planStore.importPlanFile(
            url: url,
            actualFlights: actualFlights
        )
        AssignmentImportArchiveStore.shared.save(archive())
        return count
    }

    private static func conflicts(
        in records: [AssignmentImportRecord]
    ) -> [AssignmentConflictPair] {
        let included = records
            .filter { $0.decision == .include }
            .map(\.effectiveItem)
            .sorted { $0.start < $1.start }

        var result: [AssignmentConflictPair] = []
        guard included.count > 1 else { return result }

        for leftIndex in included.indices {
            for rightIndex in included.indices where rightIndex > leftIndex {
                let left = included[leftIndex]
                let right = included[rightIndex]
                if right.start >= left.end { break }
                guard itemsConflict(left, right) else { continue }
                result.append(
                    AssignmentConflictPair(
                        leftID: left.id,
                        rightID: right.id
                    )
                )
            }
        }
        return result
    }

    private static func itemsConflict(
        _ lhs: AssignmentPlanItem,
        _ rhs: AssignmentPlanItem
    ) -> Bool {
        guard lhs.start < rhs.end, rhs.start < lhs.end else { return false }

        let leftMeta = AssignmentV119MetadataCodec.metadata(from: lhs.detail)
        let rightMeta = AssignmentV119MetadataCodec.metadata(from: rhs.detail)
        if let leftGroup = leftMeta?.linkedGroupID,
           leftGroup == rightMeta?.linkedGroupID {
            return false
        }

        if lhs.isFlightLike && rhs.isFlightLike {
            let leftNumbers = normalizedFlights(lhs)
            let rightNumbers = normalizedFlights(rhs)
            if !leftNumbers.isEmpty,
               !rightNumbers.isEmpty,
               !leftNumbers.isDisjoint(with: rightNumbers) {
                return false
            }
        }

        if !lhs.isFlightLike,
           !rhs.isFlightLike,
           normalizedText(lhs.title) == normalizedText(rhs.title),
           moscowCalendar.isDate(lhs.start, inSameDayAs: rhs.start) {
            return false
        }

        return true
    }

    private static func normalizedFlights(_ item: AssignmentPlanItem) -> Set<String> {
        let values = item.flightNumbers
            ?? item.flightLegs?.map(\.flightNumber)
            ?? item.flightNumber.map { [$0] }
            ?? []
        return Set(values.map { $0.filter(\.isNumber) }.filter { !$0.isEmpty })
    }

    private static func normalizedText(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ru_RU"))
            .replacingOccurrences(
                of: #"[^a-zа-я0-9]"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
    }
}


enum AssignmentImportV119Error: LocalizedError {
    case unresolvedConflicts
    case emptyResolvedPlan

    var errorDescription: String? {
        switch self {
        case .unresolvedConflicts:
            return "Сначала разреши все конфликты импорта."
        case .emptyResolvedPlan:
            return "После разрешения конфликтов не осталось назначений для сохранения."
        }
    }
}


private enum AssignmentImportICSBridge {
    static func makeICS(items: [AssignmentPlanItem]) -> Data {
        var lines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//AeroUchet//Resolved Import V119//RU",
            "CALSCALE:GREGORIAN"
        ]

        for item in items {
            lines.append("BEGIN:VEVENT")
            lines.append("UID:\(escape(item.id))@aerouchet-v119")

            if item.isAllDay {
                lines.append("DTSTART;VALUE=DATE:\(dateOnly(item.start))")
                lines.append("DTEND;VALUE=DATE:\(dateOnly(item.end))")
            } else {
                lines.append("DTSTART:\(dateTime(item.start))")
                lines.append("DTEND:\(dateTime(item.end))")
            }

            lines.append("SUMMARY:\(escape(summary(for: item)))")
            let description = description(for: item)
            if !description.isEmpty {
                lines.append("DESCRIPTION:\(escape(description))")
            }
            lines.append("END:VEVENT")
        }

        lines.append("END:VCALENDAR")
        return lines.joined(separator: "\r\n").data(using: .utf8) ?? Data()
    }

    private static func summary(for item: AssignmentPlanItem) -> String {
        if item.kind == .flight || item.kind == .passenger {
            let prefix = item.kind == .passenger ? "🧳" : "✈️"
            let numbers = item.flightNumbers
                ?? item.flightLegs?.map(\.flightNumber)
                ?? item.flightNumber.map { [$0] }
                ?? []
            return prefix + " " + (numbers.isEmpty ? item.title : numbers.joined(separator: " / "))
        }
        return item.title
    }

    private static func description(for item: AssignmentPlanItem) -> String {
        var parts: [String] = []
        if let detail = item.detail, !detail.isEmpty {
            parts.append(detail)
        }
        if let plannedFlightMinutes = item.plannedFlightMinutes {
            parts.append("[[AU119FLIGHT:\(plannedFlightMinutes)]]")
        }
        if item.kind == .passenger {
            let basis = AssignmentV119MetadataCodec.metadata(from: item.detail)?.passengerBasis
                ?? "по заданию"
            parts.append("назначение в качестве пассажира \(basis)")
        }
        if let aircraft = item.aircraft, !aircraft.isEmpty {
            parts.append(aircraft)
        }
        return parts.joined(separator: "\n")
    }

    private static func dateOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = moscowTimeZone
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    private static func dateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = moscowTimeZone
        formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        return formatter.string(from: date)
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
    }
}


struct AssignmentConflictResolverView: View {
    @ObservedObject var draft: AssignmentImportDraft
    let onCancel: () -> Void
    let onSave: () -> Void

    @State private var editingItem: AssignmentPlanItem?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: draft.unresolvedConflictCount == 0
                              ? "checkmark.circle.fill"
                              : "exclamationmark.triangle.fill")
                            .foregroundStyle(draft.unresolvedConflictCount == 0 ? .green : .red)
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(draft.unresolvedConflictCount == 0
                                 ? "Все конфликты разрешены"
                                 : "Осталось конфликтов: \(draft.unresolvedConflictCount)")
                                .font(.headline)
                            Text(
                                "Исходный результат распознавания сохраняется. Исключённые и изменённые назначения можно вернуть позже."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                ForEach(draft.conflictPairs) { pair in
                    if let left = draft.item(id: pair.leftID),
                       let right = draft.item(id: pair.rightID) {
                        Section("Конфликт") {
                            conflictCard(left, otherID: right.id)
                            Divider()
                            conflictCard(right, otherID: left.id)
                        }
                    }
                }

                if !draft.excludedRecords.isEmpty {
                    Section("Исключено") {
                        ForEach(draft.excludedRecords) { record in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(record.effectiveItem.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(dateSummary(record.effectiveItem))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Вернуть") {
                                    draft.include(record.id)
                                }
                            }
                        }
                    }
                }

                if draft.conflictPairs.isEmpty {
                    Section("Назначения после разрешения") {
                        ForEach(draft.includedItems) { item in
                            VStack(alignment: .leading, spacing: 7) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.title)
                                            .font(.subheadline.weight(.semibold))
                                        Text(dateSummary(item))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if draft.isEdited(item.id) {
                                        Text("Изменено")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.orange)
                                    }
                                }

                                HStack {
                                    Button("Изменить") {
                                        editingItem = item
                                    }
                                    .buttonStyle(.bordered)

                                    if draft.isEdited(item.id) {
                                        Button("Вернуть исходное") {
                                            draft.restoreOriginal(item.id)
                                        }
                                        .buttonStyle(.bordered)
                                    }

                                    Button("Исключить", role: .destructive) {
                                        draft.exclude(item.id)
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .font(.caption)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Конфликты импорта")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить план", action: onSave)
                        .fontWeight(.semibold)
                        .disabled(!draft.canSave)
                }
            }
            .sheet(item: $editingItem) { item in
                AssignmentImportEditView(item: item) { updated in
                    draft.edit(updated)
                    editingItem = nil
                }
            }
        }
    }

    private func conflictCard(
        _ item: AssignmentPlanItem,
        otherID: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                    Text(dateSummary(item))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if let detail = AssignmentV119MetadataCodec.humanDetail(item.detail) {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Button("Оставить это") {
                    draft.keep(item.id, exclude: otherID)
                }
                .buttonStyle(.borderedProminent)

                Button("Изменить") {
                    editingItem = item
                }
                .buttonStyle(.bordered)

                Button("Исключить", role: .destructive) {
                    draft.exclude(item.id)
                }
                .buttonStyle(.bordered)
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }

    private func dateSummary(_ item: AssignmentPlanItem) -> String {
        if item.isAllDay {
            let end = moscowCalendar.date(byAdding: .day, value: -1, to: item.end) ?? item.end
            return formatFullDate(item.start)
                + (moscowCalendar.isDate(item.start, inSameDayAs: end)
                   ? ""
                   : " — " + formatFullDate(end))
        }
        let metadata = AssignmentV119MetadataCodec.metadata(from: item.detail)
        let start = metadata?.sourceStart ?? item.start
        let end = metadata?.sourceEnd ?? item.end
        let dates = moscowCalendar.isDate(start, inSameDayAs: end)
            ? formatFullDate(start)
            : "\(formatFullDate(start)) — \(formatFullDate(end))"
        return dates + " · \(clock(start)) — \(clock(end))"
    }

    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = moscowTimeZone
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }

    private func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = moscowTimeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}


private struct AssignmentImportEditView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var item: AssignmentPlanItem
    @State private var humanDetail: String
    @State private var editableStart: Date
    @State private var editableEnd: Date

    let onSave: (AssignmentPlanItem) -> Void

    private var metadata: AssignmentV119Metadata? {
        AssignmentV119MetadataCodec.metadata(from: item.detail)
    }

    private var usesSourceFlightInterval: Bool {
        (item.kind == .flight || item.kind == .passenger)
            && metadata?.sourceStart != nil
            && metadata?.sourceEnd != nil
    }

    init(
        item: AssignmentPlanItem,
        onSave: @escaping (AssignmentPlanItem) -> Void
    ) {
        let metadata = AssignmentV119MetadataCodec.metadata(from: item.detail)
        _item = State(initialValue: item)
        _humanDetail = State(
            initialValue: AssignmentV119MetadataCodec.humanDetail(item.detail) ?? ""
        )
        _editableStart = State(initialValue: metadata?.sourceStart ?? item.start)
        _editableEnd = State(initialValue: metadata?.sourceEnd ?? item.end)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Назначение") {
                    TextField("Название", text: $item.title)
                    TextField("Описание", text: $humanDetail, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section(usesSourceFlightInterval ? "Время из перспективного плана" : "Время") {
                    if item.isAllDay {
                        DatePicker("Начало", selection: $editableStart, displayedComponents: .date)
                        DatePicker("Конец", selection: $editableEnd, displayedComponents: .date)
                    } else {
                        DatePicker(
                            "Начало",
                            selection: $editableStart,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        DatePicker(
                            "Конец",
                            selection: $editableEnd,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }

                    if usesSourceFlightInterval {
                        Text(
                            item.kind == .passenger
                                ? "После сохранения приложение заново добавит 40 минут до вылета к рабочему времени пассажирского перемещения."
                                : "После сохранения приложение заново рассчитает полётную смену: 1:00 до вылета и 0:30 после прилёта."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Изменить назначение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        applyEditedIntervalAndMetadata()
                        onSave(item)
                        dismiss()
                    }
                    .disabled(
                        editableEnd <= editableStart
                            || item.title.trimmingCharacters(in: .whitespaces).isEmpty
                    )
                }
            }
        }
    }

    private func applyEditedIntervalAndMetadata() {
        if var metadata = metadata, usesSourceFlightInterval {
            metadata.sourceStart = editableStart
            metadata.sourceEnd = editableEnd
            metadata.waitingMinutes = nil
            metadata.subsequentDutyReductionMinutes = nil
            metadata.linkedSequenceMinutes = nil
            metadata.linkedGroupID = nil

            if item.kind == .passenger {
                let movementStart = moscowCalendar.date(
                    byAdding: .minute,
                    value: -40,
                    to: editableStart
                ) ?? editableStart
                item.start = movementStart
                item.end = editableEnd
                metadata.passengerMovementMinutes = max(
                    0,
                    Int(editableEnd.timeIntervalSince(movementStart) / 60)
                )
            } else {
                item.start = moscowCalendar.date(
                    byAdding: .minute,
                    value: -60,
                    to: editableStart
                ) ?? editableStart
                item.end = moscowCalendar.date(
                    byAdding: .minute,
                    value: 30,
                    to: editableEnd
                ) ?? editableEnd
            }

            item.detail = AssignmentV119MetadataCodec.encode(
                humanDetail: humanDetail,
                metadata: metadata
            )
            return
        }

        item.start = editableStart
        item.end = editableEnd
        if let metadata = metadata {
            item.detail = AssignmentV119MetadataCodec.encode(
                humanDetail: humanDetail,
                metadata: metadata
            )
        } else {
            item.detail = humanDetail.isEmpty ? nil : humanDetail
        }
    }
}