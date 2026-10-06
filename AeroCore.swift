import SwiftUI
import Foundation


// MARK: - Форматтеры

let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ru_RU")
    formatter.timeZone = moscowTimeZone
    formatter.dateFormat = "dd.MM.yyyy"
    return formatter
}()

let clockFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = moscowTimeZone
    formatter.dateFormat = "HH:mm"
    return formatter
}()

let dateTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ru_RU")
    formatter.timeZone = moscowTimeZone
    formatter.dateFormat = "dd.MM.yyyy HH:mm"
    return formatter
}()

let monthFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ru_RU")
    formatter.timeZone = moscowTimeZone
    formatter.dateFormat = "LLLL yyyy"
    return formatter
}()

let longDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ru_RU")
    formatter.timeZone = moscowTimeZone
    formatter.dateFormat = "d MMMM yyyy"
    return formatter
}()

let weekdayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ru_RU")
    formatter.timeZone = moscowTimeZone
    formatter.dateFormat = "EEEE"
    return formatter
}()


// MARK: - Лег

struct PortalFlightTimes: Codable, Equatable {
    let workStart: Date
    let engineOn: Date
    let takeoff: Date
    let landing: Date
    let engineOff: Date
    let workEnd: Date
}

enum FlightScheduleType: String, Codable, CaseIterable, Identifiable {
    case planned = "Плановый"
    case unscheduled = "Внеплановый"
    var id: String { rawValue }
}

struct FlightLeg: Identifiable, Codable, Equatable {
    
    var id: UUID
    
    var date: String
    var flightNumber: String
    
    var departure: String
    var arrival: String
    
    var aircraft: String
    var registration: String
    
    var plannedDeparture: String
    
    var workStart: String
    var engineOn: String
    var takeoff: String
    var landing: String
    var engineOff: String
    var portalTimes: PortalFlightTimes?
    /// Ключ строки из выгрузки портала. Не меняется при правке времени лега,
    /// поэтому повторный импорт .xls узнаёт исправленный лег и не дублирует его.
    var portalKey: String?
    var assignmentNumber: String?
    var legNumber: String?
    var scheduleType: FlightScheduleType?
    var calculatedMinutesOverride: Int?
    
    init(
        id: UUID = UUID(),
        date: String,
        flightNumber: String,
        departure: String,
        arrival: String,
        aircraft: String,
        registration: String,
        plannedDeparture: String,
        workStart: String,
        engineOn: String,
        takeoff: String,
        landing: String,
        engineOff: String,
        portalTimes: PortalFlightTimes? = nil,
        portalKey: String? = nil,
        assignmentNumber: String? = nil,
        legNumber: String? = nil,
        scheduleType: FlightScheduleType? = nil,
        calculatedMinutesOverride: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.flightNumber = flightNumber
        self.departure = departure
        self.arrival = arrival
        self.aircraft = aircraft
        self.registration = registration
        self.plannedDeparture = plannedDeparture
        self.workStart = workStart
        self.engineOn = engineOn
        self.takeoff = takeoff
        self.landing = landing
        self.engineOff = engineOff
        self.portalTimes = portalTimes
        self.portalKey = portalKey
        self.assignmentNumber = assignmentNumber
        self.legNumber = legNumber
        self.scheduleType = scheduleType
        self.calculatedMinutesOverride = calculatedMinutesOverride
    }
}


// MARK: - Номер рейса (D38)

/// Канонический номер рейса: без «SU» и ведущих нулей.
/// «SU 0010», «0010», «010» и «10» — один и тот же рейс во всех источниках.
func canonicalFlightNumber(_ raw: String) -> String {
    let digits = raw.uppercased()
        .replacingOccurrences(of: "SU", with: "")
        .filter(\.isNumber)
    guard !digits.isEmpty else { return "" }
    let trimmed = digits.drop { $0 == "0" }
    return trimmed.isEmpty ? "0" : String(trimmed)
}


/// Все номера рейсов в поле номера: «SU 1110 / SU 1111», «1110/1111», «0010».
func canonicalFlightNumbers(in text: String) -> [String] {
    var result: [String] = []
    var current = ""
    for character in text.uppercased().replacingOccurrences(of: "SU", with: " ") {
        if character.isNumber {
            current.append(character)
        } else if !current.isEmpty {
            result.append(canonicalFlightNumber(current))
            current = ""
        }
    }
    if !current.isEmpty { result.append(canonicalFlightNumber(current)) }
    return result
}


// MARK: - Хронология лега

