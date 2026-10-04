from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing replacement: {label}")
    return text.replace(old, new, 1)


def regex_once(text: str, pattern: str, repl: str, label: str) -> str:
    out, count = re.subn(pattern, repl, text, count=1, flags=re.S | re.M)
    if count != 1:
        raise SystemExit(f"regex {label}: {count}")
    return out


# ReferenceDataV129.swift
p = Path("ReferenceDataV129.swift")
s = p.read_text()
s = replace_once(
    s,
    '''        switch value {\n        case "A320", "320": return .a320\n        case "A320A", "A320S": return .a320S\n        case "A320N": return .a320N\n        case "A321", "321": return .a321\n        case "A321B", "A321S": return .a321S\n        case "A321Q", "A321N": return .a321N\n        default: return nil\n        }''',
    '''        switch value {\n        case "A320", "320": return .a320\n        case "A320A", "A320S", "32A": return .a320S\n        case "A320N", "32N": return .a320N\n        case "A321", "321": return .a321\n        case "A321B", "A321S", "32B": return .a321S\n        case "A321Q", "A321N", "32Q": return .a321N\n        default: return nil\n        }''',
    "A320 schedule codes"
)

s = replace_once(
    s,
    '''}\n\n\nstruct AircraftReferenceV129''',
    '''}\n\n\nenum FlightScheduleAircraftGroupV131: String, CaseIterable, Identifiable {\n    case all = "Все ВС"\n    case a320 = "A320"\n    case b737 = "B737"\n    case a330 = "A330"\n    case a350 = "A350"\n    case b777 = "B777"\n\n    var id: String { rawValue }\n\n    func contains(rawAircraftCode: String) -> Bool {\n        if self == .all { return true }\n        if self == .a320 { return AircraftFamilyV129.normalized(rawAircraftCode) != nil }\n\n        let value = rawAircraftCode.uppercased()\n            .replacingOccurrences(of: " ", with: "")\n            .replacingOccurrences(of: "-", with: "")\n        switch self {\n        case .all: return true\n        case .a320: return AircraftFamilyV129.normalized(rawAircraftCode) != nil\n        case .b737: return value.hasPrefix("73") || value.hasPrefix("B73")\n        case .a330: return value.hasPrefix("33") || value.hasPrefix("A33")\n        case .a350: return value.hasPrefix("35") || value.hasPrefix("A35")\n        case .b777: return value.hasPrefix("77") || value.hasPrefix("B77")\n        }\n    }\n}\n\n\nstruct AircraftReferenceV129''',
    "schedule aircraft groups"
)

s = regex_once(
    s,
    r'''(    func aircraft\(for registration: String\) -> AircraftReferenceV129\? \{.*?^    \}\n)\n    private static func row''',
    r'''\1\n    func stableAircraft(\n        for type: AircraftFamilyV129,\n        seed: String\n    ) -> AircraftReferenceV129? {\n        if type == .a320S, let tarasov = aircraft(for: "73772") {\n            return tarasov\n        }\n\n        let candidates = aircraft\n            .filter { $0.type == type }\n            .sorted { $0.registration < $1.registration }\n        guard !candidates.isEmpty else { return nil }\n\n        let hash = seed.utf8.reduce(UInt64(1469598103934665603)) { partial, byte in\n            (partial ^ UInt64(byte)) &* 1099511628211\n        }\n        return candidates[Int(hash % UInt64(candidates.count))]\n    }\n\n    private static func row''',
    "stable aircraft"
)

s = regex_once(
    s,
    r'''    nonisolated static func normalizedFlightNumber\(_ raw: String\) -> String \{.*?^    \}\n\n    static func airportCode''',
    '''    nonisolated static func normalizedFlightNumber(_ raw: String) -> String {\n        let digits = raw.uppercased()\n            .replacingOccurrences(of: "SU", with: "")\n            .filter(\\.isNumber)\n        guard let value = Int(digits) else { return "" }\n        return String(value)\n    }\n\n    nonisolated static func displayFlightNumber(_ raw: String) -> String {\n        let normalized = normalizedFlightNumber(raw)\n        guard let number = Int(normalized) else { return raw }\n        if number < 1000 { return String(format: "%03d", number) }\n        return String(number)\n    }\n\n    static func airportCode''',
    "flight number display"
)

