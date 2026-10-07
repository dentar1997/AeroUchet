import SwiftUI
import UIKit

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
    /// Дни, когда этот рейс выполняется на неотмеченных в фильтре типах ВС — серый круг.
    var tertiaryDays: Set<String> = []
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

            if !primaryDays.isEmpty || !secondaryDays.isEmpty || !tertiaryDays.isEmpty {
                HStack(spacing: 10) {
                    if let legend, !primaryDays.isEmpty {
                        HStack(spacing: 4) {
                            Circle().fill(Color.teal).frame(width: 10, height: 10)
                            Text(legend)
                        }
                    }
                    if !secondaryDays.isEmpty {
                        HStack(spacing: 4) {
                            Circle().fill(Color.teal.opacity(0.35)).frame(width: 10, height: 10)
                            Text("другие периоды")
                        }
                    }
                    if !tertiaryDays.isEmpty {
                        HStack(spacing: 4) {
                            Circle().fill(Color.gray.opacity(0.45)).frame(width: 10, height: 10)
                            Text("на других типах ВС")
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
        let isTertiary = !isPrimary && !isSecondary && tertiaryDays.contains(key)
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
                } else if isTertiary {
                    Circle().fill(Color.gray.opacity(0.45)).padding(3)
                }
                // Выбранный день — обводка цвета текста (в тёмной теме белая).
                if isSelected {
                    Circle().strokeBorder(Color.primary, lineWidth: 2)
                }
                Text(String(moscowCalendar.component(.day, from: day)))
                    .font(.callout.monospacedDigit().weight(isToday || isSelected ? .bold : .regular))
                    // Сегодня — красная цифра на любом фоне (Денис 07.10).
                    .foregroundStyle(isToday ? Color.red : (isPrimary ? Color.white : Color.primary))
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


// MARK: - Барабан «месяц · год»
//
// Свой барабан вместо системного UIPickerView (системные элементы в Playgrounds
// мешают физической клавиатуре). Повторяет системный: инерция и остановка ровно
// на строке, строки к краям поворачиваются и тускнеют, полоса выбора посередине,
// месяцы по кругу, щелчок вибрацией на каждой строке.

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

            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color(uiColor: .tertiarySystemFill))
                    .frame(height: DrumColumn.rowHeight)
                    .padding(.horizontal, 10)
                HStack(spacing: 0) {
                    DrumColumn(
                        count: 12,
                        isCircular: true,
                        selection: $month,
                        valueAt: { $0 + 1 },
                        label: { ScheduleMonthsCalendarView.monthNames[$0 - 1] },
                        alignment: .trailing
                    )
                    DrumColumn(
                        count: years.count,
                        isCircular: false,
                        selection: $year,
                        valueAt: { years[$0] },
                        label: { String($0) },
                        alignment: .leading
                    )
                }
                .padding(.horizontal, 6)
            }
            .frame(height: DrumColumn.height)
            .padding(.bottom, 12)
        }
        .frame(width: 250)
    }
}

/// Одна колонка барабана. `valueAt` — значение по номеру строки внутри круга.
private struct DrumColumn: View {
    static let rowHeight: CGFloat = 36
    static let height: CGFloat = 216
    /// Радиус цилиндра: на половину высоты окна приходится чуть меньше четверти оборота.
    static let radius: CGFloat = 92
    /// Сколько раз повторяются строки круговой колонки (месяцы «бесконечные»).
    private static let laps = 200

    let count: Int
    let isCircular: Bool
    @Binding var selection: Int
    let valueAt: (Int) -> Int
    let label: (Int) -> String
    let alignment: Alignment

    @State private var centered: Int?
    @State private var didAppear = false

    private var total: Int { isCircular ? count * Self.laps : count }

    private func value(atRow row: Int) -> Int {
        valueAt(((row % count) + count) % count)
    }

    private func initialRow() -> Int {
        let local = (0..<count).first { valueAt($0) == selection } ?? 0
        return isCircular ? count * (Self.laps / 2) + local : local
    }

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(0..<total, id: \.self) { row in
                    // Значения снаружи замыкания visualEffect: в Playgrounds код по умолчанию
                    // на главном акторе, а visualEffect выполняется вне его.
                    let center = Self.height / 2
                    let radius = Self.radius
                    Text(label(value(atRow: row)))
                        .font(.title3)
                        .monospacedDigit()
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: alignment)
                        .padding(.horizontal, 6)
                        .frame(height: Self.rowHeight)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.25)) { centered = row }
                        }
                        .visualEffect { content, proxy in
                            // Строка лежит на цилиндре: угол — по расстоянию от центра окна,
                            // высота — проекция дуги (строки к краям сжимаются и сближаются),
                            // поворот вокруг горизонтальной оси, к краям тускнеет.
                            let frame = proxy.frame(in: .named("drumViewport"))
                            let distance = frame.midY - center
                            let angle = max(-Double.pi / 2, min(Double.pi / 2, Double(distance / radius)))
                            let projected = radius * CGFloat(sin(angle))
                            return content
                                .rotation3DEffect(
                                    .radians(-angle),
                                    axis: (x: 1, y: 0, z: 0),
                                    anchor: .center,
                                    perspective: 0.35
                                )
                                .offset(y: projected - distance)
                                .opacity(max(0, cos(angle)) * 0.85 + (abs(angle) < 0.15 ? 0.15 : 0))
                        }
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $centered, anchor: .center)
        .coordinateSpace(.named("drumViewport"))
        .contentMargins(.vertical, (Self.height - Self.rowHeight) / 2, for: .scrollContent)
        .frame(height: Self.height)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.25),
                    .init(color: .black, location: 0.75),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            guard !didAppear else { return }
            didAppear = true
            centered = initialRow()
        }
        .onChange(of: centered) { _, row in
            guard let row else { return }
            let newValue = value(atRow: row)
            guard newValue != selection else { return }
            selection = newValue
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}


