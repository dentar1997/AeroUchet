from pathlib import Path
import re


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f"missing: {label}")
    return text.replace(old, new, 1)


def regex_once(text, pattern, repl, label):
    out, count = re.subn(pattern, repl, text, count=1, flags=re.S | re.M)
    if count != 1:
        raise SystemExit(f"regex {label}: {count}")
    return out

# AssignmentsView.swift
p = Path('AssignmentsView.swift')
s = p.read_text()
s = replace_once(s, '''    private var items: [AssignmentPlanItem] {
        planStore.sourceItems(
            .importedFile,
            actualFlights: store.flights,
            hideSuperseded: false
        )
    }

    var body: some View {''', '''    private var items: [AssignmentPlanItem] {
        planStore.sourceItems(
            .importedFile,
            actualFlights: store.flights,
            hideSuperseded: false
        )
    }

    private var perspectiveMonthKeys: [Int] {
        func key(_ date: Date) -> Int {
            let parts = moscowCalendar.dateComponents([.year, .month], from: date)
            return (parts.year ?? 0) * 100 + (parts.month ?? 0)
        }
        func sourceStart(_ item: AssignmentPlanItem) -> Date {
            AssignmentV119MetadataCodec.metadata(from: item.detail)?.sourceStart ?? item.start
        }
        func monthStart(_ date: Date) -> Date {
            let parts = moscowCalendar.dateComponents([.year, .month], from: date)
            return moscowCalendar.date(from: DateComponents(
                timeZone: moscowTimeZone,
                year: parts.year,
                month: parts.month,
                day: 1
            )) ?? date
        }

        var keys = Set(items.map { key(sourceStart($0)) })
        for item in items where item.isAllDay {
            let includedEnd = moscowCalendar.date(byAdding: .day, value: -1, to: item.end) ?? item.end
            var cursor = monthStart(item.start)
            let last = monthStart(includedEnd)
            var guardCount = 0
            while cursor <= last, guardCount < 24 {
                keys.insert(key(cursor))
                guard let next = moscowCalendar.date(byAdding: .month, value: 1, to: cursor) else { break }
                cursor = next
                guardCount += 1
            }
        }
        return keys.sorted()
    }

    var body: some View {''', 'month keys')

s = replace_once(s, '''                    } else {
                        PerspectivePlanMonthCardsView(
                            items: items,
                            status: status(for:),
                            statusColor: statusColor(for:),
                            onFlightTap: openPerspectiveDuty
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                        .listRowBackground(Color.clear)
                    }''', '''                    } else {
                        ForEach(perspectiveMonthKeys, id: \.self) { monthKey in
                            PerspectivePlanMonthCardsView(
                                items: items,
                                onlyMonthKey: monthKey,
                                status: status(for:),
                                statusColor: statusColor(for:),
                                onFlightTap: openPerspectiveDuty
                            )
                            .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }''', 'direct list month rows')

s = replace_once(s, '''private struct PerspectivePlanMonthCardsView: View {
    let items: [AssignmentPlanItem]
    let status: (AssignmentPlanItem) -> String?''', '''private struct PerspectivePlanMonthCardsView: View {
    let items: [AssignmentPlanItem]
    let onlyMonthKey: Int
    let status: (AssignmentPlanItem) -> String?''', 'month key input')

s = regex_once(s, r'''    private var monthSections: \[MonthSection\] \{.*?^    \}\n\n    @ViewBuilder''', '''    private var monthSections: [MonthSection] {
        let key = onlyMonthKey
        let start = dateForMonthKey(key)
        let end = start.flatMap { moscowCalendar.date(byAdding: .month, value: 1, to: $0) }

        let primary = items
            .filter { sourceMonthKey($0) == key }
            .sorted { sourceStart($0) < sourceStart($1) }

        let carryovers: [AssignmentPlanItem]
        if let start, let end {
            carryovers = items
                .filter { item in
                    item.isAllDay
                        && sourceMonthKey(item) < key
                        && item.start < end
                        && item.end > start
                }
                .sorted { $0.start < $1.start }
        } else {
            carryovers = []
        }

        return [MonthSection(key: key, primary: primary, carryovers: carryovers)]
    }

    @ViewBuilder''', 'single month section')
