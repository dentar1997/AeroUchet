import Foundation
import PDFKit
import UIKit


struct AssignmentV119LegMetadata: Codable, Equatable {
    var flightNumber: String
    var departure: String?
    var arrival: String?
    var aircraft: String?
}


struct AssignmentV119Metadata: Codable, Equatable {
    var schemaVersion: Int = 1
    var sourceStart: Date?
    var sourceEnd: Date?
    var passengerBasis: String?
    var passengerMovementMinutes: Int?
    var linkedGroupID: String?
    var waitingMinutes: Int?
    var subsequentDutyReductionMinutes: Int?
    var linkedSequenceMinutes: Int?
    var legs: [AssignmentV119LegMetadata] = []
}


enum AssignmentV119MetadataCodec {
    private static let prefix = "[[AU119:"
    private static let suffix = "]]"

    static func metadata(from detail: String?) -> AssignmentV119Metadata? {
        guard let detail,
              let prefixRange = detail.range(of: prefix),
              let suffixRange = detail.range(
                of: suffix,
                range: prefixRange.upperBound..<detail.endIndex
              ) else {
            return nil
        }

        let encoded = String(detail[prefixRange.upperBound..<suffixRange.lowerBound])
        guard let data = Data(base64Encoded: encoded) else { return nil }
        return try? JSONDecoder().decode(AssignmentV119Metadata.self, from: data)
    }

    static func humanDetail(_ detail: String?) -> String? {
        guard let detail else { return nil }
        guard let prefixRange = detail.range(of: prefix),
              let suffixRange = detail.range(
                of: suffix,
                range: prefixRange.upperBound..<detail.endIndex
              ) else {
            let value = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }

        var value = detail
        value.removeSubrange(prefixRange.lowerBound..<suffixRange.upperBound)
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    static func encode(
        humanDetail: String?,
        metadata: AssignmentV119Metadata
    ) -> String? {
        guard let data = try? JSONEncoder().encode(metadata) else {
            return humanDetail
        }
        let token = prefix + data.base64EncodedString() + suffix
        let human = humanDetail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return human.isEmpty ? token : human + "\n" + token
    }

    static func replacingMetadata(
        in detail: String?,
        with metadata: AssignmentV119Metadata
    ) -> String? {
        encode(humanDetail: humanDetail(detail), metadata: metadata)
    }
}


private enum PerspectivePlanV119ParserError: LocalizedError {
    case unexpectedFormat