// MARK: - Фильтр типов ВС (v145): несколько типов сразу, хотя бы один отмечен

struct ScheduleAircraftFilterButton: View {
    @Binding var selection: Set<FlightScheduleAircraftGroupV131>
    /// Открыто ли своё выпадающее окно (рисует его экран расписания, см. `ScheduleAircraftMenuPanel`).
    @Binding var isOpen: Bool
    /// Где кнопка на экране — чтобы окно выпало ровно под ней.
    @Binding var frame: CGRect

    static let choices = FlightScheduleAircraftGroupV131.allCases.filter { $0 != .all }

    var body: some View {
        // Вид как у «с 00 / до 24»: серая плашка, скругление 8, высота 34.
        HStack(spacing: 6) {
            Text(Self.title(selection))
                .font(.caption.bold())
                .monospacedDigit()
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .scheduleFilterTile(active: isOpen)
        .contentShape(Rectangle())
        .onTapGesture { isOpen.toggle() }
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { value in
            frame = value
        }
    }

    static func title(_ selection: Set<FlightScheduleAircraftGroupV131>) -> String {
        if selection.count >= choices.count { return "Тип ВС" }
        if selection.count == 1, let only = selection.first { return only.rawValue }
        return "Тип ВС · \(selection.count)"
    }

    static func toggle(_ value: FlightScheduleAircraftGroupV131, in selection: inout Set<FlightScheduleAircraftGroupV131>) {
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


// MARK: - Часы «с / до» нашей крутилкой из задания на полёт (только часы)

struct ScheduleHourWheelField: View {
    let title: String
    @Binding var hour: Int
    let range: ClosedRange<Int>
    let isActive: Bool
    let onActivate: () -> Void
    /// Где поле на экране — чтобы тап мимо закрывал крутилку.
    @Binding var frame: CGRect

    private func text(_ value: Int) -> String { String(format: "%02d", value) }

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            InlineFlightWheelSegment(
                value: text(hour),
                previous: hour > range.lowerBound ? text(hour - 1) : "",
                next: hour < range.upperBound ? text(hour + 1) : "",
                width: 17,
                hitWidth: 44,
                hitOffset: 0,
                hitHeight: 48,
                isEditing: true,
                isActive: isActive,
                valueColor: isActive ? Color.teal : Color.primary,
                onActivate: onActivate,
                onStep: { delta in
                    hour = min(range.upperBound, max(range.lowerBound, hour + delta))
                },
                canStepPrevious: true
            )
        }
        .scheduleFilterTile(active: isActive)
        .contentShape(Rectangle())
        .onTapGesture(perform: onActivate)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { value in
            frame = value
        }
    }
}


/// Своё выпадающее окно типов ВС (скругление как у кнопок фильтра). Не закрывается
/// при выборе; закрывается тапом мимо — это делает экран, который его показывает.
struct ScheduleAircraftMenuPanel: View {
    @Binding var selection: Set<FlightScheduleAircraftGroupV131>

    var body: some View {
        VStack(spacing: 0) {
            ForEach(ScheduleAircraftFilterButton.choices) { value in
                HStack {
                    Text(value.rawValue)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if selection.contains(value) {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                            .foregroundStyle(.teal)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 40)
                .contentShape(Rectangle())
                .onTapGesture {
                    ScheduleAircraftFilterButton.toggle(value, in: &selection)
                }
                if value != ScheduleAircraftFilterButton.choices.last {
                    Divider().padding(.leading, 14)
                }
            }
        }
        .frame(width: 190)
        .background(
            RoundedRectangle(cornerRadius: ScheduleFilterStyle.cornerRadius)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ScheduleFilterStyle.cornerRadius)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
    }
}


// MARK: - Единый вид полей и кнопок фильтра (Денис 07.10 04:15–04:17)
//
// Форма — как ячейка задания на полёт («Начало работы»): та же пропорция скругления
// (у ячейки ~48 pt — радиус 10, у поля 34 pt — радиус 7) и тот же цвет плашки.

enum ScheduleFilterStyle {
    static let cornerRadius: CGFloat = 7
    static let height: CGFloat = 34
    static let fill = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.36, alpha: 1)
            : UIColor(white: 0.88, alpha: 1)
    })
}

extension View {
    func scheduleFilterTile(active: Bool = false) -> some View {
        padding(.horizontal, 10)
            .frame(height: ScheduleFilterStyle.height)
            .background(
                RoundedRectangle(cornerRadius: ScheduleFilterStyle.cornerRadius)
                    // Без бирюзовой заливки при выборе (Денис 07.10 04:49): бирюзовые только цифры.
                    .fill(ScheduleFilterStyle.fill)
            )
    }
}
