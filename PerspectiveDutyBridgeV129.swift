import SwiftUI
import Foundation


@MainActor
enum DutyAutofillV129 {
    private enum CachedScheduleMatch {
        case missing
        case value(FlightScheduleMatchV129)
    }

    private static var scheduleMatchCache: [String: CachedScheduleMatch] = [:]

    static func normalizedFlightNumber(_ raw: String) -> String {
        canonicalFlightNumber(String(raw.filter(\.isNumber).prefix(4)))
    }

    static func pairedFlightNumber(after raw: String) -> String? {
        let digits = normalizedFlightNumber(raw)
        guard let number = Int(digits), number > 0 else { return nil }
        let paired = number.isMultiple(of: 2) ? number + 1 : number - 1
        return paired > 0 ? String(paired) : nil
    }

    static func scheduleMatch(
        flightNumber: String,
        referenceDate: Date,
        notBefore: Date? = nil,
        departureHint: String? = nil,
        arrivalHint: String? = nil
    ) -> FlightScheduleMatchV129? {
        let store = FlightScheduleStoreV129.shared
        let cacheKey = scheduleMatchCacheKey(
            store: store,
            flightNumber: flightNumber,
            referenceDate: referenceDate,
            notBefore: notBefore,
            departureHint: departureHint,
            arrivalHint: arrivalHint
        )
        if let cached = scheduleMatchCache[cacheKey] {
            switch cached {
            case .missing: return nil
            case .value(let match): return match
            }
        }

        var candidates: [String: FlightScheduleMatchV129] = [:]
        let offsets = notBefore == nil ? [0] : [0, 1]
        for offset in offsets {
            guard let day = moscowCalendar.date(
                byAdding: .day,
                value: offset,
                to: referenceDate
            ) else { continue }

            for value in store.matches(
                flightNumber: flightNumber,
                moscowDate: day,
                departureHint: departureHint,
                arrivalHint: arrivalHint
            ) {
                candidates[value.id] = value
            }
        }

        var values = Array(candidates.values)
        if let notBefore {
            values = values.filter { $0.engineOn >= notBefore.addingTimeInterval(-5 * 60) }
        }
        if departureHint == nil && arrivalHint == nil && values.count != 1 {
            cacheScheduleMatch(nil, for: cacheKey)
            return nil
        }
        let result = values.min {
            let left = abs($0.engineOn.timeIntervalSince(referenceDate))
            let right = abs($1.engineOn.timeIntervalSince(referenceDate))
            if left == right { return $0.engineOn < $1.engineOn }
            return left < right
        }
        cacheScheduleMatch(result, for: cacheKey)
        return result
    }

    private static func scheduleMatchCacheKey(
        store: FlightScheduleStoreV129,
        flightNumber: String,
        referenceDate: Date,
        notBefore: Date?,
        departureHint: String?,
        arrivalHint: String?
    ) -> String {
        let generation = Int((store.imports.first?.importedAt.timeIntervalSinceReferenceDate ?? 0).rounded())
        let referenceMinute = Int((referenceDate.timeIntervalSinceReferenceDate / 60).rounded())
        let notBeforeMinute = notBefore.map { Int(($0.timeIntervalSinceReferenceDate / 60).rounded()) } ?? -1
        return [
            String(store.entries.count),
            String(generation),
            normalizedFlightNumber(flightNumber),
            String(referenceMinute),
            String(notBeforeMinute),
            FlightScheduleStoreV129.airportCode(departureHint) ?? "",
            FlightScheduleStoreV129.airportCode(arrivalHint) ?? ""
        ].joined(separator: "|")
    }

    private static func cacheScheduleMatch(_ match: FlightScheduleMatchV129?, for key: String) {
        if scheduleMatchCache.count > 4096 {
            scheduleMatchCache.removeAll(keepingCapacity: true)
        }
        scheduleMatchCache[key] = match.map(CachedScheduleMatch.value) ?? .missing
    }

