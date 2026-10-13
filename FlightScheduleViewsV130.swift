import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// Экраны базы расписания. Вынесены из ReferenceDataV129.swift 13.10 ради скорости сборки, код без изменений.


struct FlightScheduleDatabaseV130View: View {
    @ObservedObject private var store = FlightScheduleStoreV129.shared
    /// Номер рейса (до 4 цифр).
    @State private var search = ""
    @State private var departureQuery = ""
    @State private var arrivalQuery = ""
    /// Галочка в поле «Прилёт». Выключена — левое поле ищет аэропорт и в вылете, и в прилёте.
    @State private var arrivalEnabled = true
    /// Какая крутилка часов сейчас крутится: "from" / "to".
    @State private var activeHourField: String?
    @State private var highlightMemo = HighlightMemo()
    @State private var typeMenuOpen = false
    @State private var fromFieldFrame: CGRect = .zero
    @State private var tapCatcher = ScheduleTapCatcher()
    @State private var toFieldFrame: CGRect = .zero
    /// Вкладка «Тест» (07.10): та же таблица, шрифт крупнее, вся таблица в общей карточке.
    private let cardStyle: Bool

    /// Сортировка по столбцу (тап по заголовку). При входе — по времени UTC по возрастанию.
    private enum SortColumn { case flight, route, time, type, duration }
    @State private var sortColumn: SortColumn = .time
    @State private var sortAscending = true

    /// Крупный шрифт — только во вкладке «Тест» (Денис 07.10 05:39).
    private let largeText: Bool

    init(cardStyle: Bool = true, largeText: Bool = false) {
        // Денис 07.10 05:11: основная база — карточкой; шрифт прежний (05:23).
        self.cardStyle = cardStyle
        self.largeText = largeText
    }
    @State private var typeButtonFrame: CGRect = .zero
    @State private var typePanelFrame: CGRect = .zero
    /// Часы вылета по UTC: с `fromHour` до `toHour` (24 — до конца суток).
    @State private var fromHour = 0
    @State private var toHour = 24
    @State private var selectedDate = moscowCalendar.startOfDay(for: Date())
    @AppStorage(ScheduleAircraftFilterButton.storageKey) private var groupsRaw = ""
    /// Выбранный рейс: номер + маршрут. Держится при смене дня, пока его не снимут.
    @State private var selectedFlightKey: String?
    /// Запись расписания, раскрытая последней (её дни — сплошной круг).
    @State private var selectedRecordID: String?
    @State private var showCalendarPopover = false
    /// Маршрут, для которого календарь открыли кнопкой «Календарь выполнения» (узкий экран).
    @State private var calendarRouteID: String?

    /// Ширина, с которой календарь стоит справа от таблицы, а не всплывает.
    private static let sideCalendarMinWidth: CGFloat = 860

    private var groups: Set<FlightScheduleAircraftGroupV131> {
        ScheduleAircraftFilterButton.decode(groupsRaw)
    }

    private var groupsBinding: Binding<Set<FlightScheduleAircraftGroupV131>> {
        Binding(
            get: { groups },
            set: { groupsRaw = ScheduleAircraftFilterButton.encode($0) }
        )
    }

