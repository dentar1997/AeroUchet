import SwiftUI
import Foundation


// MARK: - Московское время

let moscowTimeZone = TimeZone(identifier: "Europe/Moscow")!

var moscowCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = moscowTimeZone
    calendar.firstWeekday = 2
    return calendar
}


// MARK: - Форматтеры

let parserFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = moscowTimeZone
    formatter.dateFormat = "dd.MM.yyyy HH:mm"
    return formatter
}()

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
        engineOff: String
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
    }
}


// MARK: - Хронология лега

struct FlightTimeline {
    
    let plannedDeparture: Date
    
    let workStart: Date
    
    let engineOn: Date
    let takeoff: Date
    let landing: Date
    let engineOff: Date
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
    
    
    var startDate: Date {
        
        parseDate(
            date: date,
            time: startTime
        )
    }
    
    
    var endDate: Date {
        
        let start =
        startDate
        
        
        var end =
        parseDate(
            date: date,
            time: endTime
        )
        
        
        if end < start {
            
            end =
            moscowCalendar.date(
                byAdding: .day,
                value: 1,
                to: end
            )!
        }
        
        
        return end
    }
    
    
    var rawMinutes: Int {
        
        minutesBetween(
            startDate,
            endDate
        )
    }
    
    
    var creditedMinutes: Int {
        
        rawMinutes
        /
        type.creditDivisor
    }
    
    
    var rawNightMinutes: Int {
        
        nightMinutes(
            from: startDate,
            to: endDate
        )
    }
    
    
    var creditedNightMinutes: Int {
        
        rawNightMinutes
        /
        type.creditDivisor
    }
}


// MARK: - Полётная смена

struct FlightDuty: Identifiable {
    
    let id: UUID
    let legs: [FlightLeg]
    
    private let timelines: [FlightTimeline]
    
    
    init(
        id: UUID,
        legs: [FlightLeg]
    ) {
        
        self.id = id
        self.legs = legs
        self.timelines =
        legs.map {
            makeTimeline(
                for: $0
            )
        }
    }
    
    
    var firstLeg: FlightLeg {
        legs.first!
    }
    
    
    var lastLeg: FlightLeg {
        legs.last!
    }
    
    
    var start: Date {
        timelines.first!.workStart
    }
    
    
    var end: Date {
        
        moscowCalendar.date(
            byAdding: .minute,
            value: 30,
            to: timelines.last!.engineOff
        )!
    }
    
    
    var workMinutes: Int {
        
        minutesBetween(
            start,
            end
        )
    }
    
    
    var workNightMinutes: Int {
        
        nightMinutes(
            from: start,
            to: end
        )
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
    var groundWorkMinutes = 0
    
    var flightNightMinutes = 0
    var airNightMinutes = 0
    
    var flightWorkNightMinutes = 0
    var groundWorkNightMinutes = 0
    
    
    var workMinutes: Int {
        
        flightWorkMinutes
        +
        groundWorkMinutes
    }
    
    
    var workNightMinutes: Int {
        
        flightWorkNightMinutes
        +
        groundWorkNightMinutes
    }
    
    
    static var zero: DailyTimeTotals {
        
        DailyTimeTotals()
    }
    
    
    mutating func add(
        _ other: DailyTimeTotals
    ) {
        
        flightMinutes +=
        other.flightMinutes
        
        airMinutes +=
        other.airMinutes
        
        flightWorkMinutes +=
        other.flightWorkMinutes
        
        groundWorkMinutes +=
        other.groundWorkMinutes
        
        flightNightMinutes +=
        other.flightNightMinutes
        
        airNightMinutes +=
        other.airNightMinutes
        
        flightWorkNightMinutes +=
        other.flightWorkNightMinutes
        
        groundWorkNightMinutes +=
        other.groundWorkNightMinutes
    }
}


// MARK: - Хранилище приложения

final class AppStore: ObservableObject {
    