struct FlightTimeline {
    
    let plannedDeparture: Date
    
    let workStart: Date
    
    let engineOn: Date
    let takeoff: Date
    let landing: Date
    let engineOff: Date
    let workEnd: Date?
}


// MARK: - Наземные события

enum WorkEventType: String, Codable, CaseIterable, Identifiable {
    
    case appearance = "Явка"
    case reserve = "Резерв"
    case homeReserve = "Резерв дома"
    case simulator = "Тренажёр"
    
    var id: String {
        rawValue
    }
    
    var icon: String {
        
        switch self {
            
        case .appearance:
            return "person.badge.clock"
            
        case .reserve:
            return "bed.double.fill"
            
        case .homeReserve:
            return "house.fill"
            
        case .simulator:
            return "airplane.circle.fill"
        }
    }
    
    var color: Color {
        
        switch self {
            
        case .appearance:
            return .purple
            
        case .reserve:
            return .orange
            
        case .homeReserve:
            return .teal
            
        case .simulator:
            return .green
        }
    }
    
    var creditDivisor: Int {
        
        switch self {
            
        case .homeReserve:
            return 4
            
        default:
            return 1
        }
    }
}


struct WorkEvent: Identifiable, Codable, Equatable {
    
    var id: UUID
    
    var date: String
    
    var type: WorkEventType
    
    var startTime: String
    var endTime: String
    
    var note: String
    
    
    init(
        id: UUID = UUID(),
        date: String,
        type: WorkEventType,
        startTime: String,
        endTime: String,
        note: String = ""
    ) {
        
        self.id = id
        self.date = date
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.note = note
    }
    
    
    var validatedDateRange:
    (start: Date, end: Date)? {
        
        guard
            let start =
                parsedDate(
                    date:
                        date,
                    time:
                        startTime
                ),
            var end =
                parsedDate(
                    date:
                        date,
                    time:
                        endTime
                )
        else {
            return nil
        }
        
        
        if end < start {
            
            end =
            moscowCalendar.date(
                byAdding: .day,
                value: 1,
                to: end
            )!
        }
        
        
        return (
            start:
                start,
            end:
                end
        )
    }
    
    
    var hasValidStoredDates: Bool {
        validatedDateRange != nil
    }
    
    
    var startDate: Date {
        
        validatedDateRange?.start
        ??
        invalidStoredDatePlaceholder
    }
    
    
    var endDate: Date {
        
        validatedDateRange?.end
        ??
        invalidStoredDatePlaceholder
    }
    
    
    var rawMinutes: Int {
        
        minutesBetween(
            startDate,
            endDate
        )
    }
    
    
    /// Зачётное время в секундах. Секунды нужны только при делении (D37):
    /// резерв дома 8:01 / 4 = 2:00:15.
    var creditedSeconds: Int {
        rawMinutes * 60 / max(1, type.creditDivisor)
    }

    var creditedMinutes: Int {
        creditedSeconds / 60
    }
}


// MARK: - Полётная смена

struct FlightDuty: Identifiable {
    
    let id: UUID
    let legs: [FlightLeg]
    
    private let timelines: [FlightTimeline]
    
    
    init(
        id: UUID,
        legs: [FlightLeg],
        timelines: [FlightTimeline]? = nil
    ) {
        
        self.id = id
        self.legs = legs
        self.timelines =
        timelines
        ??
        legs.map {
            makeTimeline(
                for: $0
            )
        }
    }
    
    
    var firstLeg: FlightLeg {
        legs.first!
    }
    
    
    
    
    var start: Date {
        timelines.first!.workStart
    }
    
    
    var end: Date {
        let last = timelines.last!
        return last.workEnd
            ?? moscowCalendar.date(byAdding: .minute, value: 30, to: last.engineOff)!
    }

    // One assignment may contain several work periods separated by rest.
    var workIntervals: [(start: Date, end: Date)] {
        timelines.indices.map { index in
            let item = timelines[index]
            let periodEnd: Date
            if index == timelines.count - 1 {
                periodEnd = end
            } else if let actual = item.workEnd {
                periodEnd = actual
            } else {
                let nextStart = timelines[index + 1].workStart
                let connects = abs(signedMinutesBetween(item.engineOff, nextStart)) <= 5
                periodEnd = connects ? item.engineOff :
                    moscowCalendar.date(byAdding: .minute, value: 30, to: item.engineOff)!
            }
            return (start: item.workStart, end: max(item.workStart, periodEnd))
        }
    }