    static func applyingSchedule(
        to source: FlightLeg,
        match: FlightScheduleMatchV129,
        index: Int,
        totalCount: Int,
        previousEngineOff: Date?
    ) -> FlightLeg {
        var leg = source
        let engineOn = match.engineOn
        let engineOff = match.engineOff
        let takeoff = engineOn.addingTimeInterval(8 * 60)
        let landing = engineOff.addingTimeInterval(-8 * 60)
        let workStart = index == 0
            ? engineOn.addingTimeInterval(-60 * 60)
            : (previousEngineOff ?? engineOn.addingTimeInterval(-60 * 60))
        let workEnd = index == totalCount - 1
            ? engineOff.addingTimeInterval(30 * 60)
            : engineOff
        let number = normalizedFlightNumber(match.entry.flightNumber)

        leg.flightNumber = number
        leg.legNumber = number
        leg.departure = match.departureWithTerminal
        leg.arrival = match.arrivalWithTerminal
        leg.date = formatDate(engineOn)
        leg.plannedDeparture = formatClock(engineOn)
        leg.workStart = formatClock(workStart)
        leg.engineOn = formatClock(engineOn)
        leg.takeoff = formatClock(takeoff)
        leg.landing = formatClock(landing)
        leg.engineOff = formatClock(engineOff)
        leg.portalTimes = PortalFlightTimes(
            workStart: workStart,
            engineOn: engineOn,
            takeoff: takeoff,
            landing: landing,
            engineOff: engineOff,
            workEnd: workEnd
        )
        leg.scheduleType = .planned

        if let scheduleType = AircraftFamilyV129.normalized(match.entry.rawAircraftCode) {
            leg.aircraft = scheduleType.rawValue
            leg.registration = aircraftReference(for: match)?.registration ?? "RA-"
        }
        return leg
    }

    static func aircraftReference(for match: FlightScheduleMatchV129) -> AircraftReferenceV129? {
        guard let family = AircraftFamilyV129.normalized(match.entry.rawAircraftCode) else {
            return nil
        }
        let seed = [
            FlightScheduleStoreV129.normalizedFlightNumber(match.entry.flightNumber),
            FlightScheduleStoreV129.dayKey(match.operatingDateUTC),
            match.entry.departure,
            match.entry.arrival,
            match.entry.rawAircraftCode,
            match.entry.configuration ?? ""
        ].joined(separator: "|")
        return AircraftReferenceStoreV129.shared.stableAircraft(for: family, seed: seed)
    }

    static func applyingAircraftReference(to source: FlightLeg) -> FlightLeg {
        var leg = source
        if let aircraft = AircraftReferenceStoreV129.shared.aircraft(for: leg.registration) {
            leg.aircraft = aircraft.type.rawValue
        }
        return leg
    }

    static func displayAirport(code: String, terminal: String?) -> String {
        let base = code.uppercased()
        let airport = AirportDatabase.airport(for: base)
        let name = base == "SVO" ? "Шереметьево" : (airport?.name ?? base)
        let terminalValue = terminal?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let shownTerminal = base == "SVO" && ["D", "E", "F"].contains(terminalValue ?? "")
            ? terminalValue
            : nil
        let shownCode = shownTerminal.map { "\(base)/\($0)" } ?? base
        return "\(name) (\(shownCode))"
    }
}


@MainActor
final class PerspectiveDutyOverrideStoreV130: ObservableObject {
    static let shared = PerspectiveDutyOverrideStoreV130()

    private static let key = "aerouchet.v130.perspectiveDutyOverrides"
    @Published private(set) var values: [String: [FlightLeg]] = [:]

    private init() {
        // Ручные правки перспективных карточек не восстановить — резерв обязателен (п. 17).
        values = StorageSafety.decode(
            [String: [FlightLeg]].self, key: Self.key, title: "Правки перспективного плана"
        ) ?? [:]
    }

    func legs(for itemID: String) -> [FlightLeg]? {
        guard let legs = values[itemID], !legs.isEmpty else { return nil }
        return legs
    }

    func save(_ legs: [FlightLeg], for itemID: String) {
        guard !legs.isEmpty else { return }
        values[itemID] = legs
        persist()
    }

    func remove(itemID: String) {
        values.removeValue(forKey: itemID)
        persist()
    }

    private func persist() {
        StorageSafety.store(values, key: Self.key, title: "Правки перспективного плана")
    }
}


@MainActor
enum PerspectiveDutyBuilderV129 {
    enum Result {
        case ready(FlightDuty)
        case missing(String)
        case routeMismatch(String)
        case mismatch(FlightDuty, expected: Int, actual: Int)
    }

    private struct PlanLeg {
        let flightNumber: String
        let departure: String?
        let arrival: String?
        let aircraft: String?
    }

