import SwiftUI
import Foundation
import PDFKit
import Vision
import UniformTypeIdentifiers

// MARK: - Сезон

enum FlightNormSeason: String, Codable, CaseIterable, Identifiable, Sendable {
    case summer = "Лето"
    case winter = "Зима"
    
    var id: String { rawValue }
}

// MARK: - Сохранённая строка

struct FlightNormRow: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var aircraftType: String
    var routeName: String
    var departureIATA: String
    var arrivalIATA: String
    var outboundMinutes: Int
    var returnMinutes: Int
    var note: String
    
    init(
        id: UUID = UUID(),
        aircraftType: String,
        routeName: String,
        departureIATA: String,
        arrivalIATA: String,
        outboundMinutes: Int,
        returnMinutes: Int,
        note: String
    ) {
        self.id = id
        self.aircraftType = aircraftType
        self.routeName = routeName
        self.departureIATA = departureIATA
        self.arrivalIATA = arrivalIATA
        self.outboundMinutes = outboundMinutes
        self.returnMinutes = returnMinutes
        self.note = note
    }
}

// MARK: - Версия нормативов

struct FlightNormVersion: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var year: Int
    var season: FlightNormSeason
    var versionNumber: Int
    var importedAt: Date
    var sourceFileName: String
    var rows: [FlightNormRow]
    
    init(
        id: UUID = UUID(),
        year: Int,
        season: FlightNormSeason,
        versionNumber: Int,
        importedAt: Date = Date(),
        sourceFileName: String,
        rows: [FlightNormRow]
    ) {
        self.id = id
        self.year = year
        self.season = season
        self.versionNumber = versionNumber
        self.importedAt = importedAt
        self.sourceFileName = sourceFileName
        self.rows = rows
    }
    
    var title: String {
        "\(season.rawValue) \(year) • Версия \(versionNumber)"
    }
}

// MARK: - Хранилище

@MainActor
final class FlightNormStore: ObservableObject {
    @Published var versions: [FlightNormVersion] = [] {
        didSet { save() }
    }
    
    private let storageKey = "savedFlightNormVersionsV1"
    
    init() {
        load()
    }
    
    @discardableResult
    func add(_ version: FlightNormVersion) -> Bool {
        let alreadyExists = versions.contains {
            $0.year == version.year &&
            $0.season == version.season &&
            $0.versionNumber == version.versionNumber
        }
        
        guard !alreadyExists else {
            return false
        }
        
        versions.append(version)
        sortVersions()
        return true
    }
    
    func delete(id: UUID) {
        versions.removeAll { $0.id == id }
    }
    
    func nextVersion(year: Int, season: FlightNormSeason) -> Int {
        let values = versions
            .filter { $0.year == year && $0.season == season }
            .map { $0.versionNumber }
        
        return (values.max() ?? 0) + 1
    }
    
    private func sortVersions() {
        versions.sort {
            if $0.year != $1.year {
                return $0.year > $1.year
            }
            
            if $0.season != $1.season {
                return $0.season == .winter
            }
            
            return $0.versionNumber > $1.versionNumber
        }
    }
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(versions)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Ошибка сохранения нормативов:", error)
        }
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }
        
        do {
            versions = try JSONDecoder().decode([FlightNormVersion].self, from: data)
            sortVersions()
        } catch {
            print("Ошибка загрузки нормативов:", error)
        }
    }
}

// MARK: - Черновая строка OCR

struct FlightNormDraftRow: Identifiable, Sendable {
    var id = UUID()
    
    var aircraftType: String
    var routeName: String
    var departureIATA: String
    var arrivalIATA: String
    var outboundTime: String
    var returnTime: String
    var note: String
    var confidence: Float
    
    var isValid: Bool {
        normalizedIATA(departureIATA).count == 3
        &&
        normalizedIATA(arrivalIATA).count == 3
        &&
        minutesFromNormTime(outboundTime) != nil
        &&
        minutesFromNormTime(returnTime) != nil
    }
}

// MARK: - Черновик импорта

struct FlightNormImportDraft: Identifiable, Sendable {
    var id = UUID()
    
    var sourceFileName: String
    var pageCount: Int
    var year: Int
    var season: FlightNormSeason
    var versionNumber: Int
    var rows: [FlightNormDraftRow]
    
    var invalidCount: Int {
        rows.filter { !$0.isValid }.count
    }
    
    func makeVersion() -> FlightNormVersion? {
        guard !rows.isEmpty, invalidCount == 0 else {
            return nil
        }
        
        let savedRows = rows.compactMap { row -> FlightNormRow? in
            guard
                let outbound = minutesFromNormTime(row.outboundTime),
                let inbound = minutesFromNormTime(row.returnTime)
            else {
                return nil
            }
            
            return FlightNormRow(
                aircraftType: row.aircraftType,
                routeName: row.routeName,
                departureIATA: normalizedIATA(row.departureIATA),
                arrivalIATA: normalizedIATA(row.arrivalIATA),
                outboundMinutes: outbound,
                returnMinutes: inbound,
                note: normalizedFlightNormNote(
                    row.note
                )
            )
        }
        
        return FlightNormVersion(
            year: year,
            season: season,
            versionNumber: versionNumber,
            sourceFileName: sourceFileName,
            rows: savedRows
        )
    }
}

// MARK: - OCR

private struct FlightNormOCRToken: Sendable {
    let text: String
    let x: Double
    let y: Double
    let confidence: Float
}

// MARK: - Ошибки импорта

enum FlightNormImportError: LocalizedError {
    case cannotOpenPDF
    case noPages
    case noRows
    