    var workMinutes: Int {
        workIntervals.reduce(0) { $0 + minutesBetween($1.start, $1.end) }
    }

    var restMinutes: Int {
        guard workIntervals.count > 1 else { return 0 }
        return zip(workIntervals, workIntervals.dropFirst()).reduce(0) { total, pair in
            total + minutesBetween(pair.0.end, pair.1.start)
        }
    }
    
    
    var flightMinutes: Int {
        
        timelines.reduce(0) {
            $0
            +
            minutesBetween(
                $1.engineOn,
                $1.engineOff
            )
        }
    }
    
    
    var airMinutes: Int {
        
        timelines.reduce(0) {
            $0
            +
            minutesBetween(
                $1.takeoff,
                $1.landing
            )
        }
    }
    
    
    var flightNightMinutes: Int {
        
        timelines.reduce(0) {
            $0
            +
            nightMinutes(
                from: $1.engineOn,
                to: $1.engineOff
            )
        }
    }
    
    
    var airNightMinutes: Int {
        
        timelines.reduce(0) {
            $0
            +
            nightMinutes(
                from: $1.takeoff,
                to: $1.landing
            )
        }
    }
    
    
    var routeText: String {
        
        guard let first =
                legs.first
                
        else {
            return ""
        }
        
        
        var airports =
        [first.departure]
        
        
        for leg in legs {
            
            airports.append(
                leg.arrival
            )
        }
        
        
        return airports.joined(
            separator: " → "
        )
    }
}

// MARK: - Итоги одного дня

struct DailyTimeTotals {

    var flightMinutes = 0
    var airMinutes = 0

    var flightWorkMinutes = 0
    /// Наземная работа в секундах: резерв дома делится на 4 с точностью до секунды (D37).
    var groundWorkSeconds = 0

    var flightNightMinutes = 0
    var airNightMinutes = 0

    var groundWorkMinutes: Int {
        groundWorkSeconds / 60
    }

    var workSeconds: Int {
        flightWorkMinutes * 60 + groundWorkSeconds
    }

    var workMinutes: Int {
        workSeconds / 60
    }

    static var zero: DailyTimeTotals {
        DailyTimeTotals()
    }

    mutating func add(_ other: DailyTimeTotals) {
        flightMinutes += other.flightMinutes
        airMinutes += other.airMinutes
        flightWorkMinutes += other.flightWorkMinutes
        groundWorkSeconds += other.groundWorkSeconds
        flightNightMinutes += other.flightNightMinutes
        airNightMinutes += other.airNightMinutes
    }
}


// MARK: - Подготовленные данные приложения

private struct PreparedFlightLeg {
    
    let flight: FlightLeg
    let timeline: FlightTimeline
}


private struct PreparedWorkEvent {
    
    let event: WorkEvent
    let start: Date
    let end: Date
}


private struct AppDerivedData {
    
    let duties: [FlightDuty]
    let dailyIndex: [Int: DailyTimeTotals]
    let flightsByDay: [Int: [FlightLeg]]
    let workEventsByDay: [Int: [WorkEvent]]
    let latestActivityDate: Date?
}


// MARK: - Хранилище приложения

final class AppStore: ObservableObject {
    