    @Published var flights: [FlightLeg] = [] {
        didSet {
            rebuildDerivedData()
            saveFlights()
        }
    }
    
    
    @Published var workEvents: [WorkEvent] = [] {
        didSet {
            rebuildDerivedData()
            saveWorkEvents()
        }
    }
    
    
    private var cachedDuties: [FlightDuty] = []
    private var cachedDailyIndex: [Int: DailyTimeTotals] = [:]
    private var cachedFlightsByDay: [Int: [FlightLeg]] = [:]
    private var cachedWorkEventsByDay: [Int: [WorkEvent]] = [:]
    private var cachedLatestActivityDate: Date?
    
    
    private let flightsKey =
    "savedFlightLegs"
    
    
    private let workEventsKey =
    "savedWorkEvents"
    
    
    init() {
        
        _ =
        loadFlights()
        
        
        _ =
        loadWorkEvents()
        
        
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
    
    
    func addFlight(
        _ flight: FlightLeg
    ) {
        
        flights.insert(
            flight,
            at: 0
        )
    }
    
    
    func updateFlight(
        _ flight: FlightLeg
    ) {
        
        guard let index =
                flights.firstIndex(
                    where: {
                        $0.id == flight.id
                    }
                )
        else {
            return
        }
        
        
        var updatedFlights =
        flights
        
        
        updatedFlights[index] =
        flight
        
        
        flights =
        updatedFlights
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
    
    
    func deleteFlight(
        id: UUID
    ) {
        
        flights.removeAll {
            $0.id == id
        }
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
        
        let duties =
        buildFlightDuties(
            from: flights
        )
        
        
        cachedDuties =
        duties
        
        
        cachedDailyIndex =
        buildDailyIndex(
            flights: flights,
            duties: duties,
            workEvents: workEvents
        )
        
        
        cachedFlightsByDay =
        buildFlightsByDay(
            flights: flights
        )
        
        
        cachedWorkEventsByDay =
        buildWorkEventsByDay(
            events: workEvents
        )
        
        
        let flightDates =
        flights.map {
            $0.timeline.engineOff
        }
        
        
        let workDates =
        workEvents.map {
            $0.endDate
        }
        
        
        cachedLatestActivityDate =
        (flightDates + workDates)
            .max()
    }
    
    
    private func saveFlights() {
        
        do {
            
            let data =
            try JSONEncoder()
                .encode(
                    flights
                )
            
            
            UserDefaults.standard.set(
                data,
                forKey:
                    flightsKey
            )
            
        } catch {
            
            print(
                "ÐÑÐ¸Ð±ÐºÐ° ÑÐ¾ÑÑÐ°Ð½ÐµÐ½Ð¸Ñ ÑÐµÐ¹ÑÐ¾Ð²:",
                error
            )
        }
    }
    
    
    private func saveWorkEvents() {
        
        do {
            
            let data =
            try JSONEncoder()
                .encode(
                    workEvents
                )
            
            
            UserDefaults.standard.set(
                data,
                forKey:
                    workEventsKey
            )
            
        } catch {
            
            print(
                "ÐÑÐ¸Ð±ÐºÐ° ÑÐ¾ÑÑÐ°Ð½ÐµÐ½Ð¸Ñ Ð¿Ð»Ð°Ð½Ð° ÑÐ°Ð±Ð¾Ñ:",
                error
            )
        }
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
            
            print(
                "ÐÑÐ¸Ð±ÐºÐ° Ð·Ð°Ð³ÑÑÐ·ÐºÐ¸ ÑÐµÐ¹ÑÐ¾Ð²:",
                error
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
            
            print(
                "ÐÑÐ¸Ð±ÐºÐ° Ð·Ð°Ð³ÑÑÐ·ÐºÐ¸ Ð¿Ð»Ð°Ð½Ð° ÑÐ°Ð±Ð¾Ñ:",
                error
            )
            
            return false
        }
    }
}



// MARK: - Даты

func parseDate(
    date: String,
    time: String
) -> Date {
    
    parserFormatter.date(
        from:
            "\(date) \(time)"
    )
    ?? Date()
}


func makeTimeline(
    for flight: FlightLeg
) -> FlightTimeline {
    
    let planned =
    parseDate(
        date:
            flight.date,
        time:
            flight.plannedDeparture
    )
    
    
    var workStart =
    parseDate(
        date:
            flight.date,
        time:
            flight.workStart
    )
    
    
    if workStart > planned {
        
        workStart =
        moscowCalendar.date(
            byAdding: .day,
            value: -1,
            to: workStart
        )!
    }
    
    
    var engineOn =
    parseDate(
        date:
            flight.date,
        time:
            flight.engineOn
    )
    
    
    while engineOn < workStart {
        
        engineOn =
        moscowCalendar.date(
            byAdding: .day,
            value: 1,
            to: engineOn
        )!
    }
    
    
    var takeoff =
    parseDate(
        date:
            flight.date,
        time:
            flight.takeoff
    )
    
    
    while takeoff < engineOn {
        
        takeoff =
        moscowCalendar.date(
            byAdding: .day,
            value: 1,
            to: takeoff
        )!
    }
    
    
    var landing =
    parseDate(
        date:
            flight.date,
        time:
            flight.landing
    )
    
    
    while landing < takeoff {
        
        landing =
        moscowCalendar.date(
            byAdding: .day,
            value: 1,
            to: landing
        )!
    }
    
    
    var engineOff =
    parseDate(
        date:
            flight.date,
        time:
            flight.engineOff
    )
    
    
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
            engineOff
    )
}


extension FlightLeg {
    