    var errorDescription: String? {
        switch self {
        case .cannotOpenPDF:
            return "Не удалось открыть PDF."
        case .noPages:
            return "В PDF нет страниц."
        case .noRows:
            return "Не удалось распознать строки таблицы."
        }
    }
}

// MARK: - Импорт PDF

enum FlightNormPDFImporter {
    static func importPDF(url: URL) async throws -> FlightNormImportDraft {
        try await Task.detached(priority: .userInitiated) {
            try scanPDF(url: url)
        }.value
    }
    
    private static func scanPDF(url: URL) throws -> FlightNormImportDraft {
        guard let document = PDFDocument(url: url) else {
            throw FlightNormImportError.cannotOpenPDF
        }
        
        guard document.pageCount > 0 else {
            throw FlightNormImportError.noPages
        }
        
        var allRows: [FlightNormDraftRow] = []
        var coverText = ""
        var currentAircraft = ""
        
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else {
                continue
            }
            
            let bounds = page.bounds(for: .mediaBox)
            let width: CGFloat = 2400
            let ratio = bounds.height / max(bounds.width, 1)
            let size = CGSize(width: width, height: width * ratio)
            
            let image = page.thumbnail(of: size, for: .mediaBox)
            
            guard let cgImage = image.cgImage else {
                continue
            }
            
            let tokens = try recognize(cgImage: cgImage)
            
            let pageText = tokens
                .map { $0.text }
                .joined(separator: "\n")
            
            if pageIndex == 0 {
                coverText = pageText
            }
            
            // Первые две страницы —
            // титульный лист и список поправок.
            // Таблицы нормативов начинаются
            // только с третьей страницы.
            
            if pageIndex >= 2 {
                
                if let detected =
                    detectAircraft(
                        in: pageText
                    ) {
                    
                    currentAircraft =
                    detected
                }
                
                
                let rows =
                parseRows(
                    tokens: tokens,
                    aircraft: currentAircraft
                )
                
                
                allRows.append(
                    contentsOf: rows
                )
            }
        }
        
        allRows = removeDuplicates(allRows)
        
        guard !allRows.isEmpty else {
            throw FlightNormImportError.noRows
        }
        
        let metadata = detectMetadata(
            coverText: coverText + "\n" + url.lastPathComponent
        )
        