    private var isRestoring = true
    
    
    @Published var flights: [FlightLeg] = [] {
        didSet {
            guard !isRestoring else {
                return
            }
            
            rebuildDerivedData()
            saveFlights()
        }
    }
    
    
    @Published var workEvents: [WorkEvent] = [] {
        didSet {
            guard !isRestoring else {
                return
            }
            
            rebuildDerivedData()
            saveWorkEvents()
        }
    }
    
    
    private var cachedDuties: [FlightDuty] = []
    private var cachedDailyIndex: [Int: DailyTimeTotals] = [:]
    private var cachedFlightsByDay: [Int: [FlightLeg]] = [:]
    private var cachedWorkEventsByDay: [Int: [WorkEvent]] = [:]
    private var cachedLatestActivityDate: Date?
    private(set) var historyFlightKeys: Set<String> = []
    
    
    private let flightsKey =
    "savedFlightLegs"
    
    
    private let workEventsKey =
    "savedWorkEvents"
    
    
    init() {
        
        _ =
        loadFlights()
        
        
        _ =
        loadWorkEvents()
        
        
        isRestoring =
        false
        
        
        rebuildDerivedData()
    }
    
    
    var duties: [FlightDuty] {
        cachedDuties
    }
    
    
    var dailyIndex: [Int: DailyTimeTotals] {
        cachedDailyIndex
    }
    
    
    var flightsByDay: [Int: [FlightLeg]] {
        cachedFlightsByDay
    }
    
    
    var workEventsByDay: [Int: [WorkEvent]] {
        cachedWorkEventsByDay
    }
    
    
    var latestActivityDate: Date? {
        cachedLatestActivityDate
    }
    
    
    /// Сопоставляет строки выгрузки портала с уже сохранёнными легами.
    /// 1) по ключу портала; 2) для легов, исправленных до появления `portalKey`, —
    /// по номеру задания и рейса лега рядом по времени (D08), при равенстве — тот,
    /// у которого совпадает маршрут. Каждый сохранённый лег используется один раз.
    private func matchImported(_ candidates: [FlightLeg]) -> [Int?] {
        var byKey: [String: Int] = [:]
        for (index, flight) in flights.enumerated() { byKey[flight.historyKey] = index }
        var claimed = Set<Int>()
        var result = [Int?](repeating: nil, count: candidates.count)
        for (position, candidate) in candidates.enumerated() {
            if let index = byKey[candidate.historyKey], claimed.insert(index).inserted {
                result[position] = index
            }
        }
        for (position, candidate) in candidates.enumerated() where result[position] == nil {
            guard let assignment = candidate.assignmentNumber, !assignment.isEmpty,
                  let leg = candidate.legNumber,
                  let start = candidate.portalTimes?.workStart else { continue }
            let options = flights.indices.filter { index in
                let saved = flights[index]
                guard !claimed.contains(index),
                      saved.assignmentNumber == assignment,
                      saved.legNumber == leg,
                      let savedStart = saved.portalTimes?.workStart else { return false }
                return abs(savedStart.timeIntervalSince(start)) < 48 * 3600
            }
            let sameRoute = options.first {
                flights[$0].departure == candidate.departure && flights[$0].arrival == candidate.arrival
            }
            if let index = sameRoute ?? (options.count == 1 ? options[0] : nil) {
                claimed.insert(index)
                result[position] = index
            }
        }
        return result
    }

    func countNewImported(_ candidates: [FlightLeg]) -> Int {
        let matches = matchImported(candidates)
        var seen = Set<String>()
        return candidates.indices.filter { position in
            seen.insert(candidates[position].historyKey).inserted && matches[position] == nil
        }.count
    }

    func importFlights(_ candidates: [FlightLeg]) -> (added: Int, updated: Int) {
        let matches = matchImported(candidates)
        var updatedFlights = flights
        var known = Set(flights.map { $0.historyKey })
        var incoming: [FlightLeg] = []
        var refreshed = 0
        for (position, candidate) in candidates.enumerated() {
            let key = candidate.historyKey
            if let index = matches[position] {
                known.insert(key)
                guard updatedFlights[index].portalTimes != nil else { continue }
                var saved = updatedFlights[index]
                if saved.portalKey == nil, candidate.portalTimes != nil { saved.portalKey = key }
                if saved.assignmentNumber == nil { saved.assignmentNumber = candidate.assignmentNumber }
                if saved.legNumber == nil { saved.legNumber = candidate.legNumber }
                if saved.scheduleType == nil { saved.scheduleType = candidate.scheduleType }
                if saved != updatedFlights[index] {
                    updatedFlights[index] = saved
                    refreshed += 1
                }
            } else if known.insert(key).inserted {
                incoming.append(candidate)
            }
        }
        if !incoming.isEmpty || refreshed > 0 { flights = incoming + updatedFlights }
        return (incoming.count, refreshed)
    }

    func addDutyLegs(_ legs: [FlightLeg]) {
        guard !legs.isEmpty else { return }
        flights = legs + flights
    }
    
    
    
    
    // One assignment is committed in a single published change.
    func updateDutyLegs(_ updated: [FlightLeg]) {
        let replacements = Dictionary(
            uniqueKeysWithValues: updated.map { ($0.id, $0) }
        )
        flights = flights.map { replacements[$0.id] ?? $0 }
    }

    func deleteDutyLegs(ids: Set<UUID>) {
        flights.removeAll { ids.contains($0.id) }
    }