    private static var buildCache: [String: Result] = [:]

    static func build(item: AssignmentPlanItem) -> Result {
        if let saved = PerspectiveDutyOverrideStoreV130.shared.legs(for: item.id) {
            return .ready(FlightDuty(id: UUID(), legs: saved))
        }

        let key = buildCacheKey(item)
        if let cached = buildCache[key] { return cached }
        func finish(_ result: Result) -> Result {
            if Self.buildCache.count > 1024 {
                Self.buildCache.removeAll(keepingCapacity: true)
            }
            Self.buildCache[key] = result
            return result
        }

        let metadata = AssignmentV119MetadataCodec.metadata(from: item.detail)
        let planLegs = resolvedPlanLegs(item: item, metadata: metadata)
        guard !planLegs.isEmpty else {
            return finish(.missing("В назначении не удалось определить номера рейсов."))
        }

        let sourceStart = metadata?.sourceStart ?? item.start
        var selected: [(PlanLeg, FlightScheduleMatchV129)] = []
        var previousEnd: Date?

        for planLeg in planLegs {
            let reference = previousEnd ?? sourceStart
            let depHint = FlightScheduleStoreV129.airportCode(planLeg.departure)
            let arrHint = FlightScheduleStoreV129.airportCode(planLeg.arrival)
            let match: FlightScheduleMatchV129?

            if depHint != nil || arrHint != nil {
                if let strict = DutyAutofillV129.scheduleMatch(
                    flightNumber: planLeg.flightNumber,
                    referenceDate: reference,
                    notBefore: previousEnd,
                    departureHint: depHint,
                    arrivalHint: arrHint
                ) {
                    match = strict
                } else if let plain = DutyAutofillV129.scheduleMatch(
                    flightNumber: planLeg.flightNumber,
                    referenceDate: reference,
                    notBefore: previousEnd
                ) {
                    let number = DutyAutofillV129.normalizedFlightNumber(planLeg.flightNumber)
                    let expected = "\(depHint ?? "?") → \(arrHint ?? "?")"
                    let actual = "\(plain.entry.departure) → \(plain.entry.arrival)"
                    return finish(.routeMismatch(
                        "Рейс \(number): маршрут плана \(expected), в расписании \(actual)"
                    ))
                } else {
                    match = nil
                }
            } else {
                match = DutyAutofillV129.scheduleMatch(
                    flightNumber: planLeg.flightNumber,
                    referenceDate: reference,
                    notBefore: previousEnd
                )
            }

            guard let match else {
                return finish(.missing(
                    "В загруженном расписании не найден рейс \(DutyAutofillV129.normalizedFlightNumber(planLeg.flightNumber)) рядом с \(shortDate(reference))."
                ))
            }
            selected.append((planLeg, match))
            previousEnd = match.engineOff
        }

        let duty = makeDuty(
            selected,
            itemID: item.id,
            assignmentDate: sourceStart
        )
        if let expected = item.plannedFlightMinutes,
           expected > 0,
           expected != duty.flightMinutes {
            return finish(.mismatch(duty, expected: expected, actual: duty.flightMinutes))
        }
        return finish(.ready(duty))
    }

    static func routeConflict(item: AssignmentPlanItem) -> String? {
        if case .routeMismatch(let conflict) = build(item: item) {
            return conflict
        }
        return nil
    }

    private static func buildCacheKey(_ item: AssignmentPlanItem) -> String {
        let store = FlightScheduleStoreV129.shared
        let generation = Int((store.imports.first?.importedAt.timeIntervalSinceReferenceDate ?? 0).rounded())
        return [
            String(store.entries.count),
            String(generation),
            item.id,
            String(Int(item.start.timeIntervalSinceReferenceDate.rounded())),
            String(Int(item.end.timeIntervalSinceReferenceDate.rounded())),
            item.flightNumber ?? "",
            item.departure ?? "",
            item.arrival ?? ""
        ].joined(separator: "|")
    }