        return FlightNormImportDraft(
            sourceFileName: url.lastPathComponent,
            pageCount: document.pageCount,
            year: metadata.year,
            season: metadata.season,
            versionNumber: metadata.version,
            rows: allRows
        )
    }
    
    private static func recognize(cgImage: CGImage) throws -> [FlightNormOCRToken] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ru-RU", "en-US"]
        request.usesLanguageCorrection = false
        
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            options: [:]
        )
        
        try handler.perform([request])
        
        guard let observations = request.results else {
            return []
        }
        
        return observations.compactMap { observation -> FlightNormOCRToken? in
            guard let candidate = observation.topCandidates(1).first else {
                return nil
            }
            
            return FlightNormOCRToken(
                text: candidate.string,
                x: Double(observation.boundingBox.minX),
                y: Double(observation.boundingBox.midY),
                confidence: candidate.confidence
            )
        }
    }
    
    private static func parseRows(
        tokens: [FlightNormOCRToken],
        aircraft: String
    ) -> [FlightNormDraftRow] {
        guard !aircraft.isEmpty else {
            return []
        }
        
        let lines = groupIntoLines(tokens)
        var result: [FlightNormDraftRow] = []
        
        for line in lines {
            let sorted = line.sorted { $0.x < $1.x }
            
            let text = sorted
                .map { $0.text }
                .joined(separator: " ")
            
            let iataMatches = regexMatches(
                pattern: #"\b[A-Z]{3}\b"#,
                in: text
            )
            
            let timeMatches = regexMatches(
                pattern: #"\b\d{1,2}[\.\:\,]\d{2}\b"#,
                in: text
            )
            
            guard
                iataMatches.count >= 2,
                timeMatches.count >= 2
            else {
                continue
            }
            
            let departure = iataMatches[0].text
            let arrival = iataMatches[1].text
            
            let outbound = normalizedNormTime(timeMatches[0].text)
            let inbound = normalizedNormTime(timeMatches[1].text)
            
            guard
                minutesFromNormTime(outbound) != nil,
                minutesFromNormTime(inbound) != nil
            else {
                continue
            }
            
            let nsText = text as NSString
            
            let routeRange = NSRange(
                location: 0,
                length: iataMatches[0].range.location
            )
            
            var routeName = nsText.substring(with: routeRange)
            routeName = cleanCellText(routeName)
            
            let secondTime = timeMatches[1].range
            let noteStart = secondTime.location + secondTime.length
            
            var note = ""
            
            if noteStart < nsText.length {
                note = nsText.substring(from: noteStart)
                note = cleanCellText(note)
                note = normalizedFlightNormNote(note)
            }
            
            let confidence: Float
            
            if sorted.isEmpty {
                confidence = 0
            } else {
                confidence =
                sorted.map { $0.confidence }.reduce(0, +)
                /
                Float(sorted.count)
            }
            
            result.append(
                FlightNormDraftRow(
                    aircraftType: aircraft,
                    routeName: routeName,
                    departureIATA: departure,
                    arrivalIATA: arrival,
                    outboundTime: outbound,
                    returnTime: inbound,
                    note: note,
                    confidence: confidence
                )
            )
        }
        
        return result
    }
    
    private static func groupIntoLines(
        _ tokens: [FlightNormOCRToken]
    ) -> [[FlightNormOCRToken]] {
        let ordered = tokens.sorted {
            if $0.y == $1.y {
                return $0.x < $1.x
            }
            
            return $0.y > $1.y
        }
        
        var lines: [[FlightNormOCRToken]] = []
        let tolerance = 0.0045
        
        for token in ordered {
            if let lastIndex = lines.indices.last {
                let averageY =
                lines[lastIndex]
                    .map { $0.y }
                    .reduce(0, +)
                /
                Double(lines[lastIndex].count)
                
                if abs(averageY - token.y) <= tolerance {
                    lines[lastIndex].append(token)
                    continue
                }
            }
            
            lines.append([token])
        }
        
        return lines.map {
            $0.sorted { $0.x < $1.x }
        }
    }
    
    private static func detectAircraft(
        in text: String
    ) -> String? {
        
        // Vision на русском скане может путать
        // латинские и кириллические символы:
        //
        // A330 -> А330
        // A330 -> AЗЗО
        // B737 -> В737
        //
        // Поэтому сначала нормализуем строку.
        
        let value =
        text
            .precomposedStringWithCanonicalMapping
            .uppercased()
            .replacingOccurrences(
                of: "А",
                with: "A"
            )
            .replacingOccurrences(
                of: "В",
                with: "B"
            )
            .replacingOccurrences(
                of: "З",
                with: "3"
            )
            .replacingOccurrences(
                of: "О",
                with: "0"
            )
            .replacingOccurrences(
                of: " ",
                with: ""
            )
        
        
        if value.contains(
            "A320/321"
        )
            ||
            value.contains(
                "A320-321"
            )
            ||
            value.contains(
                "A320321"
            ) {
            
            return
            "A320/321"
        }
        
        
        if value.contains(
            "B737"
        ) {
            
            return
            "B737"
        }
        
        
        if value.contains(
            "A330"
        ) {
            
            return
            "A330"
        }
        
        
        if value.contains(
            "A350"
        ) {
            
            return
            "A350"
        }
        
        
        if value.contains(
            "B777"
        ) {
            
            return
            "B777"
        }
        
        
        return nil
    }
    
    private static func detectMetadata(
        coverText: String
    ) -> (
        year: Int,
        season: FlightNormSeason,
        version: Int
    ) {
        let normalizedText =
        coverText.precomposedStringWithCanonicalMapping
        
        let lower = normalizedText.lowercased()
        
        let season: FlightNormSeason =
        lower.contains("зима")
        ? .winter
        : .summer
        
        var year = moscowCalendar.component(
            .year,
            from: Date()
        )
        
        if
            let match = regexMatches(
                pattern: #"\b20\d{2}\b"#,
                in: normalizedText
            ).first,
            let value = Int(match.text)
        {
            year = value
        }
        
        var version = 1
        
        let versionPatterns = [
            #"(?i)поправк[^0-9]*№?\s*(\d+)"#,
            #"(?i)верси[^0-9]*№?\s*(\d+)"#,
            #"№\s*(\d+)"#
        ]
        
        for pattern in versionPatterns {
            if let value = firstCapturedInteger(
                pattern: pattern,
                text: normalizedText
            ) {
                version = value
                break
            }
        }
        
        return (year, season, version)
    }
    
    private static func removeDuplicates(
        _ rows: [FlightNormDraftRow]
    ) -> [FlightNormDraftRow] {
        var seen: Set<String> = []
        var result: [FlightNormDraftRow] = []
        
        for row in rows {
            let key = [
                row.aircraftType,
                row.departureIATA,
                row.arrivalIATA,
                row.outboundTime,
                row.returnTime,
                row.routeName
            ]
                .joined(separator: "|")
            
            if seen.insert(key).inserted {
                result.append(row)
            }
        }
        
        return result
    }
}

// MARK: - Regex

private struct FlightNormRegexMatch {
    let text: String
    let range: NSRange
}

private func regexMatches(
    pattern: String,
    in text: String
) -> [FlightNormRegexMatch] {
    guard let regex = try? NSRegularExpression(
        pattern: pattern
    ) else {
        return []
    }
    
    let nsText = text as NSString
    
    let range = NSRange(
        location: 0,
        length: nsText.length
    )
    
    return regex
        .matches(
            in: text,
            range: range
        )
        .map {
            FlightNormRegexMatch(
                text: nsText.substring(with: $0.range),
                range: $0.range
            )
        }
}

private func firstCapturedInteger(
    pattern: String,
    text: String
) -> Int? {
    guard let regex = try? NSRegularExpression(
        pattern: pattern
    ) else {
        return nil
    }
    
    let nsText = text as NSString
    
    let wholeRange = NSRange(
        location: 0,
        length: nsText.length
    )
    
    guard
        let match = regex.firstMatch(
            in: text,
            range: wholeRange
        ),
        match.numberOfRanges > 1
    else {
        return nil
    }
    
    let value = nsText.substring(
        with: match.range(at: 1)
    )
    
    return Int(value)
}

// MARK: - Формат времени нормативов

func normalizedNormTime(_ value: String) -> String {
    value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: ".", with: ":")
        .replacingOccurrences(of: ",", with: ":")
}

func minutesFromNormTime(_ value: String) -> Int? {
    let normalized = normalizedNormTime(value)
    let parts = normalized.split(separator: ":")
    
    guard
        parts.count == 2,
        let hours = Int(parts[0]),
        let minutes = Int(parts[1]),
        hours >= 0,
        minutes >= 0,
        minutes < 60
    else {
        return nil
    }
    
    return hours * 60 + minutes
}