    private func passesFilter(_ entry: FlightScheduleEntryV129) -> Bool {
        ScheduleAircraftFilterButton.matches(groups, rawAircraftCode: entry.rawAircraftCode)
    }

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
                && passesFilter($0)
                && routeMatches($0)
        }
    }

    /// Маршрут по полям: «Вылет → Прилёт» или, без галочки, один аэропорт в любую сторону.
    private func routeMatches(_ entry: FlightScheduleEntryV129) -> Bool {
        if arrivalEnabled {
            return Self.airport(entry.departure, matches: departureQuery)
                && Self.airport(entry.arrival, matches: arrivalQuery)
        }
        let query = departureQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return Self.airport(entry.departure, matches: query) || Self.airport(entry.arrival, matches: query)
    }

    /// Номер, маршрут и часы — то же, что фильтрует список (без даты и типа ВС).
    private func matchesFields(_ entry: FlightScheduleEntryV129) -> Bool {
        if let number = exactSearchNumber,
           FlightScheduleStoreV129.normalizedFlightNumber(entry.flightNumber) != number {
            return false
        }
        guard routeMatches(entry) else { return false }
        let departure = entry.departureMinutesUTC % 1440
        return departure >= fromHour * 60 && departure < toHour * 60
    }

    private var fieldsAreFilled: Bool {
        !search.isEmpty
            || !departureQuery.trimmingCharacters(in: .whitespaces).isEmpty
            || (arrivalEnabled && !arrivalQuery.trimmingCharacters(in: .whitespaces).isEmpty)
            || fromHour != 0 || toHour != 24
    }

    /// Пустое поле — любой аэропорт; иначе начало кода или название/город.
    private static func airport(_ code: String, matches rawQuery: String) -> Bool {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        if code.uppercased().hasPrefix(query.uppercased()) { return true }
        return AirportDatabase.airport(for: code)?.matches(query) ?? false
    }


    private var values: [FlightScheduleEntryV129] {
        store.entries.filter { entry in
            passesFilter(entry)
                && Self.entryDepartsOn(utcDay: selectedUTCDay, entry)
                && matchesFields(entry)
        }
        // Всё по UTC (Денис 07.10 03:50): дни недели расписания заданы по UTC.
        .sorted(by: sortsBefore)
    }

    private static func flightNumberValue(_ entry: FlightScheduleEntryV129) -> Int {
        Int(FlightScheduleStoreV129.normalizedFlightNumber(entry.flightNumber).filter(\.isNumber)) ?? Int.max
    }

    private static func airportName(_ code: String) -> String {
        AirportDatabase.airport(for: code)?.name ?? code
    }

    private func sortsBefore(_ left: FlightScheduleEntryV129, _ right: FlightScheduleEntryV129) -> Bool {
        let order: ComparisonResult
        switch sortColumn {
        case .flight:
            let l = Self.flightNumberValue(left), r = Self.flightNumberValue(right)
            order = l == r ? .orderedSame : (l < r ? .orderedAscending : .orderedDescending)
        case .route:
            // По названиям аэропортов (городов), не по кодам: сначала вылет, потом прилёт.
            let l = Self.airportName(left.departure) + " " + Self.airportName(left.arrival)
            let r = Self.airportName(right.departure) + " " + Self.airportName(right.arrival)
            order = l.localizedCompare(r)
        case .time:
            let l = left.departureMinutesUTC % 1440, r = right.departureMinutesUTC % 1440
            order = l == r ? .orderedSame : (l < r ? .orderedAscending : .orderedDescending)
        case .type:
            order = AircraftFamilyV129.display(left.rawAircraftCode)
                .localizedStandardCompare(AircraftFamilyV129.display(right.rawAircraftCode))
        case .duration:
            let l = left.flightMinutes, r = right.flightMinutes
            order = l == r ? .orderedSame : (l < r ? .orderedAscending : .orderedDescending)
        }
        if order != .orderedSame {
            return sortAscending ? order == .orderedAscending : order == .orderedDescending
        }
        // При равенстве — по времени вылета, затем по номеру.
        let lt = left.departureMinutesUTC % 1440, rt = right.departureMinutesUTC % 1440
        if lt != rt { return lt < rt }
        return Self.flightNumberValue(left) < Self.flightNumberValue(right)
    }

    private func sortHeader(_ title: String, _ column: SortColumn) -> some View {
        Button {
            if sortColumn == column {
                sortAscending.toggle()
            } else {
                sortColumn = column
                sortAscending = true
            }
        } label: {
            Text(title)
                .multilineTextAlignment(.center)
                .fixedSize()
                // Стрелка сбоку и не занимает место заголовка: «Полётное время» всегда в две строки.
                .overlay(alignment: .trailing) {
                    if sortColumn == column {
                        Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.bold))
                            .offset(x: 13)
                    }
                }
            .foregroundStyle(sortColumn == column ? Color.teal : Color.secondary)
        }
        .buttonStyle(.plain)
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

    // MARK: Выбранный рейс и подсветка дней выполнения

    private static func flightKey(_ entry: FlightScheduleEntryV129) -> String {
        "\(FlightScheduleStoreV129.normalizedFlightNumber(entry.flightNumber))|\(entry.departure)|\(entry.arrival)"
    }

    /// Строка выбранного рейса в списке выбранного дня (если в этот день он летает).
    private func selectedRow(in rows: [FlightScheduleEntryV129]) -> FlightScheduleEntryV129? {
        guard let key = selectedFlightKey else { return nil }
        return rows.first { $0.id == selectedRecordID && Self.flightKey($0) == key }
            ?? rows.first { Self.flightKey($0) == key }
    }

    /// Выбранный рейс в выбранный день — даже если поля фильтра его не пропускают
    /// (Денис 07.10 06:22: выделенный рейс остаётся в списке как исключение).
    private var selectedExceptionRow: FlightScheduleEntryV129? {
        guard let key = selectedFlightKey else { return nil }
        let day = selectedUTCDay
        let candidates = store.entries.filter {
            Self.flightKey($0) == key && Self.entryDepartsOn(utcDay: day, $0)
        }
        return candidates.first { $0.id == selectedRecordID } ?? candidates.first
    }

    /// Строки таблицы: выбранный рейс (если фильтр его не пропускает) — первым, затем фильтр.
    private func displayRows(_ filtered: [FlightScheduleEntryV129]) -> [FlightScheduleEntryV129] {
        guard let extra = selectedExceptionRow,
              !filtered.contains(where: { Self.flightKey($0) == Self.flightKey(extra) }) else {
            return filtered
        }
        return [extra] + filtered
    }

    private struct Highlight {
        let title: String
        let primary: Set<String>
        let secondary: Set<String>
        /// Дни, когда рейс летает на неотмеченных в фильтре типах ВС.
        let tertiary: Set<String>
        let legend: String?
    }

    /// Запоминает последнюю подсветку: пересчёт только при смене полей, выбора или расписания.
    private final class HighlightMemo {
        var key = ""
        var value: Highlight?
    }

    private func highlight(rows: [FlightScheduleEntryV129]) -> Highlight? {
        let base = "\(groupsRaw)|\(store.entries.count)|\(FlightScheduleStoreV129.generation)"
        let key: String
        if let flight = selectedFlightKey {
            let record = selectedRow(in: rows)?.id ?? selectedRecordID ?? ""
            key = "1|\(flight)|\(record)|\(base)"
        } else if let route = calendarRouteID {
            key = "R|\(route)|\(search)|\(base)"
        } else if fieldsAreFilled {
            key = "2|\(search)|\(departureQuery)|\(arrivalEnabled)|\(arrivalQuery)|\(fromHour)|\(toHour)|\(base)"
        } else {
            return nil
        }
        if highlightMemo.key == key { return highlightMemo.value }
        let value = computeHighlight(rows: rows)
        highlightMemo.key = key
        highlightMemo.value = value
        return value
    }

    /// Режим 1 (выбранный рейс, главный) → маршрут кнопкой у подсказки → режим 2 (поля фильтра).
    private func computeHighlight(rows: [FlightScheduleEntryV129]) -> Highlight? {
        let allTypes = groups.count >= ScheduleAircraftFilterButton.choices.count
        if let key = selectedFlightKey {
            let sameFlight = store.entries.filter { Self.flightKey($0) == key }
            let entries = sameFlight.filter(passesFilter)
            guard let sample = entries.first ?? sameFlight.first else { return nil }
            let record = selectedRow(in: rows)
                ?? entries.first { $0.id == selectedRecordID }
            let recordDays = record.map { Self.dayKeys(Self.executionDays([$0])) } ?? []
            let allDays = Self.dayKeys(Self.executionDays(entries))
            let otherTypes = allTypes ? [] : Self.dayKeys(Self.executionDays(sameFlight.filter { !passesFilter($0) }))
            let legend = record.map {
                "эта запись \(FlightScheduleStoreV129.shortDay($0.validFrom))–\(FlightScheduleStoreV129.shortDay($0.validTo)), дни \($0.operatingWeekdays.map(String.init).joined())"
            }
            return Highlight(
                title: routeTitle(sample.flightNumber, sample.departure, sample.arrival),
                primary: recordDays,
                secondary: allDays.subtracting(recordDays),
                tertiary: otherTypes.subtracting(allDays),
                legend: legend
            )
        }
        if let id = calendarRouteID, let route = routeCandidates.first(where: { $0.id == id }) {
            return Highlight(
                title: routeTitle(route.flightNumber, route.departure, route.arrival),
                primary: Self.dayKeys(Self.executionDays(route.entries)),
                secondary: [],
                tertiary: [],
                legend: nil
            )
        }
        // Режим 2: всё, что подходит под поля, считается одной записью.
        let matching = store.entries.filter(matchesFields)
        let shown = Self.dayKeys(Self.executionDays(matching.filter(passesFilter)))
        let hidden = allTypes ? [] : Self.dayKeys(Self.executionDays(matching.filter { !passesFilter($0) }))
        return Highlight(
            title: fieldsTitle,
            primary: shown,
            secondary: [],
            tertiary: hidden.subtracting(shown),
            legend: shown.isEmpty ? nil : "по фильтру"
        )
    }

    private var fieldsTitle: String {
        var parts: [String] = []
        if !search.isEmpty { parts.append("Рейс \(search)") }
        let departure = departureQuery.trimmingCharacters(in: .whitespaces).uppercased()
        let arrival = arrivalQuery.trimmingCharacters(in: .whitespaces).uppercased()
        if arrivalEnabled {
            if !departure.isEmpty || !arrival.isEmpty {
                parts.append("\(departure.isEmpty ? "любой" : departure) → \(arrival.isEmpty ? "любой" : arrival)")
            }
        } else if !departure.isEmpty {
            parts.append("\(departure) ⇄")
        }
        if fromHour != 0 || toHour != 24 {
            parts.append(String(format: "%02d–%02d", fromHour, toHour))
        }
        return parts.isEmpty ? "Календарь" : parts.joined(separator: " · ")
    }

    /// Дни вылета по UTC — номера суток от 1970-01-01 (быстро, без календаря).
    /// Запись хранит даты действия в UTC (полночь) и дни недели ISO (1 = пн).
    private static func executionDays(_ entries: [FlightScheduleEntryV129]) -> Set<Int> {
        var result = Set<Int>()
        for entry in entries {
            let first = Int((entry.validFrom.timeIntervalSince1970 / 86_400).rounded(.down))
            let last = Int((entry.validTo.timeIntervalSince1970 / 86_400).rounded(.down))
            guard last >= first else { continue }
            let shift = entry.departureMinutesUTC / 1440
            var weekdays = [Bool](repeating: false, count: 8)
            for day in entry.operatingWeekdays where (1...7).contains(day) { weekdays[day] = true }
            for day in first...last {
                // 01.01.1970 — четверг (ISO 4).
                let iso = ((day + 3) % 7 + 7) % 7 + 1
                if weekdays[iso] { result.insert(day + shift) }
            }
        }
        return result
    }

    private static var dayKeyCache: [Int: String] = [:]

    /// Выбранная дата календаря как сутки UTC (число и месяц те же).
    private var selectedUTCDay: Int {
        let parts = moscowCalendar.dateComponents([.year, .month, .day], from: selectedDate)
        guard let date = Calendar.gregorianUTC.date(
            from: DateComponents(year: parts.year, month: parts.month, day: parts.day)
        ) else { return 0 }
        return Int((date.timeIntervalSince1970 / 86_400).rounded(.down))
    }

    /// Вылетает ли рейс записи в эти сутки UTC.
    private static func entryDepartsOn(utcDay: Int, _ entry: FlightScheduleEntryV129) -> Bool {
        let operating = utcDay - entry.departureMinutesUTC / 1440
        let first = Int((entry.validFrom.timeIntervalSince1970 / 86_400).rounded(.down))
        let last = Int((entry.validTo.timeIntervalSince1970 / 86_400).rounded(.down))
        guard operating >= first, operating <= last else { return false }
        let iso = ((operating + 3) % 7 + 7) % 7 + 1
        return entry.operatingWeekdays.contains(iso)
    }

    private static func dayKeys(_ days: Set<Int>) -> Set<String> {
        Set(days.map { day in
            if let cached = dayKeyCache[day] { return cached }
            let date = Date(timeIntervalSince1970: TimeInterval(day) * 86_400)
            let parts = Calendar.gregorianUTC.dateComponents([.year, .month, .day], from: date)
            let key = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
            dayKeyCache[day] = key
            return key
        })
    }


    private func routeTitle(_ number: String, _ departure: String, _ arrival: String) -> String {
        "Рейс \(FlightScheduleStoreV129.displayFlightNumber(number)) · \(AirportDatabase.displayName(for: departure)) → \(AirportDatabase.displayName(for: arrival))"
    }

    private func calendarView(_ highlight: Highlight?, cardLayout: Bool = false) -> some View {
        ScheduleMonthsCalendarView(
            selectedDate: $selectedDate,
            primaryDays: highlight?.primary ?? [],
            secondaryDays: highlight?.secondary ?? [],
            tertiaryDays: highlight?.tertiary ?? [],
            title: highlight?.title,
            legend: highlight?.legend,
            cardLayout: cardLayout
        )
    }

    private var fullDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = moscowTimeZone
        formatter.dateFormat = "EE, d MMMM yyyy"
        let text = formatter.string(from: selectedDate)
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    private func flightsCountText(_ count: Int) -> String {
        let tail = count % 100
        let last = count % 10
        let word: String
        if (11...14).contains(tail) { word = "рейсов" }
        else if last == 1 { word = "рейс" }
        else if (2...4).contains(last) { word = "рейса" }
        else { word = "рейсов" }
        return "\(count) \(word)"
    }

    private var selectedDateButtonTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = moscowTimeZone
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: selectedDate).replacingOccurrences(of: ".", with: "")
    }

    var body: some View {
        GeometryReader { geometry in
            let isWide = geometry.size.width >= Self.sideCalendarMinWidth
            let filtered = values
            let rows = displayRows(filtered)
            let route = highlight(rows: rows)
            HStack(spacing: 0) {
                tablePane(isWide: isWide, route: route, rows: rows, filteredCount: filtered.count)
                    .contentShape(Rectangle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                if isWide {
                    calendarView(route, cardLayout: true)
                        .padding(.top, 8)
                        .padding(.trailing, 12)
                        .padding(.bottom, 12)
                        .frame(width: 380)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
        // Нижний отступ карточек — от края экрана, как слева (12).
        // Клавиатура (и строка над ней) не ужимает экран — низ карточек не срезается.
        .ignoresSafeArea([.container, .keyboard], edges: .bottom)
        // Тап в любом месте мимо крутилок часов закрывает крутилку.
        .background {
            // Пустое место по всему экрану (и у верхней полосы) ловит тап «мимо».
            Color.clear.contentShape(Rectangle()).ignoresSafeArea()
        }
        .onAppear {
            tapCatcher.onTap = { point in
                // Окно «Тип ВС»: тап мимо кнопки и окна — закрыть (прокрутка не блокируется).
                if typeMenuOpen,
                   !typePanelFrame.contains(point),
                   !typeButtonFrame.contains(point) {
                    typeMenuOpen = false
                }
                guard activeHourField != nil else { return }
                let inside = [fromFieldFrame, toFieldFrame].contains {
                    $0.insetBy(dx: -4, dy: -14).contains(point)
                }
                if !inside { activeHourField = nil }
            }
            tapCatcher.install()
        }
        .onDisappear { tapCatcher.remove() }
        // Строку «База расписания» не показываем (Денис 07.10 05:11).
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .aeroStableNavigationBar()
        .onChange(of: search) { _, _ in calendarRouteID = nil }
        .onChange(of: fromHour) { _, value in if toHour <= value { toHour = value + 1 } }
        .onChange(of: toHour) { _, value in if fromHour >= value { fromHour = value - 1 } }
    }

    private func tablePane(
        isWide: Bool,
        route: Highlight?,
        rows values: [FlightScheduleEntryV129],
        filteredCount: Int
    ) -> some View {
        VStack(spacing: 8) {
            // Сверху строка даты (Денис 07.10 06:27), под ней поля фильтра.
            HStack {
                Text(isWide
                    ? "\(fullDateTitle) · дата вылета по UTC · \(flightsCountText(filteredCount))"
                    : "Дата вылета по UTC · \(flightsCountText(filteredCount))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            HStack(spacing: 10) {
                if !isWide {
                    Button {
                        showCalendarPopover = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                            Text(selectedDateButtonTitle)
                                .font(.subheadline.monospacedDigit())
                        }
                    }
                    .buttonStyle(.bordered)
                    .popover(isPresented: $showCalendarPopover) {
                        calendarView(route)
                            .padding(12)
                            .frame(width: 380, height: 520)
                            .background(Color(uiColor: .systemBackground))
                            .presentationBackground(Color(uiColor: .systemBackground))
                            .presentationCompactAdaptation(.popover)
                            .onChange(of: selectedDate) { _, _ in showCalendarPopover = false }
                    }
                }

                TextField("Рейс", text: $search)
                    .keyboardType(.numberPad)
                    .scheduleFilterTile()
                    .frame(width: 66)
                    .onChange(of: search) { _, value in
                        let digits = String(value.filter(\.isNumber).prefix(4))
                        if digits != value { search = digits }
                    }

                TextField(arrivalEnabled ? "Вылет" : "Аэропорт", text: $departureQuery)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .scheduleFilterTile()
                    .frame(width: 124)
                // Стрелка меняет вылет и прилёт местами.
                Button {
                    let value = departureQuery
                    departureQuery = arrivalQuery
                    arrivalQuery = value
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                }
                .buttonStyle(.borderless)
                .disabled(!arrivalEnabled)
                TextField("Прилёт", text: $arrivalQuery)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .scheduleFilterTile()
                    .disabled(!arrivalEnabled)
                    .opacity(arrivalEnabled ? 1 : 0.45)
                    .padding(.trailing, 0)
                    .overlay(alignment: .trailing) {
                        // Галочка: выключена — поле серое, пустое, а левое ищет в обе стороны.
                        Button {
                            arrivalEnabled.toggle()
                            arrivalQuery = ""
                        } label: {
                            Image(systemName: arrivalEnabled ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(arrivalEnabled ? Color.teal : Color.secondary)
                        }
                        .buttonStyle(.borderless)
                        .padding(.trailing, 6)
                    }
                    .frame(width: 124)

                ScheduleHourWheelField(
                    title: "с",
                    hour: $fromHour,
                    range: 0...23,
                    isActive: activeHourField == "from",
                    onActivate: { activeHourField = activeHourField == "from" ? nil : "from" },
                    frame: $fromFieldFrame
                )
                ScheduleHourWheelField(
                    title: "до",
                    hour: $toHour,
                    range: 1...24,
                    isActive: activeHourField == "to",
                    onActivate: { activeHourField = activeHourField == "to" ? nil : "to" },
                    frame: $toFieldFrame
                )

                ScheduleAircraftFilterButton(
                    selection: groupsBinding,
                    isOpen: $typeMenuOpen,
                    frame: $typeButtonFrame,
                    panelFrame: $typePanelFrame
                )

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            // Окно «Тип ВС» выпадает поверх таблицы.
            .zIndex(1)


            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    sortHeader("Рейс", .flight).frame(width: numberWidth, alignment: .leading)
                    sortHeader("Маршрут", .route).frame(maxWidth: .infinity, alignment: .leading)
                    sortHeader("Время UTC", .time).frame(width: timeWidth, alignment: .leading)
                    sortHeader("Тип ВС", .type).frame(width: typeWidth, alignment: .leading)
                    // В две строки и по центру — столбец уже (Денис 07.10 11:43).
                    sortHeader("Полётное\nвремя", .duration).frame(width: durationWidth, alignment: .center)
                }
                .font((largeText ? Font.subheadline : Font.caption).weight(.semibold))
                .padding(.horizontal, 12)
                // Высота как у строки дней недели календаря справа — на одной линии.
                .frame(height: ScheduleMonthsCalendarView.headerHeight + (largeText ? 8 : 0))
                .background(cardStyle ? Color.clear : Color(uiColor: .secondarySystemGroupedBackground))
                if cardStyle { Divider() }

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Подсказки — внутри таблицы, карточки не сдвигаются (Денис 07.10 06:22).
                            if let key = selectedFlightKey,
                               selectedRow(in: values) == nil,
                               let sample = store.entries.first(where: { Self.flightKey($0) == key }) {
                                hintRow("\(routeTitle(sample.flightNumber, sample.departure, sample.arrival)) в этот день не выполняется") {
                                    Button("Снять выделение") {
                                        selectedFlightKey = nil
                                        selectedRecordID = nil
                                    }
                                    .controlSize(.small)
                                }
                            }
                            if filteredCount == 0, exactSearchNumber != nil {
                                ForEach(routeCandidates) { candidate in
                                    hintRow("\(routeTitle(candidate.flightNumber, candidate.departure, candidate.arrival)) — в выбранную дату не выполняется") {
                                        if routeCandidates.count > 1 {
                                            Button(calendarRouteID == candidate.id ? "Подсвечено" : "Показать дни") {
                                                calendarRouteID = candidate.id
                                            }
                                            .controlSize(.small)
                                        }
                                    }
                                }
                            }
                            ForEach(values) { entry in
                                VStack(spacing: 0) {
                                    scheduleRow(entry, expanded: selectedRow(in: values)?.id == entry.id)
                                }
                                .id(entry.id)
                            }
                        }
                    }
                    .onChange(of: selectedDate) { _, _ in
                        // Выбранный рейс в новом дне: раскрыть его запись и прокрутить к нему.
                        guard let row = selectedRow(in: displayRows(self.values)) else { return }
                        selectedRecordID = row.id
                        DispatchQueue.main.async {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                proxy.scrollTo(row.id, anchor: .center)
                            }
                        }
                    }
                }
            }
            // «Тест»: вся таблица — в общей карточке.
            .background {
                if cardStyle {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cardStyle ? 14 : 0, style: .continuous))
            // Отступ сверху от строки даты — как между фильтром и датой (8), снизу и по бокам — 12.
            .padding(.horizontal, cardStyle ? 12 : 0)
            .padding(.bottom, cardStyle ? 12 : 0)
        }
    }

    // Ширины столбцов и шрифты — прежние (Денис 07.10 05:23: шрифт не трогать, только карточка).
    private var numberWidth: CGFloat { largeText ? 64 : 54 }
    private var timeWidth: CGFloat { largeText ? 124 : 104 }
    private var typeWidth: CGFloat { largeText ? 84 : 70 }
    private var durationWidth: CGFloat { largeText ? 90 : 70 }
    private var mainFont: Font { largeText ? .body : .subheadline }
    private var cellFont: Font { largeText ? .callout : .caption }

    @ViewBuilder
    private func scheduleRow(_ entry: FlightScheduleEntryV129, expanded isExpanded: Bool) -> some View {
        Button {
            if isExpanded {
                selectedFlightKey = nil
                selectedRecordID = nil
            } else {
                selectedFlightKey = Self.flightKey(entry)
                selectedRecordID = entry.id
            }
        } label: {
            HStack(spacing: 8) {
                Text(FlightScheduleStoreV129.displayFlightNumber(entry.flightNumber))
                    .font(mainFont.weight(.semibold).monospacedDigit())
                    .frame(width: numberWidth, alignment: .leading)
                Text("\(AirportDatabase.displayName(for: entry.departure)) → \(AirportDatabase.displayName(for: entry.arrival))")
                    .font(mainFont)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("\(clock(entry.departureMinutesUTC))–\(clock(entry.arrivalMinutesUTC))")
                    .font(cellFont.monospacedDigit())
                    .frame(width: timeWidth, alignment: .leading)
                Text(AircraftFamilyV129.display(entry.rawAircraftCode))
                    .font(cellFont.weight(.semibold))
                    .frame(width: typeWidth, alignment: .leading)
                Text(timeText(entry.flightMinutes))
                    .font(cellFont.weight(.semibold).monospacedDigit())
                    .frame(width: durationWidth, alignment: .center)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, largeText ? 8 : 5)
            .background(isExpanded ? Color.teal.opacity(0.10) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if isExpanded {
            // Доп. информация — по тем же столбцам: МСК под UTC, код и компоновка под типом ВС.
            HStack(spacing: 8) {
                Color.clear.frame(width: numberWidth, height: 1)
                Text("\(FlightScheduleStoreV129.shortDay(entry.validFrom))–\(FlightScheduleStoreV129.shortDay(entry.validTo)) · дни \(entry.operatingWeekdays.map(String.init).joined())")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(moscowClock(entry.departureMinutesUTC))–\(moscowClock(entry.arrivalMinutesUTC))")
                    .monospacedDigit()
                    .frame(width: timeWidth, alignment: .leading)
                    .overlay(alignment: .leading) {
                        Text("МСК")
                            .fixedSize()
                            .offset(x: -30)
                    }
                Text(entry.rawAircraftCode + (entry.configuration.map { "  ·  \($0)" } ?? ""))
                    .lineLimit(1)
                    .frame(width: typeWidth + 8 + durationWidth, alignment: .leading)
            }
            .font(cellFont)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.bottom, 5)
            .background(Color.teal.opacity(0.10))
        }
        Divider()
    }

    private func hintRow<Trailing: View>(
        _ text: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                trailing()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.teal.opacity(0.10))
            Divider()
        }
    }

    private func clock(_ minutes: Int) -> String {
        String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }

    /// Время по Москве из минут UTC (Москва — UTC+3 круглый год).
    private func moscowClock(_ utcMinutes: Int) -> String {
        let offset = moscowTimeZone.secondsFromGMT() / 60
        let value = ((utcMinutes + offset) % 1440 + 1440) % 1440
        return clock(value)
    }
}