schedule_view = r'''struct FlightScheduleDatabaseV130View: View {
    @ObservedObject private var store = FlightScheduleStoreV129.shared
    @State private var search = ""
    @State private var selectedDate = moscowCalendar.startOfDay(for: Date())
    @State private var group: FlightScheduleAircraftGroupV131 = .all
    @State private var expandedEntryID: String?
    @State private var calendarRequest: FlightScheduleCalendarRequestV131?

    private var exactSearchNumber: String? {
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains(where: \.isNumber) else { return nil }
        let normalized = FlightScheduleStoreV129.normalizedFlightNumber(trimmed)
        return normalized.isEmpty ? nil : normalized
    }

    private var globallyMatchingFlightEntries: [FlightScheduleEntryV129] {
        guard let number = exactSearchNumber else { return [] }
        return store.entries.filter {
            FlightScheduleStoreV129.normalizedFlightNumber($0.flightNumber) == number
                && group.contains(rawAircraftCode: $0.rawAircraftCode)
        }
    }

    private var values: [FlightScheduleEntryV129] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNumber = FlightScheduleStoreV129.normalizedFlightNumber(query)
        return store.entries.filter { entry in
            guard group.contains(rawAircraftCode: entry.rawAircraftCode),
                  entryRuns(entry, onMoscowDate: selectedDate) else {
                return false
            }
            guard !query.isEmpty else { return true }
            return (!normalizedNumber.isEmpty
                && FlightScheduleStoreV129.normalizedFlightNumber(entry.flightNumber) == normalizedNumber)
                || entry.departure.localizedCaseInsensitiveContains(query)
                || entry.arrival.localizedCaseInsensitiveContains(query)
                || (AirportDatabase.airport(for: entry.departure)?.name.localizedCaseInsensitiveContains(query) ?? false)
                || (AirportDatabase.airport(for: entry.arrival)?.name.localizedCaseInsensitiveContains(query) ?? false)
                || AircraftFamilyV129.display(entry.rawAircraftCode).localizedCaseInsensitiveContains(query)
        }
        .sorted { left, right in
            if left.departureMinutesUTC == right.departureMinutesUTC {
                return FlightScheduleStoreV129.normalizedFlightNumber(left.flightNumber)
                    .localizedStandardCompare(FlightScheduleStoreV129.normalizedFlightNumber(right.flightNumber)) == .orderedAscending
            }
            return left.departureMinutesUTC < right.departureMinutesUTC
        }
    }

    private var routeCandidates: [FlightScheduleRouteCandidateV131] {
        let grouped = Dictionary(grouping: globallyMatchingFlightEntries) {
            "\($0.departure)|\($0.arrival)"
        }
        return grouped.values.compactMap { entries in
            guard let first = entries.first else { return nil }
            return FlightScheduleRouteCandidateV131(
                flightNumber: first.flightNumber,
                departure: first.departure,
                arrival: first.arrival,
                entries: entries
            )
        }
        .sorted { ($0.departure, $0.arrival) < ($1.departure, $1.arrival) }
    }

    private var selectedDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = moscowTimeZone
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: selectedDate)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                DatePicker(
                    "Дата",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)

                Picker("Семейство ВС", selection: $group) {
                    ForEach(FlightScheduleAircraftGroupV131.allCases) { value in
                        Text(value.rawValue).tag(value)
                    }
                }
                .pickerStyle(.menu)

                TextField("Рейс или аэропорт", text: $search)
                    .textInputAutocapitalization(.characters)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedDateTitle.capitalized)
                        .font(.subheadline.weight(.semibold))
                    Text("Дата вылета по Москве · \(values.count) строк")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 12)

            if values.isEmpty,
               exactSearchNumber != nil,
               !routeCandidates.isEmpty {
                VStack(spacing: 6) {
                    ForEach(routeCandidates) { route in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Рейс \(FlightScheduleStoreV129.displayFlightNumber(route.flightNumber)) · \(route.departure) → \(route.arrival)")
                                    .font(.subheadline.weight(.semibold))
                                Text("В выбранную дату не выполняется")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Календарь выполнения") {
                                let dates = executionDates(for: route.entries)
                                calendarRequest = FlightScheduleCalendarRequestV131(
                                    flightNumber: route.flightNumber,
                                    departure: route.departure,
                                    arrival: route.arrival,
                                    dates: dates
                                )
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        )
                    }
                }
                .padding(.horizontal, 12)
            }

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text("Рейс").frame(width: 54, alignment: .leading)
                    Text("Маршрут").frame(maxWidth: .infinity, alignment: .leading)
                    Text("UTC").frame(width: 112, alignment: .leading)
                    Text("Тип ВС").frame(width: 78, alignment: .leading)
                    Text("Полёт.").frame(width: 56, alignment: .trailing)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(uiColor: .secondarySystemGroupedBackground))

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(values) { entry in
                            scheduleRow(entry)
                        }
                    }
                }
            }
        }
        .navigationTitle("База расписания")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $calendarRequest) { request in
            FlightExecutionCalendarV131View(request: request) { date in
                selectedDate = date
            }
        }
    }

    @ViewBuilder
    private func scheduleRow(_ entry: FlightScheduleEntryV129) -> some View {
        Button {
            expandedEntryID = expandedEntryID == entry.id ? nil : entry.id
        } label: {
            HStack(spacing: 8) {
                Text(FlightScheduleStoreV129.displayFlightNumber(entry.flightNumber))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .frame(width: 54, alignment: .leading)
                Text("\(entry.departure) → \(entry.arrival)")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                Text("\(clock(entry.departureMinutesUTC))–\(clock(entry.arrivalMinutesUTC))")
                    .font(.caption.monospacedDigit())
                    .frame(width: 112, alignment: .leading)
                Text(AircraftFamilyV129.display(entry.rawAircraftCode))
                    .font(.caption.weight(.semibold))
                    .frame(width: 78, alignment: .leading)
                Text(timeText(entry.flightMinutes))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .frame(width: 56, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if expandedEntryID == entry.id {
            Text("\(FlightScheduleStoreV129.shortDay(entry.validFrom))–\(FlightScheduleStoreV129.shortDay(entry.validTo)) · дни \(entry.operatingWeekdays.map(String.init).joined()) · код \(entry.rawAircraftCode)" + (entry.configuration.map { " · \($0)" } ?? ""))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 74)
                .padding(.bottom, 5)
        }
        Divider()
    }

    private func entryRuns(_ entry: FlightScheduleEntryV129, onMoscowDate date: Date) -> Bool {
        for delta in -1...0 {
            guard let probe = moscowCalendar.date(byAdding: .day, value: delta, to: date) else { continue }
            let parts = moscowCalendar.dateComponents([.year, .month, .day], from: probe)
            var components = DateComponents()
            components.timeZone = TimeZone(secondsFromGMT: 0)
            components.year = parts.year
            components.month = parts.month
            components.day = parts.day
            guard let operatingDate = utcCalendar.date(from: components),
                  operatingDate >= entry.validFrom,
                  operatingDate <= entry.validTo else { continue }
            let weekday = utcCalendar.component(.weekday, from: operatingDate)
            let isoWeekday = weekday == 1 ? 7 : weekday - 1
            guard entry.operatingWeekdays.contains(isoWeekday),
                  let engineOn = utcCalendar.date(byAdding: .minute, value: entry.departureMinutesUTC, to: operatingDate) else {
                continue
            }
            if moscowCalendar.isDate(engineOn, inSameDayAs: date) { return true }
        }
        return false
    }

    private func executionDates(for entries: [FlightScheduleEntryV129]) -> [Date] {
        var result = Set<Date>()
        for entry in entries {
            var day = entry.validFrom
            while day <= entry.validTo {
                let weekday = utcCalendar.component(.weekday, from: day)
                let isoWeekday = weekday == 1 ? 7 : weekday - 1
                if entry.operatingWeekdays.contains(isoWeekday),
                   let engineOn = utcCalendar.date(byAdding: .minute, value: entry.departureMinutesUTC, to: day) {
                    result.insert(moscowCalendar.startOfDay(for: engineOn))
                }
                guard let next = utcCalendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
        return result.sorted()
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func clock(_ minutes: Int) -> String {
        String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }
}


private struct FlightScheduleRouteCandidateV131: Identifiable {
    let flightNumber: String
    let departure: String
    let arrival: String
    let entries: [FlightScheduleEntryV129]
    var id: String { "\(FlightScheduleStoreV129.normalizedFlightNumber(flightNumber))|\(departure)|\(arrival)" }
}


private struct FlightScheduleCalendarRequestV131: Identifiable {
    let flightNumber: String
    let departure: String
    let arrival: String
    let dates: [Date]
    var id: String { "\(FlightScheduleStoreV129.normalizedFlightNumber(flightNumber))|\(departure)|\(arrival)" }
}


private struct FlightExecutionCalendarV131View: View {
    let request: FlightScheduleCalendarRequestV131
    let onSelect: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var month: Date

    init(request: FlightScheduleCalendarRequestV131, onSelect: @escaping (Date) -> Void) {
        self.request = request
        self.onSelect = onSelect
        let seed = request.dates.first ?? Date()
        _month = State(initialValue: Self.monthStart(seed))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    Button {
                        shiftMonth(-1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(!canShift(-1))

                    Spacer()
                    Text(monthTitle)
                        .font(.headline)
                    Spacer()

                    Button {
                        shiftMonth(1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(!canShift(1))
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"], id: \.self) { title in
                        Text(title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    ForEach(Array(monthCells.enumerated()), id: \.offset) { _, date in
                        if let date {
                            let active = executionDay(date)
                            Button {
                                guard active else { return }
                                onSelect(date)
                                dismiss()
                            } label: {
                                Text(String(moscowCalendar.component(.day, from: date)))
                                    .font(.subheadline.weight(active ? .semibold : .regular))
                                    .frame(width: 34, height: 34)
                                    .background(
                                        Circle()
                                            .fill(active ? Color.accentColor.opacity(0.18) : Color.clear)
                                    )
                                    .overlay {
                                        if active {
                                            Circle().stroke(Color.accentColor, lineWidth: 1)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(active ? Color.accentColor : Color.secondary)
                            .disabled(!active)
                        } else {
                            Color.clear.frame(width: 34, height: 34)
                        }
                    }
                }

                Text("Отмечены только дни выполнения рейса для выбранного фильтра ВС и загруженного покрытия расписания.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .navigationTitle("Рейс \(FlightScheduleStoreV129.displayFlightNumber(request.flightNumber)) · \(request.departure) → \(request.arrival)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = moscowTimeZone
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: month).capitalized
    }

    private var monthCells: [Date?] {
        let start = Self.monthStart(month)
        let weekday = moscowCalendar.component(.weekday, from: start)
        let mondayOffset = (weekday + 5) % 7
        let range = moscowCalendar.range(of: .day, in: .month, for: start) ?? 1..<2
        var result = Array<Date?>(repeating: nil, count: mondayOffset)
        for day in range {
            if let date = moscowCalendar.date(byAdding: .day, value: day - 1, to: start) {
                result.append(date)
            }
        }
        while result.count % 7 != 0 { result.append(nil) }
        return result
    }

    private func executionDay(_ date: Date) -> Bool {
        request.dates.contains { moscowCalendar.isDate($0, inSameDayAs: date) }
    }

    private func shiftMonth(_ delta: Int) {
        if let next = moscowCalendar.date(byAdding: .month, value: delta, to: month) {
            month = Self.monthStart(next)
        }
    }

    private func canShift(_ delta: Int) -> Bool {
        guard let target = moscowCalendar.date(byAdding: .month, value: delta, to: month),
              let first = request.dates.first,
              let last = request.dates.last else { return false }
        let candidate = Self.monthStart(target)
        return candidate >= Self.monthStart(first) && candidate <= Self.monthStart(last)
    }

    private static func monthStart(_ date: Date) -> Date {
        let components = moscowCalendar.dateComponents([.year, .month], from: date)
        return moscowCalendar.date(from: components) ?? moscowCalendar.startOfDay(for: date)
    }
}
'''

