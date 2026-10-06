import SwiftUI

// MARK: - Календарь базы расписания (v145)
//
// Обычный календарь: любой день нажимается. Если выбран рейс (раскрыта строка
// или в поиске точный номер с одним маршрутом), его дни выполнения залиты кругом.
// Месяцы листаются вертикально, размер постоянный — ничего не прыгает.

struct ScheduleMonthsCalendarView: View {
    @Binding var selectedDate: Date
    /// Дни выполнения раскрытой записи расписания — сплошной круг (ключи `ГГГГ-ММ-ДД`, Москва).
    let primaryDays: Set<String>
    /// Остальные дни того же рейса по тому же маршруту (другие записи) — бледный круг.
    let secondaryDays: Set<String>
    let title: String?
    /// Подпись под календарём, например «эта запись 05.10–25.10, дни 257».
    let legend: String?

    @State private var scrollTarget: String?
    @State private var showJump = false

    private static let weekdaySymbols = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text(title ?? "Календарь")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Button {
                    showJump = true
                } label: {
                    Image(systemName: "calendar")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .popover(isPresented: $showJump) {
                    ScheduleMonthYearWheel(
                        initial: selectedDate,
                        years: Self.years
                    ) { month in
                        showJump = false
                        scrollTarget = Self.monthID(month)
                    }
                    .presentationCompactAdaptation(.popover)
                }
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
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(Self.months, id: \.self) { month in
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

            if let legend, !primaryDays.isEmpty || !secondaryDays.isEmpty {
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.teal).frame(width: 10, height: 10)
                        Text(legend)
                    }
                    if !secondaryDays.isEmpty {
                        HStack(spacing: 4) {
                            Circle().fill(Color.teal.opacity(0.35)).frame(width: 10, height: 10)
                            Text("другие периоды")
                        }
                    }
                    Spacer(minLength: 0)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
    }

    // MARK: Месяцы

    /// С января 2010 года до +5 лет от сегодня. Рисуются только видимые месяцы.
    private static let months: [Date] = {
        guard let first = moscowCalendar.date(from: DateComponents(year: 2010, month: 1, day: 1)),
              let last = moscowCalendar.date(byAdding: .month, value: 60, to: monthStart(Date())) else {
            return [monthStart(Date())]
        }
        var result: [Date] = []
        var month = first
        while month <= last {
            result.append(month)
            guard let next = moscowCalendar.date(byAdding: .month, value: 1, to: month) else { break }
            month = next
        }
        return result
    }()

    private static let years: [Int] = {
        Array(Set(months.map { moscowCalendar.component(.year, from: $0) })).sorted()
    }()

    private func monthSection(_ month: Date) -> some View {
        let days = Self.days(in: month)
        let monthKeyPrefix = String(Self.dayKey(month).prefix(8))
        let count = primaryDays.isEmpty && secondaryDays.isEmpty
            ? 0
            : primaryDays.union(secondaryDays).filter { $0.hasPrefix(monthKeyPrefix) }.count
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
                                Color.clear.frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40)
                            }
                        }
                    }
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let key = Self.dayKey(day)
        let isPrimary = primaryDays.contains(key)
        let isSecondary = !isPrimary && secondaryDays.contains(key)
        let isSelected = moscowCalendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = moscowCalendar.isDateInToday(day)
        return Button {
            selectedDate = day
        } label: {
            ZStack {
                if isPrimary {
                    Circle().fill(Color.teal).padding(3)
                } else if isSecondary {
                    Circle().fill(Color.teal.opacity(0.35)).padding(3)
                }
                // Выбранный день — обводка цвета текста (в тёмной теме белая).
                if isSelected {
                    Circle().strokeBorder(Color.primary, lineWidth: 2)
                }
                // Сегодня — красное кольцо, видно и на закрашенном дне.
                if isToday {
                    Circle().strokeBorder(Color.red, lineWidth: 2).padding(isSelected ? 4 : 1)
                }
                Text(String(moscowCalendar.component(.day, from: day)))
                    .font(.callout.monospacedDigit().weight(isToday || isSelected ? .bold : .regular))
                    .foregroundStyle(isPrimary ? Color.white : Color.primary)
            }
            .frame(width: 38, height: 38)
            .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Даты

    static func dayKey(_ date: Date) -> String {
        let parts = moscowCalendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func monthID(_ date: Date) -> String {
        String(dayKey(date).prefix(7))
    }

    static func monthStart(_ date: Date) -> Date {
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

    static let monthNames = [
        "Январь", "Февраль", "Март", "Апрель", "Май", "Июнь",
        "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"
    ]

    private static func monthTitle(_ month: Date) -> String {
        let parts = moscowCalendar.dateComponents([.year, .month], from: month)
        let name = monthNames[max(0, min(11, (parts.month ?? 1) - 1))]
        return "\(name) \(parts.year ?? 0)"
    }
}


// MARK: - Крутилка «месяц · год» (без системного Picker: он ломает клавиатуру в Playgrounds)

private struct ScheduleMonthYearWheel: View {
    let years: [Int]
    let onGo: (Date) -> Void

    @State private var month: Int
    @State private var year: Int

    init(initial: Date, years: [Int], onGo: @escaping (Date) -> Void) {
        self.years = years
        self.onGo = onGo
        let parts = moscowCalendar.dateComponents([.year, .month], from: initial)
        _month = State(initialValue: parts.month ?? 1)
        _year = State(initialValue: parts.year ?? 2026)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Перейти к месяцу")
                    .font(.headline)
                Spacer()
                Button("Перейти") {
                    if let date = moscowCalendar.date(from: DateComponents(year: year, month: month, day: 1)) {
                        onGo(date)
                    }
                }
                .fontWeight(.semibold)
            }
            .padding()

            Divider()

            HStack(spacing: 0) {
                ScheduleWheelColumn(
                    values: Array(1...12),
                    selection: month,
                    label: { ScheduleMonthsCalendarView.monthNames[$0 - 1] }
                ) { month = $0 }
                ScheduleWheelColumn(
                    values: years,
                    selection: year,
                    label: { String($0) }
                ) { year = $0 }
            }
            .padding(.horizontal, 12)
        }
        .frame(width: 320, height: 290)
    }
}

private struct ScheduleWheelColumn: View {
    let values: [Int]
    let selection: Int
    let label: (Int) -> String
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(values, id: \.self) { value in
                        Button {
                            onSelect(value)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(value, anchor: .center)
                            }
                        } label: {
                            Text(label(value))
                                .font(value == selection ? .title3.weight(.semibold) : .body)
                                .monospacedDigit()
                                .foregroundStyle(value == selection ? .primary : .secondary)
                                .frame(maxWidth: .infinity, minHeight: 38)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .id(value)
                    }
                }
                .padding(.vertical, 80)
            }
            .onAppear {
                DispatchQueue.main.async {
                    proxy.scrollTo(selection, anchor: .center)
                }
            }
        }
        .frame(maxWidth: .infinity)
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
