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
    var confidence: Float?
    
    init(
        id: UUID = UUID(),
        aircraftType: String,
        routeName: String,
        departureIATA: String,
        arrivalIATA: String,
        outboundMinutes: Int,
        returnMinutes: Int,
        note: String,
        confidence: Float? = nil
    ) {
        self.id = id
        self.aircraftType = aircraftType
        self.routeName = routeName
        self.departureIATA = departureIATA
        self.arrivalIATA = arrivalIATA
        self.outboundMinutes = outboundMinutes
        self.returnMinutes = returnMinutes
        self.note = note
        self.confidence = confidence
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
    
    func deleteRow(
        versionID: UUID,
        rowID: UUID
    ) {
        guard let versionIndex =
                versions.firstIndex(
                    where: { $0.id == versionID }
                )
        else {
            return
        }
        
        versions[versionIndex].rows
            .removeAll { $0.id == rowID }
    }
    
    func updateTime(
        versionID: UUID,
        rowID: UUID,
        from: String,
        to: String,
        minutes: Int
    ) {
        guard
            let versionIndex =
                versions.firstIndex(
                    where: { $0.id == versionID }
                ),
            let rowIndex =
                versions[versionIndex].rows
                .firstIndex(
                    where: { $0.id == rowID }
                )
        else {
            return
        }
        
        let departure =
        normalizedIATA(
            versions[versionIndex]
                .rows[rowIndex]
                .departureIATA
        )
        
        let arrival =
        normalizedIATA(
            versions[versionIndex]
                .rows[rowIndex]
                .arrivalIATA
        )
        
        if departure == from
            && arrival == to {
            versions[versionIndex]
                .rows[rowIndex]
                .outboundMinutes = minutes
        } else if arrival == from
            && departure == to {
            versions[versionIndex]
                .rows[rowIndex]
                .returnMinutes = minutes
        }
        
        versions[versionIndex]
            .rows[rowIndex]
            .confidence = 1.0
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
                ),
                confidence: row.confidence
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
    case wrongDocument
    case noRows
    
    var errorDescription: String? {
        switch self {
        case .cannotOpenPDF:
            return "Не удалось открыть PDF."
        case .noPages:
            return "В PDF нет страниц."
        case .wrongDocument:
            return "Выбранный PDF не похож на таблицу расчётного полётного времени."
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
        
        guard
            looksLikeFlightNormDocument(
                coverText: coverText,
                fileName: url.lastPathComponent,
                rows: allRows
            )
        else {
            throw FlightNormImportError.wrongDocument
        }
        
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
    
    private static func looksLikeFlightNormDocument(
        coverText: String,
        fileName: String,
        rows: [FlightNormDraftRow]
    ) -> Bool {
        let text =
        (coverText + "\n" + fileName)
            .precomposedStringWithCanonicalMapping
            .lowercased()
            .replacingOccurrences(
                of: "ё",
                with: "е"
            )
        
        let hasTitle =
        text.contains("полетн")
        && text.contains("врем")
        
        let knownAircraft =
        Set(
            rows.map { $0.aircraftType }
        )
        
        let hasKnownAircraft =
        !knownAircraft.isDisjoint(
            with: Set([
                "A320/321",
                "B737",
                "A330",
                "A350",
                "B777"
            ])
        )
        
        return hasTitle && hasKnownAircraft
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
                                    store: store,
                                    versionID: version.id
                                )
                            } label: {
                                VStack(
                                    alignment: .leading,
                                    spacing: 4
                                ) {
                                    HStack {
                                        Text(
                                            "Версия \(version.versionNumber)"
                                        )
                                        .bold()
                                        
                                        Spacer()
                                        
                                        if version.rows.contains(
                                            where: {
                                                flightNormIsLowConfidence(
                                                    $0
                                                )
                                            }
                                        ) {
                                            Image(
                                                systemName:
                                                    "exclamationmark.triangle.fill"
                                            )
                                            .foregroundStyle(.orange)
                                        }
                                    }
                                    
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
                let draft =
                try await FlightNormPDFImporter
                    .importPDF(url: url)
                
                guard
                    draft.invalidCount == 0,
                    let version =
                        draft.makeVersion()
                else {
                    importError =
                    "PDF распознан не полностью. Версия не сохранена."
                    return
                }
                
                guard store.add(version) else {
                    importError =
                    "\(version.season.rawValue) \(version.year), версия \(version.versionNumber) уже сохранена."
                    return
                }
                
            } catch {
                importError =
                error.localizedDescription
            }
        }
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

private struct FlightNormSavedRouteGroup: Identifiable {
    let id: String
    let routeName: String
    let departureIATA: String
    let arrivalIATA: String
    let rows: [FlightNormRow]
}

struct FlightNormVersionDetailView: View {
    @Environment(\.dismiss)
    private var dismiss
    
    @ObservedObject var store: FlightNormStore
    let versionID: UUID
    
    @State private var searchText = ""
    @State private var isEditing = false
    @State private var showDeleteVersion = false
    
    private var version: FlightNormVersion? {
        store.versions.first {
            $0.id == versionID
        }
    }
    
    private var routeGroups: [FlightNormSavedRouteGroup] {
        guard let version else {
            return []
        }
        
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
                departureIATA: normalizedIATA(
                    first.departureIATA
                ),
                arrivalIATA: normalizedIATA(
                    first.arrivalIATA
                ),
                rows: rows.sorted(
                    by: flightNormSavedAircraftSort
                )
            )
        }
        .sorted(
            by: flightNormSavedRouteSort
        )
    }
    
    private var filteredGroups: [FlightNormSavedRouteGroup] {
        let query = searchText
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .uppercased()
        
        guard !query.isEmpty else {
            return routeGroups
        }
        
        return routeGroups.filter { group in
            group.routeName
                .uppercased()
                .contains(query)
            || group.departureIATA.contains(query)
            || group.arrivalIATA.contains(query)
            || group.rows.contains {
                $0.aircraftType
                    .uppercased()
                    .contains(query)
            }
        }
    }
    
    private var lowConfidenceCount: Int {
        version?
            .rows
            .filter {
                flightNormIsLowConfidence($0)
            }
            .count
        ?? 0
    }
    
    var body: some View {
        Group {
            if let version {
                List {
                    Section("Источник") {
                        LabeledContent(
                            "Период",
                            value:
                                "\(version.season.rawValue) \(version.year)"
                        )
                        
                        LabeledContent(
                            "Версия",
                            value:
                                String(
                                    version.versionNumber
                                )
                        )
                        
                        LabeledContent(
                            "Файл",
                            value:
                                version.sourceFileName
                        )
                        
                        LabeledContent(
                            "Маршрутов",
                            value:
                                String(
                                    routeGroups.count
                                )
                        )
                        
                        LabeledContent(
                            "Нормативов",
                            value:
                                String(
                                    version.rows.count
                                )
                        )
                    }
                    
                    if lowConfidenceCount > 0
                        && !isEditing {
                        Section {
                            Button {
                                isEditing = true
                            } label: {
                                Label(
                                    "Проверить распознавание: \(lowConfidenceCount)",
                                    systemImage:
                                        "exclamationmark.triangle.fill"
                                )
                                .foregroundStyle(.orange)
                            }
                        }
                    }
                    
                    Section("Маршруты") {
                        ForEach(
                            filteredGroups
                        ) { group in
                            FlightNormSavedRouteCard(
                                group: group,
                                isEditing:
                                    isEditing,
                                onWarningTap: {
                                    isEditing = true
                                },
                                timeBinding: {
                                    rowID,
                                    from,
                                    to in
                                    
                                    timeBinding(
                                        rowID: rowID,
                                        from: from,
                                        to: to
                                    )
                                },
                                onDeleteRow: {
                                    rowID in
                                    
                                    store.deleteRow(
                                        versionID:
                                            versionID,
                                        rowID:
                                            rowID
                                    )
                                }
                            )
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Версия удалена",
                    systemImage: "trash"
                )
            }
        }
        .navigationTitle(
            version.map {
                "Версия \($0.versionNumber)"
            }
            ?? "Расчётное время"
        )
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            prompt: "Маршрут, IATA или тип ВС"
        )
        .toolbar {
            ToolbarItem(
                placement: .topBarTrailing
            ) {
                Button(
                    isEditing
                    ? "Готово"
                    : "Редактировать"
                ) {
                    isEditing.toggle()
                }
                .disabled(version == nil)
            }
            
            ToolbarItem(
                placement: .topBarTrailing
            ) {
                Button(
                    role: .destructive
                ) {
                    showDeleteVersion = true
                } label: {
                    Image(
                        systemName: "trash"
                    )
                }
                .disabled(version == nil)
            }
        }
        .alert(
            "Удалить версию?",
            isPresented:
                $showDeleteVersion
        ) {
            Button(
                "Удалить",
                role: .destructive
            ) {
                store.delete(
                    id: versionID
                )
                dismiss()
            }
            
            Button(
                "Отмена",
                role: .cancel
            ) {}
        } message: {
            if let version {
                Text(
                    "\(version.season.rawValue) \(version.year), версия \(version.versionNumber) будет удалена полностью."
                )
            }
        }
    }
    
    private func timeBinding(
        rowID: UUID,
        from: String,
        to: String
    ) -> Binding<Int> {
        Binding(
            get: {
                guard
                    let version =
                        store.versions.first(
                            where: {
                                $0.id
                                == versionID
                            }
                        ),
                    let row =
                        version.rows.first(
                            where: {
                                $0.id
                                == rowID
                            }
                        )
                else {
                    return 0
                }
                
                return flightNormMinutes(
                    row: row,
                    from: from,
                    to: to
                )
                ?? 0
            },
            set: { minutes in
                store.updateTime(
                    versionID:
                        versionID,
                    rowID:
                        rowID,
                    from:
                        from,
                    to:
                        to,
                    minutes:
                        minutes
                )
            }
        )
    }
}


private struct FlightNormSavedRouteCard: View {
    let group: FlightNormSavedRouteGroup
    let isEditing: Bool
    let onWarningTap: () -> Void
    let timeBinding:
    (UUID, String, String) -> Binding<Int>
    let onDeleteRow: (UUID) -> Void
    
    private var hasAnyNote: Bool {
        group.rows.contains {
            !$0.note
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty
        }
    }
    
    private var hasLowConfidence: Bool {
        group.rows.contains {
            flightNormIsLowConfidence($0)
        }
    }
    
    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            FlightNormAircraftColumnsHeader(
                routeName: group.routeName,
                rows: group.rows,
                isEditing: isEditing,
                hasLowConfidence:
                    hasLowConfidence,
                onWarningTap:
                    onWarningTap,
                onDeleteRow:
                    onDeleteRow
            )
            
            FlightNormDirectionTimesRow(
                title:
                    "\(group.departureIATA) → \(group.arrivalIATA)",
                from:
                    group.departureIATA,
                to:
                    group.arrivalIATA,
                rows:
                    group.rows,
                isEditing:
                    isEditing,
                timeBinding:
                    timeBinding
            )
            
            FlightNormDirectionTimesRow(
                title:
                    "\(group.arrivalIATA) → \(group.departureIATA)",
                from:
                    group.arrivalIATA,
                to:
                    group.departureIATA,
                rows:
                    group.rows,
                isEditing:
                    isEditing,
                timeBinding:
                    timeBinding
            )
            
            if hasAnyNote {
                FlightNormAircraftNotesRow(
                    rows: group.rows,
                    isEditing:
                        isEditing
                )
            }
        }
        .padding(.vertical, 5)
    }
}