s = regex_once(
    s,
    r'''struct FlightScheduleDatabaseV130View: View \{.*?^\}\n\n\nstruct FlightScheduleSettingsV129View: View''',
    schedule_view + '\n\n\nstruct FlightScheduleSettingsV129View: View',
    "schedule browser view"
)
p.write_text(s)


# PerspectiveDutyBridgeV129.swift
p = Path("PerspectiveDutyBridgeV129.swift")
s = p.read_text()
s = replace_once(
    s,
    '''        for offset in -1...1 {''',
    '''        let offsets = notBefore == nil ? [0] : [0, 1]\n        for offset in offsets {''',
    "date-specific schedule offsets"
)
s = replace_once(
    s,
    '''        var values = Array(candidates.values)\n        if let notBefore {\n            values = values.filter { $0.engineOn >= notBefore.addingTimeInterval(-5 * 60) }\n        }\n        return values.min {\n            let left = abs($0.engineOn.timeIntervalSince(referenceDate))\n            let right = abs($1.engineOn.timeIntervalSince(referenceDate))\n            if left == right { return $0.engineOn < $1.engineOn }\n            return left < right\n        }''',
    '''        var values = Array(candidates.values)\n        if let notBefore {\n            values = values.filter { $0.engineOn >= notBefore.addingTimeInterval(-5 * 60) }\n        }\n        if departureHint == nil && arrivalHint == nil && values.count != 1 {\n            return nil\n        }\n        return values.min {\n            let left = abs($0.engineOn.timeIntervalSince(referenceDate))\n            let right = abs($1.engineOn.timeIntervalSince(referenceDate))\n            if left == right { return $0.engineOn < $1.engineOn }\n            return left < right\n        }''',
    "ambiguous schedule guard"
)
s = replace_once(
    s,
    '''        if let scheduleType = AircraftFamilyV129.normalized(match.entry.rawAircraftCode) {\n            leg.aircraft = scheduleType.rawValue\n        }\n        return leg\n    }''',
    '''        if let scheduleType = AircraftFamilyV129.normalized(match.entry.rawAircraftCode) {\n            leg.aircraft = scheduleType.rawValue\n            leg.registration = aircraftReference(for: match)?.registration ?? "RA-"\n        }\n        return leg\n    }\n\n    static func aircraftReference(for match: FlightScheduleMatchV129) -> AircraftReferenceV129? {\n        guard let family = AircraftFamilyV129.normalized(match.entry.rawAircraftCode) else {\n            return nil\n        }\n        let seed = [\n            FlightScheduleStoreV129.normalizedFlightNumber(match.entry.flightNumber),\n            FlightScheduleStoreV129.dayKey(match.operatingDateUTC),\n            match.entry.departure,\n            match.entry.arrival,\n            match.entry.rawAircraftCode,\n            match.entry.configuration ?? ""\n        ].joined(separator: "|")\n        return AircraftReferenceStoreV129.shared.stableAircraft(for: family, seed: seed)\n    }''',
    "schedule aircraft registration"
)
s = replace_once(
    s,
    '''            let sourceAircraft = planLeg.aircraft ?? match.entry.rawAircraftCode\n            let reference = aircraftReference(\n                rawAircraft: sourceAircraft,\n                itemID: itemID + "|\\(index)"\n            )\n            let aircraft = reference?.type.rawValue\n                ?? AircraftFamilyV129.display(sourceAircraft.replacingOccurrences(of: "-", with: ""))\n            let registration = reference?.registration ?? ""''',
    '''            let sourceAircraft = match.entry.rawAircraftCode\n            let reference = DutyAutofillV129.aircraftReference(for: match)\n            let aircraft = reference?.type.rawValue\n                ?? AircraftFamilyV129.display(sourceAircraft.replacingOccurrences(of: "-", with: ""))\n            let registration = reference?.registration ?? "RA-"''',
    "perspective schedule type"
)
s = regex_once(
    s,
    r'''\n    private static func aircraftReference\(\n        rawAircraft: String,\n        itemID: String\n    \) -> AircraftReferenceV129\? \{.*?^    \}\n\n    private static func shortDate''',
    '''\n    private static func shortDate''',
    "remove old perspective aircraft picker"
)
p.write_text(s)


