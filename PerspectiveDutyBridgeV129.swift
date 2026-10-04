import SwiftUI
import Foundation


@MainActor
enum DutyAutofillV129 {
    static func normalizedFlightNumber(_ raw: String) -> String {
        String(raw.filter(\.isNumber).prefix(4))
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
        var candidates: [String: FlightScheduleMatchV129] = [:]

        for offset in -1...1 {
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
        return values.min {
            let left = abs($0.engineOn.timeIntervalSince(referenceDate))
            let right = abs($1.engineOn.timeIntervalSince(referenceDate))
            if left == right { return $0.engineOn < $1.engineOn }
            return left < right
        }
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
        }
        return leg
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
        let name: String
        if base == "SVO" {
            name = "Шереметьево"
        } else {
            name = airport?.name ?? base
        }
        let terminalValue = terminal?.trimmingCharacters(in: .whitespacesAndNewlines)
        let shownCode: String
        if let terminalValue, !terminalValue.isEmpty {
            shownCode = "\(base)/\(terminalValue.uppercased())"
        } else {
            shownCode = base
        }
        return "\(name) (\(shownCode))"
    }
}


@MainActor
enum PerspectiveDutyBuilderV129 {
    enum Result {
        case ready(FlightDuty)
        case missing(String)
        case mismatch(FlightDuty, expected: Int, actual: Int)
    }

    private struct PlanLeg {
        let flightNumber: String
        let departure: String?
        let arrival: String?
        let aircraft: String?
    }

    static func build(item: AssignmentPlanItem) -> Result {
        let metadata = AssignmentV119MetadataCodec.metadata(from: item.detail)
        let planLegs = resolvedPlanLegs(item: item, metadata: metadata)
        guard !planLegs.isEmpty else {
            return .missing("В назначении не удалось определить номера рейсов.")
        }

        let sourceStart = metadata?.sourceStart ?? item.start
        var selected: [(PlanLeg, FlightScheduleMatchV129)] = []
        var previousEnd: Date?

        for planLeg in planLegs {
            let reference = previousEnd ?? sourceStart
            var match = DutyAutofillV129.scheduleMatch(
                flightNumber: planLeg.flightNumber,
                referenceDate: reference,
                notBefore: previousEnd,
                departureHint: planLeg.departure,
                arrivalHint: planLeg.arrival
            )
            if match == nil {
                match = DutyAutofillV129.scheduleMatch(
                    flightNumber: planLeg.flightNumber,
                    referenceDate: reference,
                    notBefore: previousEnd
                )
            }
            guard let match else {
                return .missing(
                    "В загруженном расписании не найден рейс \(DutyAutofillV129.normalizedFlightNumber(planLeg.flightNumber)) рядом с \(shortDate(reference))."
                )
            }
            selected.append((planLeg, match))
            previousEnd = match.engineOff
        }

        let duty = makeDuty(selected)
        if let expected = item.plannedFlightMinutes,
           expected > 0,
           expected != duty.flightMinutes {
            return .mismatch(duty, expected: expected, actual: duty.flightMinutes)
        }
        return .ready(duty)
    }

    static func scheduleDisplay(
        flightNumber: String,
        date: Date,
        departureHint: String? = nil,
        arrivalHint: String? = nil
    ) -> FlightScheduleMatchV129? {
        DutyAutofillV129.scheduleMatch(
            flightNumber: flightNumber,
            referenceDate: date,
            departureHint: departureHint,
            arrivalHint: arrivalHint
        ) ?? DutyAutofillV129.scheduleMatch(
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
        _ values: [(PlanLeg, FlightScheduleMatchV129)]
    ) -> FlightDuty {
        var legs: [FlightLeg] = []
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
            let rawAircraft = planLeg.aircraft ?? ""
            let aircraft = AircraftFamilyV129.display(
                rawAircraft.replacingOccurrences(of: "-", with: "")
            )
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
                    registration: "",
                    plannedDeparture: formatClock(engineOn),
                    workStart: formatClock(workStart),
                    engineOn: formatClock(engineOn),
                    takeoff: formatClock(takeoff),
                    landing: formatClock(landing),
                    engineOff: formatClock(engineOff),
                    portalTimes: times,
                    portalKey: nil,
                    assignmentNumber: "План",
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
    let duty: FlightDuty
    @ObservedObject var store: AppStore
    let onClose: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width * 0.92, 556)
            ZStack {
                Color.black.opacity(0.65)
                    .ignoresSafeArea()
                    .onTapGesture { onClose() }

                ScrollView(.vertical) {
                    DutyDetailView(
                        duty: duty,
                        onClose: onClose,
                        scrollsAsPage: true,
                        isReadOnly: true
                    )
                    .environmentObject(store)
                    .frame(width: width)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height, alignment: .center)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}