func normTimeText(_ minutes: Int) -> String {
    String(
        format: "%d:%02d",
        minutes / 60,
        minutes % 60
    )
}

func normalizedIATA(_ value: String) -> String {
    value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .uppercased()
}

func normalizedFlightNormNote(
    _ value: String
) -> String {
    let trimmed =
    value.trimmingCharacters(
        in: .whitespacesAndNewlines
    )
    
    guard !trimmed.isEmpty else {
        return ""
    }
    
    let nsValue = trimmed as NSString
    let wholeRange =
    NSRange(
        location: 0,
        length: nsValue.length
    )
    
    if let regex =
        try? NSRegularExpression(
            pattern: #"^4\.(?=\s|$)"#,
            options: []
        ),
       regex.firstMatch(
            in: trimmed,
            options: [],
            range: wholeRange
       ) != nil {
        return regex.stringByReplacingMatches(
            in: trimmed,
            options: [],
            range: wholeRange,
            withTemplate: "ч."
        )
    }
    
    return trimmed
}

private func cleanCellText(_ value: String) -> String {
    value
        .trimmingCharacters(
            in: CharacterSet(
                charactersIn: " |–—-\t\n"
            )
            .union(.whitespaces)
        )
}

// MARK: - Группа списка

struct FlightNormGroup: Identifiable {
    let year: Int
    let season: FlightNormSeason
    let versions: [FlightNormVersion]
    
    var id: String {
        "\(year)-\(season.rawValue)"
    }
}

// MARK: - Главный экран

struct FlightNormsView: View {
    @ObservedObject var store: FlightNormStore
    
    @State private var showImporter = false
    @State private var isImporting = false
    @State private var importedDraft: FlightNormImportDraft?
    @State private var importError: String?
    
    var groups: [FlightNormGroup] {
        let dictionary = Dictionary(
            grouping: store.versions
        ) {
            "\($0.year)|\($0.season.rawValue)"
        }
        
        return dictionary.values
            .compactMap { versions -> FlightNormGroup? in
                guard let first = versions.first else {
                    return nil
                }
                
                return FlightNormGroup(
                    year: first.year,
                    season: first.season,
                    versions: versions.sorted {
                        $0.versionNumber > $1.versionNumber
                    }
                )
            }
            .sorted {
                if $0.year != $1.year {
                    return $0.year > $1.year
                }
                
                return $0.season == .winter
            }
    }
    