    func addWorkEvent(
        _ event: WorkEvent
    ) {
        
        workEvents.insert(
            event,
            at: 0
        )
    }
    
    
    func updateWorkEvent(
        _ event: WorkEvent
    ) {
        
        guard let index =
                workEvents.firstIndex(
                    where: {
                        $0.id == event.id
                    }
                )
        else {
            return
        }
        
        
        var updatedEvents =
        workEvents
        
        
        updatedEvents[index] =
        event
        
        
        workEvents =
        updatedEvents
    }
    
    
    func deleteWorkEvent(
        id: UUID
    ) {
        
        workEvents.removeAll {
            $0.id == id
        }
    }
    
    
    func deleteAll() {
        
        flights.removeAll()
        
        workEvents.removeAll()
    }
    
    
    private func rebuildDerivedData() {
        
        let derived =
        buildAppDerivedData(
            flights: flights,
            workEvents: workEvents
        )
        
        
        cachedDuties =
        derived.duties
        
        
        cachedDailyIndex =
        derived.dailyIndex
        
        
        cachedFlightsByDay =
        derived.flightsByDay
        
        
        cachedWorkEventsByDay =
        derived.workEventsByDay
        
        
        cachedLatestActivityDate =
        derived.latestActivityDate

        historyFlightKeys = makeHistoryFlightKeys(flights)
    }
    
    
    private func saveFlights() {
        StorageSafety.store(flights, key: flightsKey, title: "История рейсов")
    }


    private func saveWorkEvents() {
        StorageSafety.store(workEvents, key: workEventsKey, title: "План работ")
    }


    private func loadFlights() -> Bool {
        
        guard
            let data =
                UserDefaults.standard.data(
                    forKey:
                        flightsKey
                )
                
        else {
            
            return false
        }
        
        
        do {
            
            flights =
            try JSONDecoder()
                .decode(
                    [FlightLeg].self,
                    from: data
                )
            
            return true
            
        } catch {
            StorageSafety.preserveUnreadable(
                data, key: flightsKey, title: "История рейсов", error: error
            )
            return false
        }
    }
    
    
    private func loadWorkEvents() -> Bool {
        
        guard
            let data =
                UserDefaults.standard.data(
                    forKey:
                        workEventsKey
                )
                
        else {
            
            return false
        }
        
        
        do {
            
            workEvents =
            try JSONDecoder()
                .decode(
                    [WorkEvent].self,
                    from: data
                )
            
            return true
            
        } catch {
            StorageSafety.preserveUnreadable(
                data, key: workEventsKey, title: "План работ", error: error
            )
            return false
        }
    }
}



// MARK: - Даты

func makeValidatedTimeline(
    for flight: FlightLeg
) -> FlightTimeline? {
    if let portal = flight.portalTimes {
        guard portal.workStart <= portal.engineOn,
              portal.engineOn <= portal.takeoff,
              portal.takeoff <= portal.landing,
              portal.landing <= portal.engineOff,
              portal.engineOff <= portal.workEnd else { return nil }
        return FlightTimeline(
            plannedDeparture: portal.engineOn,
            workStart: portal.workStart, engineOn: portal.engineOn,
            takeoff: portal.takeoff, landing: portal.landing,
            engineOff: portal.engineOff, workEnd: portal.workEnd
        )
    }
    
    guard
        var workStart =
            parsedDate(
                date:
                    flight.date,
                time:
                    flight.workStart
            ),
        var engineOn =
            parsedDate(
                date:
                    flight.date,
                time:
                    flight.engineOn
            ),
        var takeoff =
            parsedDate(
                date:
                    flight.date,
                time:
                    flight.takeoff
            ),
        var landing =
            parsedDate(
                date:
                    flight.date,
                time:
                    flight.landing
            ),
        var engineOff =
            parsedDate(
                date:
                    flight.date,
                time:
                    flight.engineOff
            )
    else {
        return nil
    }
    
    
    let planned = parsedDate(date: flight.date, time: flight.plannedDeparture) ?? engineOn

    if workStart > planned {
        
        workStart =
        moscowCalendar.date(
            byAdding: .day,
            value: -1,
            to: workStart
        )!
    }
    
    
    while engineOn < workStart {
        
        engineOn =
        moscowCalendar.date(
            byAdding: .day,
            value: 1,
            to: engineOn
        )!
    }
    
    
    while takeoff < engineOn {
        
        takeoff =
        moscowCalendar.date(
            byAdding: .day,
            value: 1,
            to: takeoff
        )!
    }
    
    
    while landing < takeoff {
        
        landing =
        moscowCalendar.date(
            byAdding: .day,
            value: 1,
            to: landing
        )!
    }
    
    
    while engineOff < landing {
        
        engineOff =
        moscowCalendar.date(
            byAdding: .day,
            value: 1,
            to: engineOff
        )!
    }
    
    
    return FlightTimeline(
        plannedDeparture:
            planned,
        workStart:
            workStart,
        engineOn:
            engineOn,
        takeoff:
            takeoff,
        landing:
            landing,
        engineOff:
            engineOff,
        workEnd: nil
    )
}