    static func scheduleDisplay(
        flightNumber: String,
        date: Date,
        departureHint: String? = nil,
        arrivalHint: String? = nil
    ) -> FlightScheduleMatchV129? {
        let depHint = FlightScheduleStoreV129.airportCode(departureHint)
        let arrHint = FlightScheduleStoreV129.airportCode(arrivalHint)
        if depHint != nil || arrHint != nil {
            return DutyAutofillV129.scheduleMatch(
                flightNumber: flightNumber,
                referenceDate: date,
                departureHint: depHint,
                arrivalHint: arrHint
            )
        }
        return DutyAutofillV129.scheduleMatch(
            flightNumber: flightNumber,
            referenceDate: date
        )
    }

    private static func resolvedPlanLegs(
        item: AssignmentPlanItem,
        metadata: AssignmentV119Metadata?
    ) -> [PlanLeg] {
        if let metadata, !metadata.legs.isEmpty {
            return metadata.legs.map {
                PlanLeg(
                    flightNumber: $0.flightNumber,
                    departure: $0.departure,
                    arrival: $0.arrival,
                    aircraft: $0.aircraft
                )
            }
        }
        if let legs = item.flightLegs, !legs.isEmpty {
            return legs.map {
                PlanLeg(
                    flightNumber: $0.flightNumber,
                    departure: $0.departure,
                    arrival: $0.arrival,
                    aircraft: item.aircraft
                )
            }
        }
        if let number = item.flightNumber {
            return [
                PlanLeg(
                    flightNumber: number,
                    departure: item.departure,
                    arrival: item.arrival,
                    aircraft: item.aircraft
                )
            ]
        }
        return []
    }

    private static func makeDuty(
        _ values: [(PlanLeg, FlightScheduleMatchV129)],
        itemID: String,
        assignmentDate: Date
    ) -> FlightDuty {
        var legs: [FlightLeg] = []
        let assignmentNumber = shortDate(assignmentDate)

        for index in values.indices {
            let planLeg = values[index].0
            let match = values[index].1
            let engineOn = match.engineOn
            let engineOff = match.engineOff
            let takeoff = engineOn.addingTimeInterval(8 * 60)
            let landing = engineOff.addingTimeInterval(-8 * 60)
            let workStart = index == 0
                ? engineOn.addingTimeInterval(-60 * 60)
                : values[index - 1].1.engineOff
            let workEnd = index == values.indices.last
                ? engineOff.addingTimeInterval(30 * 60)
                : engineOff

            let sourceAircraft = match.entry.rawAircraftCode
            let reference = DutyAutofillV129.aircraftReference(for: match)
            let aircraft = reference?.type.rawValue
                ?? AircraftFamilyV129.display(sourceAircraft.replacingOccurrences(of: "-", with: ""))
            let registration = reference?.registration ?? "RA-"
            let number = DutyAutofillV129.normalizedFlightNumber(planLeg.flightNumber)
            let times = PortalFlightTimes(
                workStart: workStart,
                engineOn: engineOn,
                takeoff: takeoff,
                landing: landing,
                engineOff: engineOff,
                workEnd: workEnd
            )
            legs.append(
                FlightLeg(
                    date: formatDate(engineOn),
                    flightNumber: number,
                    departure: match.departureWithTerminal,
                    arrival: match.arrivalWithTerminal,
                    aircraft: aircraft,
                    registration: registration,
                    plannedDeparture: formatClock(engineOn),
                    workStart: formatClock(workStart),
                    engineOn: formatClock(engineOn),
                    takeoff: formatClock(takeoff),
                    landing: formatClock(landing),
                    engineOff: formatClock(engineOff),
                    portalTimes: times,
                    portalKey: nil,
                    assignmentNumber: assignmentNumber,
                    legNumber: number,
                    scheduleType: .planned,
                    calculatedMinutesOverride: nil
                )
            )
        }
        return FlightDuty(id: UUID(), legs: legs)
    }

    private static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = moscowTimeZone
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }
}


struct PerspectiveDutyOverlayV129: View {
    let item: AssignmentPlanItem
    let duty: FlightDuty
    @ObservedObject var store: AppStore
    @ObservedObject var planStore: AssignmentPlanStore
    let onClose: () -> Void

    var body: some View {
        DutyAssignmentOverlay(
            duty: duty,
            store: store,
            onUpdate: { legs in
                PerspectiveDutyOverrideStoreV130.shared.save(legs, for: item.id)
            },
            onDelete: {
                PerspectiveDutyOverrideStoreV130.shared.remove(itemID: item.id)
                planStore.deleteItem(id: item.id)
            },
            onClose: onClose
        )
    }
}