    var errorDescription: String? {
        switch self {
        case .unexpectedFormat:
            return "Формат перспективного плана изменился или документ распознан не полностью. Импорт отменён, чтобы не потерять назначения."
        }
    }
}


enum PerspectivePlanV119Parser {
    static func parseFile(url: URL) throws -> AssignmentPlanSnapshot {
        guard url.pathExtension.lowercased() == "pdf" else {
            return try AssignmentPlanImporter.parseFile(url: url)
        }
        guard let document = PDFDocument(url: url) else {
            throw AssignmentPlanImportError.unreadableFile
        }

        let headerText = (document.page(at: 0)?.string ?? "")
            .components(separatedBy: .newlines)
            .prefix(10)
            .joined(separator: " ")
        guard headerText.localizedCaseInsensitiveContains("перспективный план") else {
            return try AssignmentPlanImporter.parseFile(url: url)
        }
        guard let year = firstYear(in: headerText),
              let scopeMonthKey = scopeMonthKey(in: headerText, year: year) else {
            throw PerspectivePlanV119ParserError.unexpectedFormat
        }

        var rawItems: [AssignmentPlanItem] = []
        var inheritedDate: Date?
        var parsedAssignmentRows = 0

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else {
                throw PerspectivePlanV119ParserError.unexpectedFormat
            }
            let rows = geometryRows(page: page)
            guard !rows.isEmpty else {
                throw PerspectivePlanV119ParserError.unexpectedFormat
            }

            for (rowIndex, row) in rows.enumerated() {
                let dateText = text(
                    page: page,
                    topRect: CGRect(
                        x: row.tableLeft,
                        y: row.top,
                        width: row.dateRight - row.tableLeft,
                        height: row.bottom - row.top
                    )
                )
                let timeText = text(
                    page: page,
                    topRect: CGRect(
                        x: row.dateRight,
                        y: row.top,
                        width: row.contentLeft - row.dateRight,
                        height: row.bottom - row.top
                    )
                )
                let contentText = text(
                    page: page,
                    topRect: CGRect(
                        x: row.contentLeft,
                        y: row.top,
                        width: row.tableRight - row.contentLeft,
                        height: row.bottom - row.top
                    )
                )

                let combinedText = dateText + " " + timeText + " " + contentText
                if combinedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continue
                }
                if isHeaderRow(combinedText) {
                    continue
                }

                let dates = dates(in: dateText, year: year)
                let baseDate = dates.first ?? inheritedDate
                if let first = dates.first {
                    inheritedDate = first
                }

                guard let baseDate else {
                    throw PerspectivePlanV119ParserError.unexpectedFormat
                }

                let rowID = "p119|\(pageIndex)|\(rowIndex)|\(dayKey(baseDate))"
                if dates.count >= 2 {
                    guard let item = makeRangeItem(
                        start: dates[0],
                        rawEnd: dates[1],
                        content: contentText,
                        id: rowID,
                        scopeMonthKey: scopeMonthKey
                    ) else {
                        throw PerspectivePlanV119ParserError.unexpectedFormat
                    }
                    rawItems.append(item)
                    parsedAssignmentRows += 1
                    continue
                }

                let times = exactTimes(in: timeText)
                let mergedTimes = times.count >= 2
                    ? times
                    : exactTimes(in: dateText + " " + timeText)
                guard mergedTimes.count >= 2 else {
                    throw PerspectivePlanV119ParserError.unexpectedFormat
                }

                let items = makeTimedItems(
                    date: baseDate,
                    startClock: mergedTimes[0],
                    endClock: mergedTimes[1],
                    content: contentText,
                    id: rowID,
                    scopeMonthKey: scopeMonthKey
                )
                guard !items.isEmpty else {
                    throw PerspectivePlanV119ParserError.unexpectedFormat
                }
                rawItems.append(contentsOf: items)
                parsedAssignmentRows += 1
            }
        }

        guard parsedAssignmentRows > 0, !rawItems.isEmpty else {
            throw PerspectivePlanV119ParserError.unexpectedFormat
        }