p.write_text(s)

# PlanAssignmentRowV119.swift: decode metadata once per row construction
p = Path('PlanAssignmentRowV119.swift')
s = p.read_text()
s = replace_once(s, '''struct PlanAssignmentRowV119: View {
    let item: AssignmentPlanItem
    var status: String?
    var statusColor: Color = .secondary
    var conflictText: String?
    var perspectiveStyle = false

    private var effectiveConflictText: String? {''', '''struct PlanAssignmentRowV119: View {
    let item: AssignmentPlanItem
    var status: String?
    var statusColor: Color = .secondary
    var conflictText: String?
    var perspectiveStyle = false
    private let decodedMetadata: AssignmentV119Metadata?

    init(
        item: AssignmentPlanItem,
        status: String? = nil,
        statusColor: Color = .secondary,
        conflictText: String? = nil,
        perspectiveStyle: Bool = false
    ) {
        self.item = item
        self.status = status
        self.statusColor = statusColor
        self.conflictText = conflictText
        self.perspectiveStyle = perspectiveStyle
        self.decodedMetadata = AssignmentV119MetadataCodec.metadata(from: item.detail)
    }

    private var effectiveConflictText: String? {''', 'row init cache')
s = replace_once(s, '''    private var metadata: AssignmentV119Metadata? {
        AssignmentV119MetadataCodec.metadata(from: item.detail)
    }''', '''    private var metadata: AssignmentV119Metadata? {
        decodedMetadata
    }''', 'row metadata cache')
p.write_text(s)

# PerspectiveDutyBridgeV129.swift
p = Path('PerspectiveDutyBridgeV129.swift')
s = p.read_text()
s = replace_once(s, '''@MainActor
enum DutyAutofillV129 {
    static func normalizedFlightNumber''', '''@MainActor
enum DutyAutofillV129 {
    private enum CachedScheduleMatch {
        case missing
        case value(FlightScheduleMatchV129)
    }

    private static var scheduleMatchCache: [String: CachedScheduleMatch] = [:]

    static func normalizedFlightNumber''', 'schedule cache declaration')

s = replace_once(s, '''        let store = FlightScheduleStoreV129.shared
        var candidates: [String: FlightScheduleMatchV129] = [:]

        let offsets = notBefore == nil ? [0] : [0, 1]''', '''        let store = FlightScheduleStoreV129.shared
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
        let offsets = notBefore == nil ? [0] : [0, 1]''', 'schedule cache read')

s = replace_once(s, '''        if departureHint == nil && arrivalHint == nil && values.count != 1 {
            return nil
        }
        return values.min {
            let left = abs($0.engineOn.timeIntervalSince(referenceDate))
            let right = abs($1.engineOn.timeIntervalSince(referenceDate))
            if left == right { return $0.engineOn < $1.engineOn }
            return left < right
        }
    }

    static func applyingSchedule''', '''        if departureHint == nil && arrivalHint == nil && values.count != 1 {
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

    static func applyingSchedule''', 'schedule cache write')

s = replace_once(s, '''    private struct PlanLeg {
        let flightNumber: String
        let departure: String?
        let arrival: String?
        let aircraft: String?
    }

    static func build(item: AssignmentPlanItem) -> Result {''', '''    private struct PlanLeg {
        let flightNumber: String
        let departure: String?
        let arrival: String?
        let aircraft: String?
    }

    private static var buildCache: [String: Result] = [:]

    static func build(item: AssignmentPlanItem) -> Result {''', 'builder cache declaration')

build_pattern = r'''    static func build\(item: AssignmentPlanItem\) -> Result \{.*?^    \}\n\n    static func routeConflict\(item: AssignmentPlanItem\) -> String\? \{.*?^    \}\n\n    static func scheduleDisplay'''
build_repl = '''    static func build(item: AssignmentPlanItem) -> Result {
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

    static func scheduleDisplay'''
s = regex_once(s, build_pattern, build_repl, 'builder one-pass cache')
p.write_text(s)

print('v132 patch applied')