private struct FlightScheduleRouteCandidateV131: Identifiable {
    let flightNumber: String
    let departure: String
    let arrival: String
    let entries: [FlightScheduleEntryV129]
    var id: String { "\(FlightScheduleStoreV129.normalizedFlightNumber(flightNumber))|\(departure)|\(arrival)" }
}


struct FlightScheduleSettingsV129View: View {
    @ObservedObject private var store = FlightScheduleStoreV129.shared

    /// Коды из расписания, которых нет в справочнике аэропортов (пришли скрин — допишем).
    private var unknownAirports: [String] {
        var codes = Set<String>()
        for entry in store.entries {
            codes.insert(entry.departure)
            codes.insert(entry.arrival)
        }
        return codes.filter { !AirportDatabase.isKnown($0) }.sorted()
    }
    @State private var showImporter = false
    @State private var message = ""
    @State private var showMessage = false
    @State private var showDelete = false
    @State private var pendingDeleteImport: FlightScheduleImportRecordV129?

    var body: some View {
        List {
            Section("Состояние") {
                LabeledContent("Строк в базе", value: String(store.entries.count))
                LabeledContent("Покрытие", value: store.coverageText)
                LabeledContent("Импортов", value: String(store.imports.count))
                LabeledContent("Аэропорты без названия", value: String(unknownAirports.count))
                if !unknownAirports.isEmpty {
                    Text(unknownAirports.joined(separator: ", "))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                NavigationLink {
                    FlightScheduleDatabaseV130View()
                } label: {
                    Label("Открыть базу расписания", systemImage: "list.bullet.rectangle")
                }
                .disabled(store.entries.isEmpty)
            }

            Section {
                Button {
                    showImporter = true
                } label: {
                    Label("Импортировать расписание", systemImage: "square.and.arrow.down")
                }

                Button("Удалить все расписания", role: .destructive) {
                    showDelete = true
                }
                .disabled(store.entries.isEmpty)
            } footer: {
                Text("Загружается .xls с листом «UTC». Вид перевозки игнорируется; данные используются только как плановое расписание.")
            }

            if !store.imports.isEmpty {
                Section("Загруженные расписания") {
                    ForEach(store.imports) { value in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(FlightScheduleStoreV129.shortDay(value.validFrom))–\(FlightScheduleStoreV129.shortDay(value.validTo))")
                            .font(.subheadline.weight(.semibold))
                        Text("\(value.rowCount.formatted(.number.grouping(.automatic))) строк · импорт \(importDate(value.importedAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(role: .destructive) {
                        pendingDeleteImport = value
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
                }
            }
        }
        .navigationTitle("Расписание рейсов")
        .navigationBarTitleDisplayMode(.inline)
        .aeroStableNavigationBar()
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType(filenameExtension: "xls") ?? .data]
        ) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                let summary = try store.importXLS(data: data, sourceName: url.lastPathComponent)
        if summary.unchanged {
            message = "Это расписание уже загружено. Обновлений нет."
        } else {
            message = "Импорт завершён. Добавлено: \(summary.added), обновлено: \(summary.updated), удалено устаревших: \(summary.removed). В базе: \(summary.total) строк."
        }
            } catch {
                message = error.localizedDescription
            }
            showMessage = true
        }
        .alert("Расписание рейсов", isPresented: $showMessage) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(message)
        }
        .alert("Удалить всё расписание?", isPresented: $showDelete) {
            Button("Отмена", role: .cancel) { }
            Button("Удалить", role: .destructive) { store.deleteAll() }
        } message: {
            Text("Будет очищена только локальная база расписания рейсов. История и планы не изменятся.")
        }
    .alert(
        "Удалить выбранное расписание?",
        isPresented: Binding(
            get: { pendingDeleteImport != nil },
            set: { if !$0 { pendingDeleteImport = nil } }
        )
    ) {
        Button("Отмена", role: .cancel) { pendingDeleteImport = nil }
        Button("Удалить", role: .destructive) {
            if let value = pendingDeleteImport {
                store.deleteImport(id: value.id)
            }
            pendingDeleteImport = nil
        }
    } message: {
        if let value = pendingDeleteImport {
            Text("\(FlightScheduleStoreV129.shortDay(value.validFrom))–\(FlightScheduleStoreV129.shortDay(value.validTo)) будет удалено из локальной базы.")
        }
    }

    }

    private func importDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = moscowTimeZone
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter.string(from: date)
    }
}
