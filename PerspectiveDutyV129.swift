import Foundation


enum AirportPresentationV129 {
    static func iataHint(from raw: String?) -> String? {
        guard let raw else { return nil }
        let upper = raw.uppercased()

        if upper.contains("ШЕРЕМЕТЬЕВО") || upper == "Ш" || upper.hasPrefix("Ш (") {
            return "SVO"
        }

        if let slash = upper.firstIndex(of: "/") {
            let prefix = String(upper[..<slash])
            let letters = prefix.filter(\.isLetter)
            if letters.count == 3 { return letters }
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
        return letters.count == 3 ? letters : nil
    }

    static func display(code rawCode: String) -> String {
        let upper = rawCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let components = upper.split(separator: "/", maxSplits: 1).map(String.init)
        let iata = components.first ?? upper
        let terminal = components.count > 1 ? components[1] : nil

        let name: String
        if iata == "SVO" {
            name = "Шереметьево"
        } else if let airport = AirportDatabase.airport(for: iata) {
            name = airport.name
        } else {
            name = iata
        }

        let suffix = terminal.map { "\(iata)/\($0)" } ?? iata
        return "\(name) (\(suffix))"
    }

    static func display(raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.localizedCaseInsensitiveContains("Шереметьево") {
            let upper = trimmed.uppercased()
            if let terminal = singleLetterParenthesis(in: upper) {
                return "Шереметьево (SVO/\(terminal))"
            }
            return "Шереметьево (SVO)"
        }

        if let iata = iataHint(from: trimmed) {
            if trimmed.uppercased().hasPrefix(iata), trimmed.contains("/") {
                return display(code: trimmed)
            }
            if let terminal = terminalAfterIATA(in: trimmed, iata: iata) {
                return display(code: "\(iata)/\(terminal)")
            }
            return display(code: iata)
        }
        return trimmed
    }

    private static func singleLetterParenthesis(in value: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"\(([A-Z0-9])\)"#),
              let match = regex.firstMatch(
                in: value,
                range: NSRange(location: 0, length: (value as NSString).length)
              ),
              match.numberOfRanges >= 2 else { return nil }
        return (value as NSString).substring(with: match.range(at: 1))
    }

    private static func terminalAfterIATA(in value: String, iata: String) -> String? {
        let upper = value.uppercased()
        guard let regex = try? NSRegularExpression(
            pattern: "\\(\(NSRegularExpression.escapedPattern(for: iata))/([A-Z0-9]+)\\)"
        ),
        let match = regex.firstMatch(
            in: upper,
            range: NSRange(location: 0, length: (upper as NSString).length)
        ),
        match.numberOfRanges >= 2 else { return nil }
        return (upper as NSString).substring(with: match.range(at: 1))
    }
}


@MainActor
enum PerspectiveDutyBuilderV129 {
    enum Result {
        case ready(FlightDuty)
        case missing(String)
        case mismatch(String)
    }

    private struct SourceLeg {
        let flightNumber: String
        let departure: String?
        let arrival: String?
        let aircraft: String?
    }