        let linked = linkPassengerAndWorkingEvents(rawItems.sorted { $0.start < $1.start })
        return AssignmentPlanSnapshot(
            items: linked,
            generatedAt: nil,
            scopeMonthKey: scopeMonthKey
        )
    }

    // MARK: - Geometry

    private struct GeometryRow {
        var top: CGFloat
        var bottom: CGFloat
        var tableLeft: CGFloat
        var dateRight: CGFloat
        var contentLeft: CGFloat
        var tableRight: CGFloat
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

    // MARK: - Row parsing

    private static func makeRangeItem(
        start: Date,
        rawEnd: Date,
        content: String,
        id: String,
        scopeMonthKey: Int?
    ) -> AssignmentPlanItem? {
        var end = rawEnd
        if end <= start {
            end = moscowCalendar.date(byAdding: .year, value: 1, to: end) ?? end
        }
        guard end > start else { return nil }

        let labels = eventLabels(content)
        guard !labels.title.isEmpty else { return nil }
        return makeItem(
            id: id + "|range",
            kind: classify(labels.title + " " + (labels.detail ?? "")),
            start: start,
            end: end,
            title: labels.title,
            detail: labels.detail,
            isAllDayRange: true,
            originMonthKey: scopeMonthKey
        )
    }

    private static func makeTimedItems(
        date: Date,
        startClock: String,
        endClock: String,
        content: String,
        id: String,
        scopeMonthKey: Int?
    ) -> [AssignmentPlanItem] {
        guard let sourceStart = dateWithTime(startClock, date: date),
              var sourceEnd = dateWithTime(endClock, date: date) else {
            return []
        }
        if sourceEnd <= sourceStart {
            sourceEnd = moscowCalendar.date(byAdding: .day, value: 1, to: sourceEnd) ?? sourceEnd
        }

        let numbers = flightNumbers(in: content)
        guard !numbers.isEmpty else {
            let labels = eventLabels(content)
            guard !labels.title.isEmpty else { return [] }
            let kind = classify(labels.title + " " + (labels.detail ?? ""))
            let aircraft: String? = kind == .simulator
                ? normalizedAircraft(aircraftTypes(in: content).first)
                : nil
            return [makeItem(
                id: id + "|ground",
                kind: kind,
                start: sourceStart,
                end: sourceEnd,
                title: labels.title,
                aircraft: aircraft,
                detail: labels.detail,
                isAllDayRange: false,
                originMonthKey: scopeMonthKey
            )]
        }

        let route = routeLine(in: content)
        let routeNodes = route.flatMap { splitRoute($0, expectedLegCount: numbers.count) }
        let aircraftValues = aircraftTypes(in: content)
        let defaultAircraft = aircraftValues.first
        let passengerSet = passengerFlightNumbers(in: content)
        let allPassenger = !passengerSet.isEmpty
            && numbers.allSatisfy { passengerSet.contains(normalizedFlight($0)) }
        let allWorking = passengerSet.isEmpty
        let plannedMinutes = plannedFlightMinutes(in: content)

        if allPassenger {
            return [makePassengerItem(
                sourceStart: sourceStart,
                sourceEnd: sourceEnd,
                numbers: numbers,
                route: route,
                routeNodes: routeNodes,
                aircraftValues: aircraftValues,
                defaultAircraft: defaultAircraft,
                content: content,
                id: id + "|passenger",
                scopeMonthKey: scopeMonthKey
            )]
        }

        if allWorking {
            return [makeWorkingItem(
                sourceStart: sourceStart,
                sourceEnd: sourceEnd,
                numbers: numbers,
                route: route,
                routeNodes: routeNodes,
                aircraftValues: aircraftValues,
                defaultAircraft: defaultAircraft,
                plannedMinutes: plannedMinutes,
                id: id + "|flight",
                scopeMonthKey: scopeMonthKey
            )]
        }

        let passengerNumbers = numbers.filter { passengerSet.contains(normalizedFlight($0)) }
        let workingNumbers = numbers.filter { !passengerSet.contains(normalizedFlight($0)) }
        var result: [AssignmentPlanItem] = []

        if !passengerNumbers.isEmpty {
            result.append(makePassengerItem(
                sourceStart: sourceStart,
                sourceEnd: sourceEnd,
                numbers: passengerNumbers,
                route: route,
                routeNodes: nil,
                aircraftValues: aircraftValues,
                defaultAircraft: defaultAircraft,
                content: content,
                id: id + "|passenger",
                scopeMonthKey: scopeMonthKey
            ))
        }
        if !workingNumbers.isEmpty {
            result.append(makeWorkingItem(
                sourceStart: sourceStart,
                sourceEnd: sourceEnd,
                numbers: workingNumbers,
                route: route,
                routeNodes: nil,
                aircraftValues: aircraftValues,
                defaultAircraft: defaultAircraft,
                plannedMinutes: plannedMinutes,
                id: id + "|flight",
                scopeMonthKey: scopeMonthKey
            ))
        }
        return result
    }

    private static func makeWorkingItem(
        sourceStart: Date,
        sourceEnd: Date,
        numbers: [String],
        route: String?,
        routeNodes: [String]?,
        aircraftValues: [String],
        defaultAircraft: String?,
        plannedMinutes: Int?,
        id: String,
        scopeMonthKey: Int?
    ) -> AssignmentPlanItem {
        let dutyStart = moscowCalendar.date(byAdding: .minute, value: -60, to: sourceStart)
            ?? sourceStart
        let dutyEnd = moscowCalendar.date(byAdding: .minute, value: 30, to: sourceEnd)
            ?? sourceEnd
        let legs = numbers.enumerated().map { index, number in
            AssignmentPlanLeg(
                id: id + "|leg|\(index)",
                flightNumber: normalizedDisplayFlight(number),
                role: .workingPilot,
                departure: routeNodes?[safe: index].map(expandAirport),
                arrival: routeNodes?[safe: index + 1].map(expandAirport)
            )
        }
        let metaLegs = legs.enumerated().map { index, leg in
            AssignmentV119LegMetadata(
                flightNumber: leg.flightNumber,
                departure: leg.departure,
                arrival: leg.arrival,
                aircraft: normalizedAircraft(aircraftValues[safe: index] ?? defaultAircraft)
            )
        }
        let metadata = AssignmentV119Metadata(
            sourceStart: sourceStart,
            sourceEnd: sourceEnd,
            passengerBasis: nil,
            passengerMovementMinutes: nil,
            linkedGroupID: nil,
            waitingMinutes: nil,
            subsequentDutyReductionMinutes: nil,
            linkedSequenceMinutes: nil,
            legs: metaLegs
        )

        return makeItem(
            id: id,
            kind: .flight,
            start: dutyStart,
            end: dutyEnd,
            title: "Полётная смена",
            flightNumber: numbers.first.map(normalizedDisplayFlight),
            flightNumbers: numbers.map(normalizedDisplayFlight),
            departure: routeNodes?.first.map(expandAirport),
            arrival: routeNodes?.last.map(expandAirport),
            aircraft: normalizedAircraft(defaultAircraft),
            assignmentGroup: route.map(expandRoute),
            detail: AssignmentV119MetadataCodec.encode(
                humanDetail: nil,
                metadata: metadata
            ),
            flightLegs: legs,
            plannedFlightMinutes: plannedMinutes,
            isAllDayRange: false,
            originMonthKey: scopeMonthKey
        )
    }

    private static func makePassengerItem(
        sourceStart: Date,
        sourceEnd: Date,
        numbers: [String],
        route: String?,
        routeNodes: [String]?,
        aircraftValues: [String],
        defaultAircraft: String?,
        content: String,
        id: String,
        scopeMonthKey: Int?
    ) -> AssignmentPlanItem {
        let movementStart = moscowCalendar.date(byAdding: .minute, value: -40, to: sourceStart)
            ?? sourceStart
        let movementMinutes = max(0, Int(sourceEnd.timeIntervalSince(movementStart) / 60))
        let basis = passengerBasis(in: content)
        let legs = numbers.enumerated().map { index, number in
            AssignmentPlanLeg(
                id: id + "|leg|\(index)",
                flightNumber: normalizedDisplayFlight(number),
                role: .passenger,
                departure: routeNodes?[safe: index].map(expandAirport),
                arrival: routeNodes?[safe: index + 1].map(expandAirport)
            )
        }
        let metaLegs = legs.enumerated().map { index, leg in
            AssignmentV119LegMetadata(
                flightNumber: leg.flightNumber,
                departure: leg.departure,
                arrival: leg.arrival,
                aircraft: normalizedAircraft(aircraftValues[safe: index] ?? defaultAircraft)
            )
        }
        let metadata = AssignmentV119Metadata(
            sourceStart: sourceStart,
            sourceEnd: sourceEnd,
            passengerBasis: basis,
            passengerMovementMinutes: movementMinutes,
            linkedGroupID: nil,
            waitingMinutes: nil,
            subsequentDutyReductionMinutes: nil,
            linkedSequenceMinutes: nil,
            legs: metaLegs
        )

        return makeItem(
            id: id,
            kind: .passenger,
            start: movementStart,
            end: sourceEnd,
            title: "Перелёт пассажиром",
            flightNumber: numbers.first.map(normalizedDisplayFlight),
            flightNumbers: numbers.map(normalizedDisplayFlight),
            departure: routeNodes?.first.map(expandAirport),
            arrival: routeNodes?.last.map(expandAirport),
            aircraft: normalizedAircraft(defaultAircraft),
            assignmentGroup: route.map(expandRoute),
            detail: AssignmentV119MetadataCodec.encode(
                humanDetail: nil,
                metadata: metadata
            ),
            flightLegs: legs,
            plannedFlightMinutes: nil,
            isAllDayRange: false,
            originMonthKey: scopeMonthKey
        )
    }

    private static func makeItem(
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

    // MARK: - Linking passenger / working events

    private static func linkPassengerAndWorkingEvents(
        _ input: [AssignmentPlanItem]
    ) -> [AssignmentPlanItem] {
        var items = input
        guard items.count > 1 else { return items }

        for index in 0..<(items.count - 1) {
            let leftKind = items[index].kind
            let rightKind = items[index + 1].kind
            let isPair = (leftKind == .passenger && rightKind == .flight)
                || (leftKind == .flight && rightKind == .passenger)
            guard isPair else { continue }

            var leftMeta = AssignmentV119MetadataCodec.metadata(from: items[index].detail)
                ?? AssignmentV119Metadata()
            var rightMeta = AssignmentV119MetadataCodec.metadata(from: items[index + 1].detail)
                ?? AssignmentV119Metadata()

            let leftEnd = items[index].end
            let rightStart = items[index + 1].start
            let gapMinutes = max(0, Int(rightStart.timeIntervalSince(leftEnd) / 60))
            let chronologicalGap = rightStart.timeIntervalSince(leftEnd)
            guard chronologicalGap < 10 * 60 * 60 else { continue }

            let groupID = "link|\(items[index].id)|\(items[index + 1].id)"
            leftMeta.linkedGroupID = groupID
            rightMeta.linkedGroupID = groupID

            if leftKind == .passenger {
                leftMeta.waitingMinutes = gapMinutes > 0 ? gapMinutes : nil
                let passengerMinutes = leftMeta.passengerMovementMinutes
                    ?? items[index].durationMinutes
                rightMeta.subsequentDutyReductionMinutes = passengerMinutes / 2
            } else {
                rightMeta.waitingMinutes = gapMinutes > 0 ? gapMinutes : nil
                let passengerMinutes = rightMeta.passengerMovementMinutes
                    ?? items[index + 1].durationMinutes
                let total = items[index].durationMinutes
                    + gapMinutes
                    + passengerMinutes
                leftMeta.linkedSequenceMinutes = total
                rightMeta.linkedSequenceMinutes = total
            }

            items[index].detail = AssignmentV119MetadataCodec.replacingMetadata(
                in: items[index].detail,
                with: leftMeta
            )
            items[index + 1].detail = AssignmentV119MetadataCodec.replacingMetadata(
                in: items[index + 1].detail,
                with: rightMeta
            )
        }
        return items
    }

    // MARK: - Content helpers

    private static func eventLabels(_ text: String) -> (title: String, detail: String?) {
        let normalizedSource = text.replacingOccurrences(
            of: #"\s*·\s*"#,
            with: " ",
            options: .regularExpression
        )
        let lines = normalizedSource
            .components(separatedBy: .newlines)
            .map { cleanLine($0) }
            .filter { !$0.isEmpty }
            .filter { flightNumbers(in: $0).isEmpty }
            .filter { routeLine(in: $0) == nil }

        guard let first = lines.first else { return ("", nil) }
        let title = canonicalTitle(first)
        let detailLines = lines.dropFirst()
            .filter { normalizedText($0) != normalizedText(title) }
        let detail = detailLines.enumerated().map { index, line in
            guard index < detailLines.count - 1 else { return line }
            return line.replacingOccurrences(
                of: #"\.\s*$"#,
                with: "",
                options: .regularExpression
            )
        }
        .joined(separator: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        return (title, detail.isEmpty ? nil : detail)
    }

    private static func canonicalTitle(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("резерв в месте жит") || lower.contains("резерв в месте житель") {
            return "Резерв в месте жительства"
        }
        if lower.hasPrefix("резерв") { return "Резерв" }
        if lower.contains("выходн") { return "Выходной" }
        if lower.contains("медкомисс") || lower.contains("влэк") { return "Медкомиссия" }
        if lower.contains("отпуск") { return "Отпуск" }
        if lower.hasPrefix("явка") { return "Явка" }
        if lower.hasPrefix("обучение") { return "Обучение" }
        if lower.contains("тренаж") || lower.contains("ктс") { return raw }
        return raw
    }

    private static func classify(_ text: String) -> AssignmentPlanKind {
        let value = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if value.contains("резерв в месте жит") || value.contains("резерв в месте житель") {
            return .homeReserve
        }
        if value.contains("резерв") { return .hotelReserve }
        if value.contains("выходн") { return .dayOff }
        if value.contains("медкомисс") || value.contains("влэк") { return .medical }
        if value.contains("отпуск") { return .leave }
        if value.hasPrefix("явка") { return .training }
        if value.contains("тренаж") || value.contains("ктс") { return .simulator }
        if value.contains("обуч") || value.contains("явка") || value.contains("инструктаж") {
            return .training
        }
        return .ground
    }

    private static func cleanLine(_ raw: String) -> String {
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

    private static func flightNumbers(in text: String) -> [String] {
        regex(in: text.uppercased(), pattern: #"SU\s*\d{2,4}"#)
            .map(normalizedDisplayFlight)
    }

    private static func passengerFlightNumbers(in text: String) -> Set<String> {
        var result: Set<String> = []
        for line in text.components(separatedBy: .newlines) {
            guard line.localizedCaseInsensitiveContains("пассаж") else { continue }
            let numbers = flightNumbers(in: line)
            if numbers.isEmpty { continue }
            for number in numbers {
                result.insert(normalizedFlight(number))
            }
        }
        if result.isEmpty,
           text.localizedCaseInsensitiveContains("пассаж") {
            for number in flightNumbers(in: text) {
                result.insert(normalizedFlight(number))
            }
        }
        return result
    }

    private static func passengerBasis(in text: String) -> String {
        let value = text.lowercased()
        if value.contains("по билету") { return "по билету" }
        return "по заданию"
    }

    private static func routeLine(in text: String) -> String? {
        text.components(separatedBy: .newlines).first { raw in
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedLine = line.replacingOccurrences(
                of: #"[‐‑‒–—]"#,
                with: "-",
                options: .regularExpression
            )
            let lower = normalizedLine.lowercased()
            return normalizedLine.contains("-")
                && !lower.contains("su")
                && !lower.contains("a-3")
                && !lower.contains("a3")
                && !lower.contains("b-7")
                && !lower.contains("ч ")
                && !lower.contains("планируем")
                && regex(in: normalizedLine, pattern: #"\b\d{1,2}:\d{2}\b"#).isEmpty
        }
    }

    private static func splitRoute(_ route: String, expectedLegCount: Int) -> [String]? {
        var protected = route.replacingOccurrences(
            of: #"[‐‑‒–—]"#,
            with: "-",
            options: .regularExpression
        )
        protected = protected.replacingOccurrences(
            of: #"\s*-\s*"#,
            with: "-",
            options: .regularExpression
        )

        for airport in AirportDatabase.airports where airport.name.contains("-") {
            let airportName = airport.name
                .replacingOccurrences(
                    of: #"[‐‑‒–—]"#,
                    with: "-",
                    options: .regularExpression
                )
                .replacingOccurrences(
                    of: #"\s*-\s*"#,
                    with: "-",
                    options: .regularExpression
                )
            protected = protected.replacingOccurrences(
                of: airportName,
                with: airportName.replacingOccurrences(of: "-", with: "§"),
                options: [.caseInsensitive]
            )
        }

        let nodes = protected
            .split(separator: "-")
            .map { String($0).replacingOccurrences(of: "§", with: "-") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return nodes.count == expectedLegCount + 1 ? nodes : nil
    }

    private static func expandAirport(_ value: String) -> String {
        value
            .replacingOccurrences(of: "Ш (B)", with: "Шереметьево (B)")
            .replacingOccurrences(of: "Ш (C)", with: "Шереметьево (C)")
            .replacingOccurrences(of: "Ш(B)", with: "Шереметьево (B)")
            .replacingOccurrences(of: "Ш(C)", with: "Шереметьево (C)")
    }

    private static func expandRoute(_ route: String) -> String {
        route
            .replacingOccurrences(of: "Ш (B)", with: "Шереметьево (B)")
            .replacingOccurrences(of: "Ш (C)", with: "Шереметьево (C)")
    }

    private static func aircraftTypes(in text: String) -> [String] {
        regex(
            in: text.uppercased(),
            pattern: #"\b(?:A|B)-?\d{3,4}[A-Z]?\b"#
        )
    }

    private static func normalizedAircraft(_ value: String?) -> String? {
        value?.replacingOccurrences(of: "-", with: "")
    }

    private static func plannedFlightMinutes(in text: String) -> Int? {
        guard let groups = captures(
            in: text,
            pattern: #"(\d+)\s*ч\s*(\d+)\s*мин"#
        ), groups.count >= 3,
        let hours = Int(groups[1]),
        let minutes = Int(groups[2]) else {
            return nil
        }
        return hours * 60 + minutes
    }

    private static func normalizedDisplayFlight(_ value: String) -> String {
        let digits = value.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "SU", with: "")
            .filter(\.isNumber)
        return digits.isEmpty ? value : "SU \(digits)"
    }

    private static func normalizedFlight(_ value: String) -> String {
        canonicalFlightNumber(value)
    }

    private static func exactTimes(in text: String) -> [String] {
        regex(in: text, pattern: #"\b(?:[01]?\d|2[0-3]):[0-5]\d\b"#)
    }

    private static func dates(in text: String, year: Int) -> [Date] {
        guard let regex = try? NSRegularExpression(pattern: #"(\d{1,2})\.(\d{1,2})"#) else {
            return []
        }
        let ns = text as NSString
        return regex.matches(
            in: text,
            range: NSRange(location: 0, length: ns.length)
        ).compactMap { match in
            guard match.numberOfRanges >= 3,
                  let day = Int(ns.substring(with: match.range(at: 1))),
                  let month = Int(ns.substring(with: match.range(at: 2))) else {
                return nil
            }
            var components = DateComponents()
            components.timeZone = moscowTimeZone
            components.year = year
            components.month = month
            components.day = day
            return moscowCalendar.date(from: components)
        }
    }

    private static func dateWithTime(_ clock: String, date: Date) -> Date? {
        let parts = clock.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return nil
        }
        return moscowCalendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: date
        )
    }

    private static func firstYear(in text: String) -> Int? {
        regex(in: text, pattern: #"20\d{2}"#).first.flatMap(Int.init)
    }

    private static func scopeMonthKey(in text: String, year: Int) -> Int? {
        let value = text.lowercased()
        let months: [(String, Int)] = [
            ("январ", 1), ("феврал", 2), ("март", 3), ("апрел", 4),
            ("мая", 5), ("май", 5), ("июн", 6), ("июл", 7),
            ("август", 8), ("сентябр", 9), ("октябр", 10),
            ("ноябр", 11), ("декабр", 12)
        ]
        guard let month = months.first(where: { value.contains($0.0) })?.1 else {
            return nil
        }
        return year * 100 + month
    }

    private static func isHeaderRow(_ text: String) -> Bool {
        let value = text.lowercased()
        return value.contains("дата назначение")
            || value.contains("планируемое полётное время")
            || value.contains("сгенерировано")
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

    private static func captures(in text: String, pattern: String) -> [String]? {
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
}


private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
