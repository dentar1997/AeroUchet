import SwiftUI

// MARK: - Календарь базы расписания (v145)
//
// Обычный календарь: любой день нажимается. Если выбран рейс (раскрыта строка
// или в поиске точный номер с одним маршрутом), его дни выполнения залиты кругом.
// Месяцы листаются вертикально, размер постоянный — ничего не прыгает.

struct ScheduleMonthsCalendarView: View {
    @Binding var selectedDate: Date
    /// Дни выполнения рейса — ключи `ГГГГ-ММ-ДД` по Москве. Пусто — без подсветки.
    let highlightedDays: Set<String>
    let title: String?

    @State private var scrollTarget: String?

    private static let weekdaySymbols = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text(title ?? "Календарь")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                jumpMenu
                Button("Сегодня") {
                    let today = moscowCalendar.startOfDay(for: Date())
                    selectedDate = today
                    scrollTarget = Self.monthID(today)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack(spacing: 0) {
                ForEach(Self.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(symbol == "Сб" || symbol == "Вс" ? .secondary : .primary)
                        .frame(maxWidth: .infinity)
                }
            }
            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14, pinnedViews: []) {
                        ForEach(months, id: \.self) { month in
                            monthSection(month)
                                .id(Self.monthID(month))
                        }
                    }
                    .padding(.vertical, 6)
                }
                .onAppear {
                    proxy.scrollTo(Self.monthID(selectedDate), anchor: .top)
                }
                .onChange(of: scrollTarget) { _, target in
                    guard let target else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(target, anchor: .top)
                    }
                    scrollTarget = nil
                }
            }
        }
    }

    // MARK: Месяцы

    /// Год назад и год вперёд от сегодня; выбранная дата всегда внутри.
    private var months: [Date] {
        let today = Self.monthStart(Date())
        let selected = Self.monthStart(selectedDate)
        guard var first = moscowCalendar.date(byAdding: .month, value: -12, to: today),
              var last = moscowCalendar.date(byAdding: .month, value: 12, to: today) else {
            return [selected]
        }
        if selected < first { first = selected }
        if selected > last { last = selected }
        var result: [Date] = []
        var month = first
        while month <= last {
            result.append(month)
            guard let next = moscowCalendar.date(byAdding: .month, value: 1, to: month) else { break }
            month = next
        }
        return result
    }

    private var jumpMenu: some View {
        let byYear = Dictionary(grouping: months) { moscowCalendar.component(.year, from: $0) }
        return Menu {
            ForEach(byYear.keys.sorted(), id: \.self) { year in
                Section(String(year)) {
                    ForEach(byYear[year] ?? [], id: \.self) { month in
                        Button(Self.monthTitle(month)) {
                            scrollTarget = Self.monthID(month)
                        }
                    }
                }
            }
        } label: {
            Label("Месяц", systemImage: "calendar")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func monthSection(_ month: Date) -> some View {
        let days = Self.days(in: month)
        let monthKeyPrefix = String(Self.dayKey(month).prefix(8))
        let count = highlightedDays.isEmpty
            ? 0
            : highlightedDays.filter { $0.hasPrefix(monthKeyPrefix) }.count
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(Self.monthTitle(month))
                    .font(.headline)
                if count > 0 {
                    Text("· \(count) дн.")
                        .font(.subheadline)
                        .foregroundStyle(.teal)
                }
            }
            .padding(.horizontal, 4)

            let leading = Self.leadingBlanks(month)
            let cells: [Date?] = Array(repeating: nil, count: leading) + days.map { Optional($0) }
            let rows = stride(from: 0, to: cells.count, by: 7).map {
                Array(cells[$0..<min($0 + 7, cells.count)])
            }
            VStack(spacing: 2) {
                ForEach(rows.indices, id: \.self) { index in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { column in
                            let row = rows[index]
                            if column < row.count, let day = row[column] {
                                dayCell(day)
                            } else {
                                Color.clear.frame(maxWidth: .infinity, minHeight: 38, maxHeight: 38)
                            }
                        }
                    }
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let key = Self.dayKey(day)
        let isHighlighted = highlightedDays.contains(key)
        let isSelected = moscowCalendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = moscowCalendar.isDateInToday(day)
        return Button {
            selectedDate = day
        } label: {
            ZStack {
                if isHighlighted {
                    Circle().fill(Color.teal)
                }
                if isSelected {
                    Circle().strokeBorder(Color.primary, lineWidth: 2)
                }
                Text(String(moscowCalendar.component(.day, from: day)))
                    .font(.callout.monospacedDigit().weight(isToday || isSelected ? .bold : .regular))
                    .foregroundStyle(
                        isHighlighted ? Color.white : (isToday ? Color.red : Color.primary)
                    )
            }
            .frame(width: 34, height: 34)
            .frame(maxWidth: .infinity, minHeight: 38, maxHeight: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Даты

    static func dayKey(_ date: Date) -> String {
        let parts = moscowCalendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private static func monthID(_ date: Date) -> String {
        String(dayKey(date).prefix(7))
    }

    private static func monthStart(_ date: Date) -> Date {
        let parts = moscowCalendar.dateComponents([.year, .month], from: date)
        return moscowCalendar.date(from: parts) ?? moscowCalendar.startOfDay(for: date)
    }

    private static func days(in month: Date) -> [Date] {
        guard let range = moscowCalendar.range(of: .day, in: .month, for: month) else { return [] }
        return range.compactMap { moscowCalendar.date(byAdding: .day, value: $0 - 1, to: month) }
    }

    /// Пустые клетки до первого числа (неделя с понедельника).
    private static func leadingBlanks(_ month: Date) -> Int {
        let weekday = moscowCalendar.component(.weekday, from: month) // 1 = вс
        return (weekday + 5) % 7
    }

    private static let monthNames = [
        "Январь", "Февраль", "Март", "Апрель", "Май", "Июнь",
        "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"
    ]

    private static func monthTitle(_ month: Date) -> String {
        let parts = moscowCalendar.dateComponents([.year, .month], from: month)
        let name = monthNames[max(0, min(11, (parts.month ?? 1) - 1))]
        return "\(name) \(parts.year ?? 0)"
    }
}


// MARK: - Фильтр типов ВС (v145): несколько типов сразу, хотя бы один отмечен

struct ScheduleAircraftFilterButton: View {
    @Binding var selection: Set<FlightScheduleAircraftGroupV131>
    @State private var isOpen = false

    static let choices = FlightScheduleAircraftGroupV131.allCases.filter { $0 != .all }

    var body: some View {
        Button {
            isOpen = true
        } label: {
            HStack(spacing: 4) {
                Text(title)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
        }
        .buttonStyle(.bordered)
        .popover(isPresented: $isOpen) {
            VStack(spacing: 0) {
                ForEach(Self.choices) { value in
                    Button {
                        toggle(value)
                    } label: {
                        HStack {
                            Text(value.rawValue)
                            Spacer()
                            if selection.contains(value) {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.teal)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if value != Self.choices.last { Divider() }
                }
            }
            .frame(width: 220)
            .presentationCompactAdaptation(.popover)
        }
    }

    private var title: String {
        if selection.count >= Self.choices.count { return "Тип ВС" }
        if selection.count == 1, let only = selection.first { return only.rawValue }
        return "Тип ВС · \(selection.count)"
    }

    private func toggle(_ value: FlightScheduleAircraftGroupV131) {
        if selection.contains(value) {
            guard selection.count > 1 else { return } // последний тип не снимается
            selection.remove(value)
        } else {
            selection.insert(value)
        }
    }

    // Хранение выбора между заходами в базу расписания.
    static let storageKey = "aerouchet.scheduleBrowser.aircraftGroups"

    static func decode(_ raw: String) -> Set<FlightScheduleAircraftGroupV131> {
        let values = Set(raw.split(separator: ",").compactMap {
            FlightScheduleAircraftGroupV131(rawValue: String($0))
        }).subtracting([.all])
        return values.isEmpty ? Set(choices) : values
    }

    static func encode(_ value: Set<FlightScheduleAircraftGroupV131>) -> String {
        choices.filter(value.contains).map(\.rawValue).joined(separator: ",")
    }

    /// Рейс проходит фильтр. Отмечены все типы — фильтра нет (и прочие типы видны).
    static func matches(_ selection: Set<FlightScheduleAircraftGroupV131>, rawAircraftCode: String) -> Bool {
        if selection.count >= choices.count { return true }
        return selection.contains { $0.contains(rawAircraftCode: rawAircraftCode) }
    }
}