    var body: some View {
        List {
            if store.versions.isEmpty {
                ContentUnavailableView(
                    "Нормативов пока нет",
                    systemImage: "tablecells",
                    description: Text(
                        "Импортируй PDF с таблицей расчётного времени."
                    )
                )
            } else {
                ForEach(groups) { group in
                    Section(
                        "\(group.season.rawValue) \(String(group.year))"
                    ) {
                        ForEach(group.versions) { version in
                            NavigationLink {
                                FlightNormVersionDetailView(
                                    version: version
                                )
                            } label: {
                                VStack(
                                    alignment: .leading,
                                    spacing: 4
                                ) {
                                    Text(
                                        "Версия \(version.versionNumber)"
                                    )
                                    .bold()
                                    
                                    Text(
                                        "\(version.rows.count) строк • \(version.sourceFileName)"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Расчётное время")
        .toolbar {
            Button {
                showImporter = true
            } label: {
                Label(
                    "Импорт PDF",
                    systemImage: "doc.badge.plus"
                )
            }
            .disabled(isImporting)
        }
        .overlay {
            if isImporting {
                ZStack {
                    Color.black
                        .opacity(0.18)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 14) {
                        ProgressView()
                        
                        Text("Распознаю PDF…")
                            .bold()
                        
                        Text(
                            "На большом документе это может занять некоторое время."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .background {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(.regularMaterial)
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    return
                }

                importPDF(url)

            case .failure(let error):
                importError = error.localizedDescription
            }
        }
        .sheet(
            item: $importedDraft
        ) { draft in
            FlightNormImportReviewView(
                initialDraft: draft
            ) { version in
                let wasAdded = store.add(version)
                importedDraft = nil
                
                if !wasAdded {
                    importError =
                    "\(version.season.rawValue) \(version.year), версия \(version.versionNumber) уже сохранена."
                }
            }
            .presentationSizing(.page)
        }
        .alert(
            "Ошибка импорта",
            isPresented: Binding(
                get: {
                    importError != nil
                },
                set: {
                    if !$0 {
                        importError = nil
                    }
                }
            )
        ) {
            Button("OK") {
                importError = nil
            }
        } message: {
            Text(importError ?? "")
        }
    }
    
    private func importPDF(_ url: URL) {
        isImporting = true
        
        let hasAccess =
        url.startAccessingSecurityScopedResource()
        
        Task {
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
                
                isImporting = false
            }
            
            do {
                var draft =
                try await FlightNormPDFImporter
                    .importPDF(url: url)
                
                if draft.versionNumber <= 0 {
                    draft.versionNumber =
                    store.nextVersion(
                        year: draft.year,
                        season: draft.season
                    )
                }
                
                importedDraft = draft
                
            } catch {
                importError =
                error.localizedDescription
            }
        }
    }
}

// MARK: - Проверка импорта

private struct FlightNormDraftRouteGroup: Identifiable {
    let id: String
    let routeName: String
    let departureIATA: String
    let arrivalIATA: String
    let rowIDs: [UUID]
}

struct FlightNormImportReviewView: View {
    @Environment(\.dismiss)
    private var dismiss
    
    @State private var draft:
    FlightNormImportDraft
    
    let onSave:
    (FlightNormVersion) -> Void
    
    private let aircraftOrder = [
        "A320/321",
        "B737",
        "A330",
        "A350",
        "B777"
    ]
    
    private var aircraftCounts: [String: Int] {
        Dictionary(
            grouping: draft.rows,
            by: { $0.aircraftType }
        )
        .mapValues { $0.count }
    }
    
    private var routeGroups: [FlightNormDraftRouteGroup] {
        let grouped = Dictionary(
            grouping: draft.rows
        ) { row in
            flightNormSavedRouteKey(
                departure: row.departureIATA,
                arrival: row.arrivalIATA
            )
        }
        
        return grouped.compactMap { key, rows in
            guard let first = rows.first else {
                return nil
            }
            
            return FlightNormDraftRouteGroup(
                id: key,
                routeName: flightNormBestDraftRouteName(rows),
                departureIATA: normalizedIATA(
                    first.departureIATA
                ),
                arrivalIATA: normalizedIATA(
                    first.arrivalIATA
                ),
                rowIDs: rows.map(\.id)
            )
        }
        .sorted(
            by: flightNormDraftRouteSort
        )
    }
    
    private func rowBinding(
        id: UUID
    ) -> Binding<FlightNormDraftRow>? {
        guard let index =
                draft.rows.firstIndex(
                    where: { $0.id == id }
                )
        else {
            return nil
        }
        
        return $draft.rows[index]
    }
    
    init(
        initialDraft: FlightNormImportDraft,
        onSave: @escaping (FlightNormVersion) -> Void
    ) {
        _draft =
        State(
            initialValue: initialDraft
        )
        
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Таблица") {
                    Picker(
                        "Сезон",
                        selection: $draft.season
                    ) {
                        ForEach(
                            FlightNormSeason.allCases
                        ) { season in
                            Text(season.rawValue)
                                .tag(season)
                        }
                    }
                    
                    AeroYearPickerRow(
                        "Год",
                        selection: $draft.year,
                        range: 2000...2100
                    )
                    
                    Stepper(
                        "Версия \(draft.versionNumber)",
                        value: $draft.versionNumber,
                        in: 1...999
                    )
                    
                    LabeledContent(
                        "Файл",
                        value: draft.sourceFileName
                    )
                    
                    LabeledContent(
                        "Страниц",
                        value: String(draft.pageCount)
                    )
                }
                
                Section("По типам ВС") {
                    ForEach(
                        aircraftOrder,
                        id: \.self
                    ) { aircraft in
                        LabeledContent(
                            aircraft,
                            value: String(
                                aircraftCounts[
                                    aircraft,
                                    default: 0
                                ]
                            )
                        )
                    }
                    
                    LabeledContent(
                        "Всего",
                        value: String(draft.rows.count)
                    )
                }
                
                if draft.invalidCount > 0 {
                    Section {
                        Label(
                            "Нужно проверить строк: \(draft.invalidCount)",
                            systemImage:
                                "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(.orange)
                    }
                }
                
                Section {
                    ForEach(routeGroups) { group in
                        FlightNormDraftRouteCard(
                            group: group,
                            draft: $draft,
                            rowBinding: rowBinding
                        )
                    }
                } header: {
                    Text(
                        "Распознано: \(draft.rows.count)"
                    )
                } footer: {
                    Text(
                        "Нажмите на тип ВС, чтобы проверить или исправить распознанную строку."
                    )
                }
            }
            .navigationTitle(
                "Проверка импорта"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {
                ToolbarItem(
                    placement: .cancellationAction
                ) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(
                    placement: .confirmationAction
                ) {
                    Button("Сохранить") {
                        guard let version =
                                draft.makeVersion()
                        else {
                            return
                        }
                        
                        onSave(version)
                        dismiss()
                    }
                    .disabled(
                        draft.rows.isEmpty
                        ||
                        draft.invalidCount > 0
                    )
                }
            }
        }
    }
}

private struct FlightNormDraftRouteCard: View {
    let group: FlightNormDraftRouteGroup
    @Binding var draft: FlightNormImportDraft
    let rowBinding:
    (UUID) -> Binding<FlightNormDraftRow>?
    
    private var rows: [FlightNormDraftRow] {
        draft.rows.filter {
            group.rowIDs.contains($0.id)
        }
    }
    
    private func row(
        aircraftType: String
    ) -> FlightNormDraftRow? {
        rows.first {
            $0.aircraftType == aircraftType
        }
    }
    
    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            HStack(
                spacing: flightNormDraftColumnSpacing
            ) {
                Text(
                    flightNormDisplayRouteName(
                        group.routeName
                    )
                )
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .frame(
                    width: flightNormDraftRouteColumnWidth,
                    alignment: .leading
                )
                
                ForEach(
                    flightNormSavedAircraftOrder,
                    id: \.self
                ) { aircraftType in
                    if let row =
                        row(
                            aircraftType:
                                aircraftType
                        ),
                       let binding =
                        rowBinding(row.id) {
                        NavigationLink {
                            FlightNormDraftRowEditView(
                                row: binding
                            )
                        } label: {
                            Text(aircraftType)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .allowsTightening(true)
                                .frame(
                                    maxWidth: .infinity
                                )
                                .foregroundStyle(
                                    !row.isValid
                                    ? .red
                                    : row.confidence < 0.80
                                    ? .orange
                                    : .primary
                                )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("")
                            .frame(
                                maxWidth: .infinity
                            )
                    }
                }
            }
            
            FlightNormDraftDirectionRow(
                title:
                    "\(group.departureIATA) → \(group.arrivalIATA)",
                from: group.departureIATA,
                to: group.arrivalIATA,
                rows: rows
            )
            
            FlightNormDraftDirectionRow(
                title:
                    "\(group.arrivalIATA) → \(group.departureIATA)",
                from: group.arrivalIATA,
                to: group.departureIATA,
                rows: rows
            )
            
            if rows.contains(
                where: {
                    !normalizedFlightNormNote(
                        $0.note
                    ).isEmpty
                }
            ) {
                FlightNormDraftNotesRow(
                    rows: rows
                )
            }
        }
        .padding(.vertical, 5)
    }
}


private struct FlightNormDraftDirectionRow: View {
    let title: String
    let from: String
    let to: String
    let rows: [FlightNormDraftRow]
    
    var body: some View {
        HStack(
            spacing: flightNormDraftColumnSpacing
        ) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(
                    width: flightNormDraftRouteColumnWidth,
                    alignment: .leading
                )
            
            ForEach(
                flightNormSavedAircraftOrder,
                id: \.self
            ) { aircraftType in
                Text(
                    flightNormDraftTime(
                        aircraftType: aircraftType,
                        rows: rows,
                        from: from,
                        to: to
                    )
                )
                .fontWeight(.medium)
                .monospacedDigit()
                .frame(
                    maxWidth: .infinity
                )
            }
        }
    }
}


private struct FlightNormDraftNotesRow: View {
    let rows: [FlightNormDraftRow]
    
    var body: some View {
        HStack(
            alignment: .top,
            spacing: flightNormDraftColumnSpacing
        ) {
            Text("Примечание")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(
                    width: flightNormDraftRouteColumnWidth,
                    alignment: .leading
                )
            
            ForEach(
                flightNormSavedAircraftOrder,
                id: \.self
            ) { aircraftType in
                Text(
                    normalizedFlightNormNote(
                        rows.first {
                            $0.aircraftType
                            == aircraftType
                        }?
                        .note
                        ?? ""
                    )
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .allowsTightening(true)
                .multilineTextAlignment(
                    .center
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: .center
                )
            }
        }
    }
}


private func flightNormDraftTime(
    aircraftType: String,
    rows: [FlightNormDraftRow],
    from: String,
    to: String
) -> String {
    guard let row =
            rows.first(
                where: {
                    $0.aircraftType
                    == aircraftType
                }
            )
    else {
        return ""
    }
    
    let departure =
    normalizedIATA(
        row.departureIATA
    )
    
    let arrival =
    normalizedIATA(
        row.arrivalIATA
    )
    
    if departure == from
        && arrival == to {
        return normalizedNormTime(
            row.outboundTime
        )
    }
    
    if arrival == from
        && departure == to {
        return normalizedNormTime(
            row.returnTime
        )
    }
    
    return ""
}


private func flightNormBestDraftRouteName(
    _ rows: [FlightNormDraftRow]
) -> String {
    rows
        .map {
            $0.routeName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        }
        .filter {
            !$0.isEmpty
        }
        .sorted {
            if $0.count != $1.count {
                return $0.count > $1.count
            }
            
            return $0.localizedStandardCompare(
                $1
            ) == .orderedAscending
        }
        .first
    ?? ""
}


private func flightNormDraftRouteSort(
    _ left: FlightNormDraftRouteGroup,
    _ right: FlightNormDraftRouteGroup
) -> Bool {
    let leftIsMoscow =
        left.departureIATA == "SVO"
        || left.arrivalIATA == "SVO"
        || left.routeName
            .localizedCaseInsensitiveContains(
                "Москва"
            )
    
    let rightIsMoscow =
        right.departureIATA == "SVO"
        || right.arrivalIATA == "SVO"
        || right.routeName
            .localizedCaseInsensitiveContains(
                "Москва"
            )
    
    if leftIsMoscow != rightIsMoscow {
        return leftIsMoscow
    }
    
    let leftKey =
        leftIsMoscow
        ? flightNormMoscowDestinationName(
            left.routeName
        )
        : left.routeName
    
    let rightKey =
        rightIsMoscow
        ? flightNormMoscowDestinationName(
            right.routeName
        )
        : right.routeName
    
    let comparison =
    leftKey.localizedStandardCompare(
        rightKey
    )
    
    if comparison != .orderedSame {
        return comparison
            == .orderedAscending
    }
    
    return left.routeName
        .localizedStandardCompare(
            right.routeName
        ) == .orderedAscending
}


// MARK: - Редактор строки

struct FlightNormDraftRowEditView: View {
    @Binding var row:
    FlightNormDraftRow
    
    var body: some View {
        Form {
            Section("Маршрут") {
                TextField(
                    "Название",
                    text: $row.routeName
                )
                
                TextField(
                    "Тип ВС",
                    text: $row.aircraftType
                )
                
                TextField(
                    "IATA вылета",
                    text: $row.departureIATA
                )
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                
                TextField(
                    "IATA прилёта",
                    text: $row.arrivalIATA
                )
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            }
            
            Section("Расчётное время") {
                TextField(
                    "Туда",
                    text: $row.outboundTime
                )
                
                TextField(
                    "Обратно",
                    text: $row.returnTime
                )
            }
            
            Section("Примечание") {
                TextField(
                    "Примечание",
                    text: $row.note,
                    axis: .vertical
                )
                .lineLimit(3...8)
            }
            
            Section {
                if row.isValid {
                    Label(
                        "Строка готова",
                        systemImage:
                            "checkmark.circle.fill"
                    )
                    .foregroundStyle(.green)
                } else {
                    Label(
                        "Проверь IATA и время",
                        systemImage:
                            "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Строка")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Просмотр сохранённой версии

private let flightNormSavedAircraftOrder = [
    "A320/321",
    "B737",
    "A330",
    "A350",
    "B777"
]

private let flightNormSavedRouteColumnWidth: CGFloat = 190
private let flightNormSavedColumnSpacing: CGFloat = 4

private let flightNormDraftRouteColumnWidth: CGFloat = 235
private let flightNormDraftColumnSpacing: CGFloat = 8

private struct FlightNormSavedRouteGroup: Identifiable {
    let id: String
    let routeName: String
    let departureIATA: String
    let arrivalIATA: String
    let rows: [FlightNormRow]
}

struct FlightNormVersionDetailView: View {
    let version: FlightNormVersion
    
    @State private var searchText = ""
    
    private var routeGroups: [FlightNormSavedRouteGroup] {
        let grouped = Dictionary(
            grouping: version.rows
        ) { row in
            flightNormSavedRouteKey(
                departure: row.departureIATA,
                arrival: row.arrivalIATA
            )
        }
        
        return grouped.compactMap { key, rows in
            guard let first = rows.first else {
                return nil
            }
            
            return FlightNormSavedRouteGroup(
                id: key,
                routeName: flightNormBestRouteName(rows),
                departureIATA: normalizedIATA(first.departureIATA),
                arrivalIATA: normalizedIATA(first.arrivalIATA),
                rows: rows.sorted(by: flightNormSavedAircraftSort)
            )
        }
        .sorted(
            by: flightNormSavedRouteSort
        )
    }
    
    private var filteredGroups: [FlightNormSavedRouteGroup] {
        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        
        guard !query.isEmpty else {
            return routeGroups
        }
        
        return routeGroups.filter { group in
            group.routeName.uppercased().contains(query)
            || group.departureIATA.contains(query)
            || group.arrivalIATA.contains(query)
            || group.rows.contains {
                $0.aircraftType.uppercased().contains(query)
            }
        }
    }
    
    var body: some View {
        List {
            Section("Источник") {
                LabeledContent(
                    "Период",
                    value: "\(version.season.rawValue) \(version.year)"
                )
                
                LabeledContent(
                    "Версия",
                    value: String(version.versionNumber)
                )
                
                LabeledContent(
                    "Файл",
                    value: version.sourceFileName
                )
                
                LabeledContent(
                    "Маршрутов",
                    value: String(routeGroups.count)
                )
                
                LabeledContent(
                    "Нормативов",
                    value: String(version.rows.count)
                )
            }
            
            Section("Маршруты") {
                ForEach(filteredGroups) { group in
                    FlightNormSavedRouteCard(group: group)
                }
            }
        }
        .navigationTitle("Версия \(version.versionNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            prompt: "Маршрут, IATA или тип ВС"
        )
    }
}

private struct FlightNormSavedRouteCard: View {
    let group: FlightNormSavedRouteGroup
    
    private var hasAnyNote: Bool {
        group.rows.contains {
            !$0.note
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty
        }
    }
    
    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            FlightNormAircraftColumnsHeader(
                routeName: group.routeName,
                rows: group.rows
            )
            
            FlightNormDirectionTimesRow(
                title: "\(group.departureIATA) → \(group.arrivalIATA)",
                from: group.departureIATA,
                to: group.arrivalIATA,
                rows: group.rows
            )
            
            FlightNormDirectionTimesRow(
                title: "\(group.arrivalIATA) → \(group.departureIATA)",
                from: group.arrivalIATA,
                to: group.departureIATA,
                rows: group.rows
            )
            
            if hasAnyNote {
                FlightNormAircraftNotesRow(
                    rows: group.rows
                )
            }
        }
        .padding(.vertical, 5)
    }
}

private struct FlightNormAircraftColumnsHeader: View {
    let routeName: String
    let rows: [FlightNormRow]
    
    var body: some View {
        HStack(
            spacing: flightNormSavedColumnSpacing
        ) {
            Text(
                flightNormDisplayRouteName(
                    routeName
                )
            )
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(
                    width: flightNormSavedRouteColumnWidth,
                    alignment: .leading
                )
            
            ForEach(
                flightNormSavedAircraftOrder,
                id: \.self
            ) { aircraftType in
                Text(
                    flightNormRow(
                        aircraftType: aircraftType,
                        rows: rows
                    ) == nil
                    ? ""
                    : aircraftType
                )
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct FlightNormDirectionTimesRow: View {
    let title: String
    let from: String
    let to: String
    let rows: [FlightNormRow]
    
    var body: some View {
        HStack(
            spacing: flightNormSavedColumnSpacing
        ) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(
                    width: flightNormSavedRouteColumnWidth,
                    alignment: .leading
                )
            
            ForEach(
                flightNormSavedAircraftOrder,
                id: \.self
            ) { aircraftType in
                Text(
                    flightNormTime(
                        aircraftType: aircraftType,
                        rows: rows,
                        from: from,
                        to: to
                    )
                )
                .fontWeight(.medium)
                .monospacedDigit()
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct FlightNormAircraftNotesRow: View {
    let rows: [FlightNormRow]
    
    var body: some View {
        HStack(
            alignment: .top,
            spacing: flightNormSavedColumnSpacing
        ) {
            Text("Примечание")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(
                    width: flightNormSavedRouteColumnWidth,
                    alignment: .leading
                )
            
            ForEach(
                flightNormSavedAircraftOrder,
                id: \.self
            ) { aircraftType in
                Text(
                    normalizedFlightNormNote(
                        flightNormRow(
                            aircraftType: aircraftType,
                            rows: rows
                        )?
                        .note
                        ?? ""
                    )
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: .center
                )
            }
        }
    }
}

private func flightNormRow(
    aircraftType: String,
    rows: [FlightNormRow]
) -> FlightNormRow? {
    rows.first {
        $0.aircraftType == aircraftType
    }
}

private func flightNormTime(
    aircraftType: String,
    rows: [FlightNormRow],
    from: String,
    to: String
) -> String {
    guard let row = flightNormRow(
        aircraftType: aircraftType,
        rows: rows
    ) else {
        return ""
    }
    
    return flightNormTime(
        row: row,
        from: from,
        to: to
    )
}

private func flightNormTime(
    row: FlightNormRow,
    from: String,
    to: String
) -> String {
    let departure = normalizedIATA(row.departureIATA)
    let arrival = normalizedIATA(row.arrivalIATA)
    
    if departure == from && arrival == to {
        return normTimeText(row.outboundMinutes)
    }
    
    if arrival == from && departure == to {
        return normTimeText(row.returnMinutes)
    }
    
    return ""
}

private func flightNormSavedRouteSort(
    _ left: FlightNormSavedRouteGroup,
    _ right: FlightNormSavedRouteGroup
) -> Bool {
    let leftIsMoscow =
        flightNormIsMoscowRoute(left)
    let rightIsMoscow =
        flightNormIsMoscowRoute(right)
    
    if leftIsMoscow != rightIsMoscow {
        return leftIsMoscow
    }
    
    let leftKey =
        leftIsMoscow
        ? flightNormMoscowDestinationName(
            left.routeName
        )
        : left.routeName
    
    let rightKey =
        rightIsMoscow
        ? flightNormMoscowDestinationName(
            right.routeName
        )
        : right.routeName
    
    let comparison =
    leftKey.localizedStandardCompare(
        rightKey
    )
    
    if comparison != .orderedSame {
        return comparison == .orderedAscending
    }
    
    return left.routeName.localizedStandardCompare(
        right.routeName
    ) == .orderedAscending
}

private func flightNormIsMoscowRoute(
    _ group: FlightNormSavedRouteGroup
) -> Bool {
    if group.departureIATA == "SVO"
        || group.arrivalIATA == "SVO" {
        return true
    }
    
    return group.routeName
        .localizedCaseInsensitiveContains(
            "Москва"
        )
}

private func flightNormDisplayRouteName(
    _ routeName: String
) -> String {
    let trimmed =
    routeName.trimmingCharacters(
        in: .whitespacesAndNewlines
    )
    
    guard !trimmed.isEmpty else {
        return trimmed
    }
    
    // Основной разделитель между аэропортами/городами в PDF
    // обычно окружён пробелами. Внутренние дефисы в названиях
    // вроде Шарм-эль-Шейх при этом сохраняются.
    if let regex =
        try? NSRegularExpression(
            pattern: #"\s+[\-–—]\s+"#,
            options: []
        ) {
        let nsTrimmed = trimmed as NSString
        let wholeRange =
        NSRange(
            location: 0,
            length: nsTrimmed.length
        )
        
        if let match =
            regex.firstMatch(
                in: trimmed,
                options: [],
                range: wholeRange
            ) {
            let mutable =
            NSMutableString(
                string: trimmed
            )
            
            mutable.replaceCharacters(
                in: match.range,
                with: " ↔ "
            )
            
            return mutable as String
        }
    }
    
    // Для московских маршрутов OCR иногда убирает пробелы вокруг
    // разделителя: Москва-Шарм-эль-Шейх.
    let moscowPrefixes = [
        "Москва-",
        "Москва–",
        "Москва—"
    ]
    
    for prefix in moscowPrefixes {
        if trimmed.hasPrefix(prefix) {
            let destination =
            String(
                trimmed.dropFirst(
                    prefix.count
                )
            )
            
            return "Москва ↔ \(destination)"
        }
    }
    
    return trimmed
}

private func flightNormMoscowDestinationName(
    _ routeName: String
) -> String {
    let displayName =
    flightNormDisplayRouteName(
        routeName
    )
    
    let parts =
    displayName
        .components(
            separatedBy: "↔"
        )
        .map {
            $0.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        }
        .filter {
            !$0.isEmpty
        }
    
    if let destination =
        parts.first(
            where: {
                !$0.localizedCaseInsensitiveContains(
                    "Москва"
                )
            }
        ) {
        return destination
    }
    
    return routeName
}

private func flightNormSavedAircraftSort(
    _ left: FlightNormRow,
    _ right: FlightNormRow
) -> Bool {
    let leftIndex = flightNormSavedAircraftOrder.firstIndex(
        of: left.aircraftType
    ) ?? 999
    
    let rightIndex = flightNormSavedAircraftOrder.firstIndex(
        of: right.aircraftType
    ) ?? 999
    
    if leftIndex != rightIndex {
        return leftIndex < rightIndex
    }
    
    return left.aircraftType < right.aircraftType
}

private func flightNormSavedRouteKey(
    departure: String,
    arrival: String
) -> String {
    let first = normalizedIATA(departure)
    let second = normalizedIATA(arrival)
    
    if first <= second {
        return "\(first)|\(second)"
    }
    
    return "\(second)|\(first)"
}

private func flightNormBestRouteName(
    _ rows: [FlightNormRow]
) -> String {
    let names = rows
        .map {
            $0.routeName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        }
        .filter { !$0.isEmpty }
    
    return names.min {
        $0.count < $1.count
    } ?? ""
}