    static func build(
        item: AssignmentPlanItem,
        scheduleStore: FlightScheduleStoreV129 = .shared
    ) -> Result {
        guard item.kind == .flight else {
            return .missing("Карточка задания доступна только для рабочей полётной смены.")
        }

        let metadata = AssignmentV119MetadataCodec.metadata(from: item.detail)
        let sourceLegs = legs(item: item, metadata: metadata)
        guard !sourceLegs.isEmpty else {
            return .missing("В перспективном плане не удалось определить номера рейсов этой смены.")
        }

        let lookupDate = metadata?.sourceStart ?? item.start
        var matches: [FlightScheduleMatchV129] = []

        for leg in sourceLegs {
            let departureHint = AirportPresentationV129.iataHint(from: leg.departure)
            let arrivalHint = AirportPresentationV129.iataHint(from: leg.arrival)
            let routed = scheduleStore.matches(
                flightNumber: leg.flightNumber,
                moscowDate: lookupDate,
                departureHint: departureHint,
                arrivalHint: arrivalHint
            )

            let chosen: FlightScheduleMatchV129?
            if routed.count == 1 {
                chosen = routed[0]
            } else {
                let plain = scheduleStore.matches(
                    flightNumber: leg.flightNumber,
                    moscowDate: lookupDate
                )
                chosen = plain.count == 1 ? plain[0] : nil
            }

            guard let chosen else {
                let digits = FlightScheduleStoreV129.normalizedFlightNumber(leg.flightNumber)
                return .missing(
                    "Для рейса \(digits) на \(formatDate(lookupDate)) нет однозначной строки в загруженном расписании. Карточка не построена."
                )
            }
            matches.append(chosen)
        }

        let scheduleMinutes = matches.reduce(0) { $0 + $1.entry.flightMinutes }
        if let planned = item.plannedFlightMinutes,
           planned > 0,
           planned != scheduleMinutes {
            return .mismatch(
                "Расписание даёт \(timeText(scheduleMinutes)), а перспективный план — \(timeText(planned)). Карточка не построена: требуется проверка исходных данных."
            )
        }

        var flightLegs: [FlightLeg] = []
        var previousEngineOff: Date?

        for index in sourceLegs.indices {
            let source = sourceLegs[index]
            let match = matches[index]
            let engineOn = match.engineOn
            let engineOff = match.engineOff
            let takeoff = moscowCalendar.date(byAdding: .minute, value: 8, to: engineOn) ?? engineOn
            let landing = moscowCalendar.date(byAdding: .minute, value: -8, to: engineOff) ?? engineOff
            let workStart: Date
            if let previousEngineOff {
                workStart = previousEngineOff
            } else {
                workStart = moscowCalendar.date(byAdding: .minute, value: -60, to: engineOn) ?? engineOn
            }
            let workEnd = index == sourceLegs.indices.last
                ? (moscowCalendar.date(byAdding: .minute, value: 30, to: engineOff) ?? engineOff)
                : engineOff

            let timeline = PortalFlightTimes(
                workStart: workStart,
                engineOn: engineOn,
                takeoff: takeoff,
                landing: landing,
                engineOff: engineOff,
                workEnd: workEnd
            )

            flightLegs.append(
                FlightLeg(
                    date: formatDate(engineOn),
                    flightNumber: FlightScheduleStoreV129.normalizedFlightNumber(source.flightNumber),
                    departure: match.departureWithTerminal,
                    arrival: match.arrivalWithTerminal,
                    aircraft: normalizedAircraft(source.aircraft ?? item.aircraft ?? ""),
                    registration: "",
                    plannedDeparture: formatClock(engineOn),
                    workStart: formatClock(workStart),
                    engineOn: formatClock(engineOn),
                    takeoff: formatClock(takeoff),
                    landing: formatClock(landing),
                    engineOff: formatClock(engineOff),
                    portalTimes: timeline,
                    assignmentNumber: nil,
                    legNumber: FlightScheduleStoreV129.normalizedFlightNumber(source.flightNumber),
                    scheduleType: .planned,
                    calculatedMinutesOverride: nil
                )
            )
            previousEngineOff = engineOff
        }

        return .ready(FlightDuty(id: UUID(), legs: flightLegs))
    }

    private static func legs(
        item: AssignmentPlanItem,
        metadata: AssignmentV119Metadata?
    ) -> [SourceLeg] {
        if let metadata, !metadata.legs.isEmpty {
            return metadata.legs.map {
                SourceLeg(
                    flightNumber: $0.flightNumber,
                    departure: $0.departure,
                    arrival: $0.arrival,
                    aircraft: $0.aircraft
                )
            }
        }

        if let values = item.flightLegs, !values.isEmpty {
            return values.map {
                SourceLeg(
                    flightNumber: $0.flightNumber,
                    departure: $0.departure,
                    arrival: $0.arrival,
                    aircraft: item.aircraft
                )
            }
        }

        let numbers = item.flightNumbers ?? item.flightNumber.map { [$0] } ?? []
        return numbers.map {
            SourceLeg(
                flightNumber: $0,
                departure: item.departure,
                arrival: item.arrival,
                aircraft: item.aircraft
            )
        }
    }

    private static func normalizedAircraft(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return AircraftFamilyV129.normalized(trimmed)?.rawValue
            ?? trimmed.replacingOccurrences(of: "-", with: "")
    }
}