private struct FlightNormAircraftColumnsHeader: View {
    let routeName: String
    let rows: [FlightNormRow]
    let isEditing: Bool
    let hasLowConfidence: Bool
    let onWarningTap: () -> Void
    let onDeleteRow: (UUID) -> Void
    
    var body: some View {
        HStack(
            alignment: .top,
            spacing:
                flightNormSavedColumnSpacing
        ) {
            HStack(spacing: 5) {
                Text(
                    flightNormDisplayRouteName(
                        routeName
                    )
                )
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(
                    isEditing
                    && hasLowConfidence
                    ? .orange
                    : .primary
                )
                
                if hasLowConfidence
                    && !isEditing {
                    Button {
                        onWarningTap()
                    } label: {
                        Image(
                            systemName:
                                "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(
                width:
                    flightNormSavedRouteColumnWidth,
                alignment: .leading
            )
            
            ForEach(
                flightNormSavedAircraftOrder,
                id: \.self
            ) { aircraftType in
                if let row =
                    flightNormRow(
                        aircraftType:
                            aircraftType,
                        rows:
                            rows
                    ) {
                    VStack(spacing: 4) {
                        Text(aircraftType)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(
                                isEditing
                                && flightNormIsLowConfidence(
                                    row
                                )
                                ? .orange
                                : .primary
                            )
                        
                        if isEditing {
                            Button(
                                role: .destructive
                            ) {
                                onDeleteRow(
                                    row.id
                                )
                            } label: {
                                Image(
                                    systemName:
                                        "trash"
                                )
                                .font(.caption2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(
                        maxWidth: .infinity
                    )
                } else {
                    Text("")
                        .frame(
                            maxWidth: .infinity
                        )
                }
            }
        }
    }
}


private struct FlightNormDirectionTimesRow: View {
    let title: String
    let from: String
    let to: String
    let rows: [FlightNormRow]
    let isEditing: Bool
    let timeBinding:
    (UUID, String, String) -> Binding<Int>
    
    var body: some View {
        HStack(
            spacing:
                flightNormSavedColumnSpacing
        ) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(
                    width:
                        flightNormSavedRouteColumnWidth,
                    alignment: .leading
                )
            
            ForEach(
                flightNormSavedAircraftOrder,
                id: \.self
            ) { aircraftType in
                if let row =
                    flightNormRow(
                        aircraftType:
                            aircraftType,
                        rows:
                            rows
                    ) {
                    if isEditing {
                        AeroMinutesPickerButton(
                            minutes:
                                timeBinding(
                                    row.id,
                                    from,
                                    to
                                ),
                            isHighlighted:
                                flightNormIsLowConfidence(
                                    row
                                )
                        )
                    } else {
                        Text(
                            flightNormTime(
                                row: row,
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
                } else {
                    Text("")
                        .frame(
                            maxWidth: .infinity
                        )
                }
            }
        }
    }
}


private struct FlightNormAircraftNotesRow: View {
    let rows: [FlightNormRow]
    let isEditing: Bool
    
    var body: some View {
        HStack(
            alignment: .top,
            spacing:
                flightNormSavedColumnSpacing
        ) {
            Text("Примечание")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(
                    width:
                        flightNormSavedRouteColumnWidth,
                    alignment: .leading
                )
            
            ForEach(
                flightNormSavedAircraftOrder,
                id: \.self
            ) { aircraftType in
                let row =
                flightNormRow(
                    aircraftType:
                        aircraftType,
                    rows:
                        rows
                )
                
                Text(
                    normalizedFlightNormNote(
                        row?.note
                        ?? ""
                    )
                )
                .font(.caption2)
                .foregroundStyle(
                    isEditing
                    && row.map(
                        flightNormIsLowConfidence
                    ) == true
                    ? .orange
                    : .secondary
                )
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


private func flightNormIsLowConfidence(
    _ row: FlightNormRow
) -> Bool {
    guard let confidence =
            row.confidence
    else {
        return false
    }
    
    return confidence < 0.80
}

private func flightNormMinutes(
    row: FlightNormRow,
    from: String,
    to: String
) -> Int? {
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
        return row.outboundMinutes
    }
    
    if arrival == from
        && departure == to {
        return row.returnMinutes
    }
    
    return nil
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