func makeTimeline(
    for flight: FlightLeg
) -> FlightTimeline {
    
    guard
        let timeline =
            makeValidatedTimeline(
                for:
                    flight
            )
    else {
        
        return FlightTimeline(
            plannedDeparture:
                invalidStoredDatePlaceholder,
            workStart:
                invalidStoredDatePlaceholder,
            engineOn:
                invalidStoredDatePlaceholder,
            takeoff:
                invalidStoredDatePlaceholder,
            landing:
                invalidStoredDatePlaceholder,
            engineOff:
                invalidStoredDatePlaceholder,
            workEnd: nil
        )
    }
    
    
    return timeline
}


extension FlightLeg {
    static func portalKey(for source: PortalFlightTimes) -> String {
        "portal|" + [source.workStart, source.engineOn, source.takeoff,
                     source.landing, source.engineOff, source.workEnd]
            .map { String(Int($0.timeIntervalSince1970 / 60)) }
            .joined(separator: "|")
    }

    var historyKey: String {
        if let portalKey { return portalKey }
        if let source = portalTimes {
            return FlightLeg.portalKey(for: source)
        }
        let t = timeline
        return [flightNumber, departure, arrival, registration,
                String(Int(t.engineOn.timeIntervalSince1970 / 60)),
                String(Int(t.engineOff.timeIntervalSince1970 / 60))].joined(separator: "|")
    }
    
    var validatedTimeline:
    FlightTimeline? {
        
        makeValidatedTimeline(
            for:
                self
        )
    }
    
    
    var hasValidStoredDates: Bool {
        validatedTimeline != nil
    }
    
    
    var timeline: FlightTimeline {
        
        makeTimeline(
            for:
                self
        )
    }
    
    
    var flightMinutes: Int {
        
        minutesBetween(
            timeline.engineOn,
            timeline.engineOff
        )
    }

    var workMinutes: Int {
        guard let t = validatedTimeline else { return 0 }
        let end = t.workEnd
            ?? moscowCalendar.date(byAdding: .minute, value: 30, to: t.engineOff)!
        return minutesBetween(t.workStart, end)
    }

    var calculatedMinutes: Int? {
        if let calculatedMinutesOverride {
            return max(0, calculatedMinutesOverride)
        }
        if scheduleType == .unscheduled { return flightMinutes }
        return nil
    }

    var displayedLegNumber: String {
        legNumber ?? flightNumber
    }
    
    
    var airMinutes: Int {
        
        minutesBetween(
            timeline.takeoff,
            timeline.landing
        )
    }
    
    
    var flightNightMinutes: Int {
        
        nightMinutes(
            from:
                timeline.engineOn,
            to:
                timeline.engineOff
        )
    }
    
    
    var airNightMinutes: Int {
        
        nightMinutes(
            from:
                timeline.takeoff,
            to:
                timeline.landing
        )
    }
}


// MARK: - Индекс выполненных рейсов

/// «день|номер» для рейсов истории с портала. План сверяется с историей по этому
/// индексу, а не перебором всех легов в каждой строке списка (аудит 05.10, п. 16).
func historyFlightKey(day: Date, number: String) -> String {
    "\(dayKey(day))|\(number)"
}


private func makeHistoryFlightKeys(_ flights: [FlightLeg]) -> Set<String> {
    var keys = Set<String>()
    for flight in flights {
        guard let engineOn = flight.portalTimes?.engineOn else { continue }
        var numbers = canonicalFlightNumbers(in: flight.flightNumber)
        if let leg = flight.legNumber {
            numbers.append(contentsOf: canonicalFlightNumbers(in: leg))
        }
        for number in numbers where !number.isEmpty {
            keys.insert(historyFlightKey(day: engineOn, number: number))
        }
    }
    return keys
}


// MARK: - Подготовка производных данных