# AppViews.swift
p = Path("AppViews.swift")
s = p.read_text()
s = replace_once(
    s,
    '''        let textBinding: Binding<String> = isEditing\n            ? legNumberBinding(index)\n            : .constant(editableLegNumber(leg, index: index))''',
    '''        let textBinding: Binding<String> = isEditing\n            ? legNumberBinding(index)\n            : .constant(FlightScheduleStoreV129.displayFlightNumber(editableLegNumber(leg, index: index)))''',
    "canonical flight display"
)
s = replace_once(
    s,
    '''                    restoreValue: original.indices.contains(index)\n                        ? registrationComparisonKey(original[index].registration)\n                        : staticDigits,\n                    highlightHorizontalPadding: 0''',
    '''                    restoreValue: original.indices.contains(index)\n                        ? registrationComparisonKey(original[index].registration)\n                        : staticDigits,\n                    clearOnFirstDelete: true,\n                    highlightHorizontalPadding: 0''',
    "registration delete restore"
)
s = replace_once(
    s,
    '''        let suffix = formatted.dropFirst(3)\n        return !suffix.isEmpty && suffix.allSatisfy(\\.isNumber)''',
    '''        let suffix = formatted.dropFirst(3)\n        return suffix.count <= 5 && suffix.allSatisfy(\\.isNumber)''',
    "RA prefix numeric field"
)
s = replace_once(
    s,
    '''        guard let match else { return }\n        draft[index] = DutyAutofillV129.applyingSchedule(\n            to: draft[index],\n            match: match,\n            index: index,\n            totalCount: draft.count,\n            previousEngineOff: previousEnd\n        )''',
    '''        guard let match else { return }\n        let enteredNumber = editableLegNumber(draft[index], index: index)\n        var updated = DutyAutofillV129.applyingSchedule(\n            to: draft[index],\n            match: match,\n            index: index,\n            totalCount: draft.count,\n            previousEngineOff: previousEnd\n        )\n        updated.legNumber = enteredNumber\n        updated.flightNumber = enteredNumber\n        draft[index] = updated''',
    "preserve live flight typing"
)
s = replace_once(
    s,
    '''        if hasRegistration, current != type {\n            draft[index].registration = ""\n        }''',
    '''        if hasRegistration, current != type {\n            draft[index].registration = "RA-"\n        }''',
    "type change keeps RA prefix"
)
p.write_text(s)