    var timeline: FlightTimeline {
        
        makeTimeline(
            for: self
        )
    }
    
    
    var flightMinutes: Int {
        
        minutesBetween(
            timeline.engineOn,
            timeline.engineOff
        )
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


// MARK: - Работа со временем

func minutesBetween(
    _ start: Date,
    _ end: Date
) -> Int {
    
    max(
        0,
        Int(
            end.timeIntervalSince(
                start
            )
            /
            60
        )
    )
}


func signedMinutesBetween(
    _ start: Date,
    _ end: Date
) -> Int {
    
    Int(
        end.timeIntervalSince(
            start
        )
        /
        60
    )
}


func overlapMinutes(
    start1: Date,
    end1: Date,
    start2: Date,
    end2: Date
) -> Int {
    
    let start =
    max(
        start1,
        start2
    )
    
    
    let end =
    min(
        end1,
        end2
    )
    
    
    guard end > start
    else {
        return 0
    }
    
    
    return minutesBetween(
        start,
        end
    )
}


func minutesInDay(
    from start: Date,
    to end: Date,
    day: Date
) -> Int {
    
    let dayStart =
    moscowCalendar
        .startOfDay(
            for: day
        )
    
    
    let nextDay =
    moscowCalendar.date(
        byAdding: .day,
        value: 1,
        to: dayStart
    )!
    
    
    return overlapMinutes(
        start1:
            start,
        end1:
            end,
        start2:
            dayStart,
        end2:
            nextDay
    )
}


// MARK: - Ночь

func nightMinutesInDay(
    from start: Date,
    to end: Date,
    day: Date
) -> Int {
    
    let dayStart =
    moscowCalendar
        .startOfDay(
            for: day
        )
    
    
    let sixAM =
    moscowCalendar.date(
        bySettingHour: 6,
        minute: 0,
        second: 0,
        of: dayStart
    )!
    
    
    let tenPM =
    moscowCalendar.date(
        bySettingHour: 22,
        minute: 0,
        second: 0,
        of: dayStart
    )!
    
    
    let nextDay =
    moscowCalendar.date(
        byAdding: .day,
        value: 1,
        to: dayStart
    )!
    
    
    let morning =
    overlapMinutes(
        start1:
            start,
        end1:
            end,
        start2:
            dayStart,
        end2:
            sixAM
    )
    
    
    let evening =
    overlapMinutes(
        start1:
            start,
        end1:
            end,
        start2:
            tenPM,
        end2:
            nextDay
    )
    
    
    return morning + evening
}


func nightMinutes(
    from start: Date,
    to end: Date
) -> Int {
    
    guard end > start
    else {
        return 0
    }
    
    
    var day =
    moscowCalendar
        .startOfDay(
            for: start
        )
    
    
    let lastDay =
    moscowCalendar
        .startOfDay(
            for: end
        )
    
    
    var total = 0
    
    
    while day <= lastDay {
        
        total +=
        nightMinutesInDay(
            from:
                start,
            to:
                end,
            day:
                day
        )
        
        
        day =
        moscowCalendar.date(
            byAdding: .day,
            value: 1,
            to: day
        )!
    }
    
    
    return total
}


// MARK: - Полётные смены

func buildFlightDuties(
    from flights: [FlightLeg]
) -> [FlightDuty] {
    
    let prepared =
    flights
        .map {
            (
                flight: $0,
                timeline:
                    makeTimeline(
                        for: $0
                    )
            )
        }
        .sorted {
            $0.timeline.workStart
            <
            $1.timeline.workStart
        }
    
    
    guard !prepared.isEmpty
    else {
        return []
    }
    
    
    var result:
    [FlightDuty] = []
    
    
    var current:
    [(flight: FlightLeg, timeline: FlightTimeline)] = []
    
    
    for item in prepared {
        
        if current.isEmpty {
            
            current =
            [item]
            
            continue
        }
        
        
        let previous =
        current.last!
        
        
        let difference =
        signedMinutesBetween(
            previous.timeline.engineOff,
            item.timeline.workStart
        )
        
        
        let routeContinues =
        previous.flight.arrival
        ==
        item.flight.departure
        
        
        if routeContinues
            &&
            difference >= -5
            &&
            difference <= 5 {
            
            current.append(
                item
            )
            
        } else {
            
            result.append(
                FlightDuty(
                    id:
                        current.first!.flight.id,
                    legs:
                        current.map {
                            $0.flight
                        }
                )
            )
            
            
            current =
            [item]
        }
    }
    
    
    if !current.isEmpty {
        
        result.append(
            FlightDuty(
                id:
                    current.first!.flight.id,
                legs:
                    current.map {
                        $0.flight
                    }
            )
        )
    }
    
    
    return result.sorted {
        
        $0.start
        >
        $1.start
    }
}


// MARK: - Календарные дни

func dayKey(
    _ date: Date
) -> Int {
    
    let components =
    moscowCalendar
        .dateComponents(
            [
                .year,
                .month,
                .day
            ],
            from:
                date
        )
    
    
    return
    (components.year ?? 0)
    * 10000
    +
    (components.month ?? 0)
    * 100
    +
    (components.day ?? 0)
}


func touchedDays(
    from start: Date,
    to end: Date
) -> [Date] {
    
    guard end > start
    else {
        return []
    }
    
    
    var result:
    [Date] = []
    
    
    var day =
    moscowCalendar
        .startOfDay(
            for: start
        )
    
    
    let adjustedEnd =
    end.addingTimeInterval(
        -1
    )
    
    
    let lastDay =
    moscowCalendar
        .startOfDay(
            for:
                adjustedEnd
        )
    
    
    while day <= lastDay {
        
        result.append(
            day
        )
        
        
        day =
        moscowCalendar.date(
            byAdding: .day,
            value: 1,
            to: day
        )!
    }
    
    
    return result
}


// MARK: - Учёт домашнего резерва по суткам

func creditedWorkMinutes(
    event: WorkEvent,
    day: Date
) -> Int {
    
    let dayStart =
    moscowCalendar.startOfDay(
        for: day
    )
    
    
    let dayEnd =
    moscowCalendar.date(
        byAdding: .day,
        value: 1,
        to: dayStart
    )!
    
    
    let segmentStart =
    max(
        event.startDate,
        dayStart
    )
    
    
    let segmentEnd =
    min(
        event.endDate,
        dayEnd
    )
    
    
    guard segmentEnd > segmentStart
    else {
        return 0
    }
    
    
    let divisor =
    event.type.creditDivisor
    
    
    if divisor == 1 {
        
        return minutesBetween(
            segmentStart,
            segmentEnd
        )
    }
    
    
    let elapsedBefore =
    minutesBetween(
        event.startDate,
        segmentStart
    )
    
    
    let elapsedAfter =
    minutesBetween(
        event.startDate,
        segmentEnd
    )
    
    
    return
    elapsedAfter / divisor
    -
    elapsedBefore / divisor
}


func creditedNightMinutes(
    event: WorkEvent,
    day: Date
) -> Int {
    
    let rawNight =
    nightMinutesInDay(
        from:
            event.startDate,
        to:
            event.endDate,
        day:
            day
    )
    
    
    return
    rawNight
    /
    event.type.creditDivisor
}


// MARK: - Дневной индекс

func buildDailyIndex(
    flights: [FlightLeg],
    duties: [FlightDuty],
    workEvents: [WorkEvent]
) -> [Int: DailyTimeTotals] {
    
    var result:
    [Int: DailyTimeTotals] = [:]
    
    
    for flight in flights {
        
        let timeline =
        flight.timeline
        
        
        for day in touchedDays(
            from:
                timeline.engineOn,
            to:
                timeline.engineOff
        ) {
            
            let key =
            dayKey(
                day
            )
            
            
            var totals =
            result[key]
            ?? .zero
            
            
            totals.flightMinutes +=
            minutesInDay(
                from:
                    timeline.engineOn,
                to:
                    timeline.engineOff,
                day:
                    day
            )
            
            
            totals.airMinutes +=
            minutesInDay(
                from:
                    timeline.takeoff,
                to:
                    timeline.landing,
                day:
                    day
            )
            
            
            totals.flightNightMinutes +=
            nightMinutesInDay(
                from:
                    timeline.engineOn,
                to:
                    timeline.engineOff,
                day:
                    day
            )
            
            
            totals.airNightMinutes +=
            nightMinutesInDay(
                from:
                    timeline.takeoff,
                to:
                    timeline.landing,
                day:
                    day
            )
            
            
            result[key] =
            totals
        }
    }
    
    
    for duty in duties {
        
        for day in touchedDays(
            from:
                duty.start,
            to:
                duty.end
        ) {
            
            let key =
            dayKey(
                day
            )
            
            
            var totals =
            result[key]
            ?? .zero
            
            
            totals.flightWorkMinutes +=
            minutesInDay(
                from:
                    duty.start,
                to:
                    duty.end,
                day:
                    day
            )
            
            
            totals.flightWorkNightMinutes +=
            nightMinutesInDay(
                from:
                    duty.start,
                to:
                    duty.end,
                day:
                    day
            )
            
            
            result[key] =
            totals
        }
    }
    
    
    for event in workEvents {
        
        for day in touchedDays(
            from:
                event.startDate,
            to:
                event.endDate
        ) {
            
            let key =
            dayKey(
                day
            )
            
            
            var totals =
            result[key]
            ?? .zero
            
            
            totals.groundWorkMinutes +=
            creditedWorkMinutes(
                event:
                    event,
                day:
                    day
            )
            
            
            totals.groundWorkNightMinutes +=
            creditedNightMinutes(
                event:
                    event,
                day:
                    day
            )
            
            
            result[key] =
            totals
        }
    }
    
    
    return result
}


// MARK: - Индексы событий

func buildFlightsByDay(
    flights: [FlightLeg]
) -> [Int: [FlightLeg]] {
    
    var result:
    [Int: [FlightLeg]] = [:]
    
    
    for flight in flights {
        
        let timeline =
        flight.timeline
        
        
        for day in touchedDays(
            from:
                timeline.engineOn,
            to:
                timeline.engineOff
        ) {
            
            result[
                dayKey(day),
                default: []
            ]
                .append(
                    flight
                )
        }
    }
    
    
    return result
}


func buildWorkEventsByDay(
    events: [WorkEvent]
) -> [Int: [WorkEvent]] {
    
    var result:
    [Int: [WorkEvent]] = [:]
    
    
    for event in events {
        
        let start =
        event.startDate
        
        
        let end =
        event.endDate
        
        
        for day in touchedDays(
            from:
                start,
            to:
                end
        ) {
            
            result[
                dayKey(day),
                default: []
            ]
                .append(
                    event
                )
        }
    }
    
    
    return result
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

func timeText(
    _ minutes: Int
) -> String {
    
    let hours =
    minutes / 60
    
    
    let mins =
    minutes % 60
    
    
    return String(
        format:
            "%d:%02d",
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