private func buildAppDerivedData(
    flights: [FlightLeg],
    workEvents: [WorkEvent]
) -> AppDerivedData {
    
    let preparedFlights:
    [PreparedFlightLeg] =
    flights.compactMap {
        flight -> PreparedFlightLeg? in
        
        guard
            let timeline =
                makeValidatedTimeline(
                    for:
                        flight
                )
        else {
            return nil
        }
        
        
        return PreparedFlightLeg(
            flight:
                flight,
            timeline:
                timeline
        )
    }
    
    
    let preparedWorkEvents:
    [PreparedWorkEvent] =
    workEvents.compactMap {
        event -> PreparedWorkEvent? in
        
        guard
            let range =
                event.validatedDateRange
        else {
            return nil
        }
        
        
        return PreparedWorkEvent(
            event:
                event,
            start:
                range.start,
            end:
                range.end
        )
    }
    
    
    let duties =
    buildFlightDuties(
        fromPrepared:
            preparedFlights
    )
    
    
    var dailyIndex:
    [Int: DailyTimeTotals] = [:]
    
    
    var flightsByDay:
    [Int: [FlightLeg]] = [:]
    
    
    for item in preparedFlights {
        
        for day in touchedDays(
            from:
                item.timeline.engineOn,
            to:
                item.timeline.engineOff
        ) {
            
            let key =
            dayKey(day)
            
            
            flightsByDay[
                key,
                default: []
            ]
                .append(
                    item.flight
                )
            
            
            var totals =
            dailyIndex[key]
            ?? .zero
            
            
            totals.flightMinutes +=
            minutesInDay(
                from:
                    item.timeline.engineOn,
                to:
                    item.timeline.engineOff,
                day:
                    day
            )
            
            
            totals.airMinutes +=
            minutesInDay(
                from:
                    item.timeline.takeoff,
                to:
                    item.timeline.landing,
                day:
                    day
            )
            
            
            totals.flightNightMinutes +=
            nightMinutesInDay(
                from:
                    item.timeline.engineOn,
                to:
                    item.timeline.engineOff,
                day:
                    day
            )
            
            
            totals.airNightMinutes +=
            nightMinutesInDay(
                from:
                    item.timeline.takeoff,
                to:
                    item.timeline.landing,
                day:
                    day
            )
            
            
            dailyIndex[key] =
            totals
        }
    }
    
    
    for duty in duties {
        for period in duty.workIntervals {
        for day in touchedDays(
            from:
                period.start,
            to:
                period.end
        ) {
            
            let key =
            dayKey(day)
            
            
            var totals =
            dailyIndex[key]
            ?? .zero
            
            
            totals.flightWorkMinutes +=
            minutesInDay(
                from:
                    period.start,
                to:
                    period.end,
                day:
                    day
            )
            
            
            dailyIndex[key] =
            totals
        }
        }
    }
    
    
    var workEventsByDay:
    [Int: [WorkEvent]] = [:]
    
    
    for item in preparedWorkEvents {
        
        for day in touchedDays(
            from:
                item.start,
            to:
                item.end
        ) {
            
            let key =
            dayKey(day)
            
            
            workEventsByDay[
                key,
                default: []
            ]
                .append(
                    item.event
                )
            
            
            var totals =
            dailyIndex[key]
            ?? .zero
            
            
            totals.groundWorkSeconds +=
            creditedWorkSeconds(
                start: item.start,
                end: item.end,
                type: item.event.type,
                day: day
            )
            
            
            dailyIndex[key] =
            totals
        }
    }
    
    
    let flightDates =
    preparedFlights.map {
        $0.timeline.engineOff
    }
    
    
    let workDates =
    preparedWorkEvents.map {
        $0.end
    }
    
    
    return AppDerivedData(
        duties:
            duties,
        dailyIndex:
            dailyIndex,
        flightsByDay:
            flightsByDay,
        workEventsByDay:
            workEventsByDay,
        latestActivityDate:
            (flightDates + workDates)
                .max()
    )
}


// MARK: - Полётные смены

private func buildFlightDuties(
    fromPrepared flights: [PreparedFlightLeg]
) -> [FlightDuty] {
    func duty(_ items: [PreparedFlightLeg]) -> FlightDuty {
        let ordered = items.sorted { $0.timeline.workStart < $1.timeline.workStart }
        return FlightDuty(
            id: ordered[0].flight.id,
            legs: ordered.map { $0.flight },
            timelines: ordered.map { $0.timeline }
        )
    }

    let assigned = flights.filter { !($0.flight.assignmentNumber ?? "").isEmpty }
    let grouped = Dictionary(grouping: assigned) { $0.flight.assignmentNumber! }
    var result = grouped.values.map(duty)

    let legacy = flights
        .filter { ($0.flight.assignmentNumber ?? "").isEmpty }
        .sorted { $0.timeline.workStart < $1.timeline.workStart }
    var current: [PreparedFlightLeg] = []

    for item in legacy {
        if let previous = current.last {
            let gap = signedMinutesBetween(previous.timeline.engineOff, item.timeline.workStart)
            let connects = previous.flight.arrival == item.flight.departure
                && (-5...5).contains(gap)
            if !connects {
                result.append(duty(current))
                current = []
            }
        }
        current.append(item)
    }
    if !current.isEmpty { result.append(duty(current)) }

    return result.sorted { $0.start > $1.start }
}