# PlanAssignmentRowV119.swift
p = Path("PlanAssignmentRowV119.swift")
s = p.read_text()
s = regex_once(
    s,
    r'''    private func legText\(_ leg: DisplayLeg\) -> String \{.*?^    \}\n\n    private var displayedFlightMinutes: Int\? \{.*?^    \}''',
    '''    private func legText(_ leg: DisplayLeg) -> String {\n        var parts = [leg.flightNumber]\n        var displayedAircraft = leg.aircraft\n        if perspectiveStyle,\n           !scheduleStore.entries.isEmpty,\n           let match = PerspectiveDutyBuilderV129.scheduleDisplay(\n                flightNumber: leg.flightNumber,\n                date: metadata?.sourceStart ?? item.start,\n                departureHint: leg.departure,\n                arrivalHint: leg.arrival\n           ) {\n            let departure = DutyAutofillV129.displayAirport(\n                code: match.entry.departure,\n                terminal: match.entry.departureTerminal\n            )\n            let arrival = DutyAutofillV129.displayAirport(\n                code: match.entry.arrival,\n                terminal: match.entry.arrivalTerminal\n            )\n            parts.append("\\(departure) → \\(arrival)")\n            displayedAircraft = AircraftFamilyV129.display(match.entry.rawAircraftCode)\n        } else if let departure = leg.departure,\n                  let arrival = leg.arrival {\n            parts.append("\\(departure) → \\(arrival)")\n        }\n        if let aircraft = displayedAircraft, !aircraft.isEmpty {\n            parts.append(AircraftFamilyV129.display(aircraft))\n        }\n        return parts.joined(separator: " · ")\n    }\n\n    private var displayedFlightMinutes: Int? {\n        if perspectiveStyle, !scheduleStore.entries.isEmpty, !displayLegs.isEmpty {\n            let values = displayLegs.compactMap { leg in\n                PerspectiveDutyBuilderV129.scheduleDisplay(\n                    flightNumber: leg.flightNumber,\n                    date: metadata?.sourceStart ?? item.start,\n                    departureHint: leg.departure,\n                    arrivalHint: leg.arrival\n                )?.entry.flightMinutes\n            }\n            if values.count == displayLegs.count {\n                return values.reduce(0, +)\n            }\n        }\n        if let value = item.plannedFlightMinutes {\n            return value\n        }\n        return plannedMinutesMarker(in: item.detail)\n    }''',
    "perspective schedule aircraft and duration"
)
s = replace_once(
    s,
    '''    private func displayFlightNumber(_ value: String) -> String {\n        let digits = value.filter(\\.isNumber)\n        return digits.isEmpty ? value : digits\n    }''',
    '''    private func displayFlightNumber(_ value: String) -> String {\n        FlightScheduleStoreV129.displayFlightNumber(value)\n    }''',
    "perspective canonical flight display"
)
p.write_text(s)

print("v131 patch applied")