// MARK: - Зачёт наземной работы по суткам (резерв дома — 1/4, D37)

func creditedWorkSeconds(
    start: Date,
    end: Date,
    type: WorkEventType,
    day: Date
) -> Int {
    creditedSecondsInDay(
        start: start,
        end: end,
        divisor: type.creditDivisor,
        day: day
    )
}


func creditedWorkSeconds(
    event: WorkEvent,
    day: Date
) -> Int {
    guard let range = event.validatedDateRange else { return 0 }
    return creditedWorkSeconds(
        start: range.start,
        end: range.end,
        type: event.type,
        day: day
    )
}


// MARK: - Месяцы

func startOfMonth(
    _ date: Date
) -> Date {
    
    let components =
    moscowCalendar
        .dateComponents(
            [
                .year,
                .month
            ],
            from:
                date
        )
    
    
    return
    moscowCalendar.date(
        from:
            components
    )!
}


func daysInMonth(
    _ month: Date
) -> [Date] {
    
    let start =
    startOfMonth(
        month
    )
    
    
    guard
        let range =
            moscowCalendar.range(
                of: .day,
                in: .month,
                for: start
            )
            
    else {
        return []
    }
    
    
    return range.compactMap {
        
        moscowCalendar.date(
            byAdding: .day,
            value: $0 - 1,
            to: start
        )
    }
}


func calendarOffset(
    for month: Date
) -> Int {
    
    let weekday =
    moscowCalendar.component(
        .weekday,
        from:
            startOfMonth(
                month
            )
    )
    
    
    return
    (weekday + 5)
    % 7
}


func changeMonth(
    _ month: Date,
    by value: Int
) -> Date {
    
    moscowCalendar.date(
        byAdding: .month,
        value: value,
        to:
            startOfMonth(
                month
            )
    )!
}


func monthTotals(
    month: Date,
    index:
    [Int: DailyTimeTotals]
) -> DailyTimeTotals {
    
    var total =
    DailyTimeTotals.zero
    
    
    for day in daysInMonth(
        month
    ) {
        
        if let value =
            index[
                dayKey(
                    day
                )
            ] {
            
            total.add(
                value
            )
        }
    }
    
    
    return total
}


// MARK: - Выходные

func isWeekend(
    _ date: Date
) -> Bool {
    
    let weekday =
    moscowCalendar.component(
        .weekday,
        from:
            date
    )
    
    
    return
    weekday == 1
    ||
    weekday == 7
}


// MARK: - Форматирование

/// Время с секундами только если они есть (D37): 02:00 или 02:00:15.
func durationText(_ seconds: Int) -> String {
    let value = max(0, seconds)
    let base = String(format: "%02d:%02d", value / 3600, (value % 3600) / 60)
    let rest = value % 60
    return rest == 0 ? base : base + String(format: ":%02d", rest)
}


func timeText(
    _ minutes: Int
) -> String {
    
    let hours =
    minutes / 60
    
    
    let mins =
    minutes % 60
    
    
    return String(
        format:
            "%02d:%02d",
        hours,
        mins
    )
}


func formatDate(
    _ date: Date
) -> String {
    
    dateFormatter.string(
        from:
            date
    )
}


func formatClock(
    _ date: Date
) -> String {
    
    clockFormatter.string(
        from:
            date
    )
}


func formatDateTime(
    _ date: Date
) -> String {
    
    dateTimeFormatter.string(
        from:
            date
    )
}


func monthTitle(
    _ date: Date
) -> String {
    
    let value =
    monthFormatter.string(
        from:
            date
    )
    
    
    return
    value.prefix(1)
        .uppercased()
    +
    value.dropFirst()
}


func longDateTitle(
    _ date: Date
) -> String {
    
    longDateFormatter.string(
        from:
            date
    )
}


func weekdayName(
    _ date: Date
) -> String {
    
    let value =
    weekdayFormatter.string(
        from:
            date
    )
    
    
    return
    value.prefix(1)
        .uppercased()
    +
    value.dropFirst()
}
