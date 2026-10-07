import SwiftUI
import UIKit
import CoreImage

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
    /// Колонка справа от таблицы (Денис 07.10 05:39): кнопки как у фильтра, заголовок как строка
    /// даты, сам календарь — в карточке; дни недели на одной линии с заголовками таблицы.
    var cardLayout = false

    @State private var scrollTarget: String?
    @State private var showJump = false
    @State private var jumpPanelFrame: CGRect = .zero
    @State private var jumpButtonFrame: CGRect = .zero

    private static let weekdaySymbols = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    /// Высота строки заголовков (дни недели и «Рейс · Маршрут…» слева — на одной линии).
    static let headerHeight: CGFloat = 40
    /// Компактная сетка под iPad 12.9: в карточке целиком три месяца по шесть недель + легенда.
    // 07.10 12:12: ровно три месяца (текущий и два следующих) + место под легенду.
    private static let rowHeight: CGFloat = 38
    private static let dayCircle: CGFloat = 32

    var body: some View {
        if cardLayout {
            VStack(spacing: 8) {
                // Сверху строка рейса (как строка даты слева), под ней кнопки у левого края.
                HStack {
                    Text(title ?? "Календарь")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        // Длинный маршрут не обрезается, а уменьшается.
                        .minimumScaleFactor(0.55)
                    Spacer(minLength: 0)
                }
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .foregroundStyle(.teal)
                        .scheduleFilterTile()
                        .contentShape(Rectangle())
                        .onTapGesture { showJump.toggle() }
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { jumpButtonFrame = $0 }
                        .overlay(alignment: .topLeading) {
                            // Своё окно «стекло» под кнопкой (Денис 07.10 11:37), не системный popover.
                            if showJump {
                                ScheduleMonthYearWheel(
                                    initial: selectedDate,
                                    years: Self.years
                                ) { month in
                                    showJump = false
                                    scrollTarget = Self.monthID(month)
                                }
                                .scheduleGlassPanel()
                                .fixedSize()
                                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { jumpPanelFrame = $0 }
                                .offset(y: ScheduleFilterStyle.height + 6)
                            }
                        }
                    Text("Сегодня")
                        .font(.caption.bold())
                        .scheduleFilterTile()
                        .contentShape(Rectangle())
                        .onTapGesture(perform: goToday)
                    Spacer(minLength: 0)
                }
                .zIndex(1)
                .onReceive(NotificationCenter.default.publisher(for: ScheduleTapCatcher.tapNotification)) { note in
                    guard showJump, let point = note.object as? CGPoint else { return }
                    if !jumpPanelFrame.contains(point) && !jumpButtonFrame.contains(point) {
                        showJump = false
                    }
                }
                VStack(spacing: 0) {
                    weekdayRow
                        .font(.caption.weight(.semibold))
                        // Та же высота, что у строки заголовков таблицы слева.
                        .frame(height: ScheduleMonthsCalendarView.headerHeight)
                    Divider()
                    monthsList
                        .padding(.horizontal, 8)
                    // Место под легенду есть всегда: выбрал рейс — дни не срезаются.
                    legendRow
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        } else {
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Text(title ?? "Календарь")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    jumpButton
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Button("Сегодня", action: goToday)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                weekdayRow
                    .font(.caption2.weight(.semibold))
                Divider()
                monthsList
                legendRow
            }
        }
    }

    private func goToday() {
        let today = moscowCalendar.startOfDay(for: Date())
        selectedDate = today
        scrollTarget = Self.monthID(today)
    }

    private var jumpButton: some View {
        Button {
            showJump = true
        } label: {
            Image(systemName: "calendar")
        }
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
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(Self.weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    // Все дни недели серым, как заголовки таблицы слева.
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
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
    }

    @ViewBuilder
    private var legendRow: some View {
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
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(Self.monthTitle(month))
                    .font(.subheadline.weight(.semibold))
                if count > 0 {
                    Text("· \(count) дн.")
                        .font(.caption)
                        .foregroundStyle(.teal)
                }
            }
            .padding(.horizontal, 4)

            let leading = Self.leadingBlanks(month)
            // Всегда 6 недель: все месяцы одной высоты, прокрутка к месяцу встаёт ровно.
            let filled: [Date?] = Array(repeating: nil, count: leading) + days.map { Optional($0) }
            let cells: [Date?] = filled + Array(repeating: nil, count: max(0, 42 - filled.count))
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
                                Color.clear.frame(maxWidth: .infinity, minHeight: Self.rowHeight, maxHeight: Self.rowHeight)
                            }
                        }
                    }
                }
            }
        }
        // Отступ сверху внутри месяца: при прокрутке к нему название не срезается.
        .padding(.top, 6)
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
            .frame(width: Self.dayCircle, height: Self.dayCircle)
            .frame(maxWidth: .infinity, minHeight: Self.rowHeight, maxHeight: Self.rowHeight)
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
            // Надпись слева сверху, галочка справа (Денис 07.10 13:26).
            HStack {
                Text("Перейти к месяцу")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    if let date = moscowCalendar.date(from: DateComponents(year: year, month: month, day: 1)) {
                        onGo(date)
                    }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.teal)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Self.gap)
            .padding(.top, 12)
            .padding(.bottom, 2)

            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color(uiColor: .tertiarySystemFill))
                    .frame(height: DrumColumn.rowHeight)
                    .padding(.horizontal, 10)
                // Месяц и год разнесены; отступы до краёв окна — как промежуток между ними.
                HStack(spacing: Self.gap) {
                    DrumColumn(
                        count: 12,
                        isCircular: true,
                        selection: $month,
                        valueAt: { $0 + 1 },
                        label: { ScheduleMonthsCalendarView.monthNames[$0 - 1] },
                        alignment: .trailing
                    )
                    .frame(width: Self.monthWidth)
                    DrumColumn(
                        count: years.count,
                        isCircular: false,
                        selection: $year,
                        valueAt: { years[$0] },
                        label: { String($0) },
                        alignment: .leading
                    )
                    .frame(width: Self.yearWidth)
                }
                .padding(.horizontal, Self.gap)
            }
            .frame(height: DrumColumn.height)
            .padding(.bottom, 12)
        }
        // Квадратное окно (Денис 07.10 13:03): ширина = высоте, промежутки поровну.
        .frame(width: Self.side, height: Self.side)
    }

    static let side: CGFloat = 264
    static let gap: CGFloat = max(16, (side - monthWidth - yearWidth) / 3)
    // Колонки ровно по самому длинному месяцу и году: слева от месяца и справа от года
    // остаются одинаковые отступы (= промежутку между ними).
    private static func textWidth(_ text: String) -> CGFloat {
        // Как в барабане: .title3 с моноширинными цифрами (иначе год не влезал — «20…»).
        let size = UIFont.preferredFont(forTextStyle: .title3).pointSize
        let font = UIFont.monospacedDigitSystemFont(ofSize: size, weight: .regular)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width) + 8
    }
    static let monthWidth: CGFloat = ScheduleMonthsCalendarView.monthNames.map(textWidth).max() ?? 110
    static let yearWidth: CGFloat = textWidth("2026")
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
                        // Никогда не сокращать до «…».
                        .fixedSize()
                        .frame(maxWidth: .infinity, alignment: alignment)
                        .padding(.horizontal, 2)
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
    /// Где окно — тап мимо кнопки и окна его закрывает (без «ловушки», прокрутка работает).
    @Binding var panelFrame: CGRect

    static let choices = FlightScheduleAircraftGroupV131.allCases.filter { $0 != .all }

    var body: some View {
        // Вид как у «с 00 / до 24»: серая плашка, скругление 8, высота 34.
        HStack(spacing: 6) {
            Text(Self.title(selection))
                .font(.caption.bold())
                .monospacedDigit()
                .lineLimit(1)
                // Текст всегда целиком, в одну строку: кнопка не сжимается.
                .fixedSize()
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
        .overlay(alignment: .topLeading) {
            if isOpen {
                ScheduleAircraftMenuPanel(selection: $selection)
                    .fixedSize()
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { panelFrame = $0 }
                    .offset(y: ScheduleFilterStyle.height + 6)
            }
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
                .padding(.horizontal, 12)
                .frame(height: 32)
                .contentShape(Rectangle())
                .onTapGesture {
                    ScheduleAircraftFilterButton.toggle(value, in: &selection)
                }
                if value != ScheduleAircraftFilterButton.choices.last {
                    // Еле заметная полоска, отступы слева и справа одинаковые (Денис 07.10 12:48).
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 0.5)
                        .padding(.horizontal, 12)
                }
            }
        }
        // Компактнее: без лишнего места.
        .frame(width: 140)
        .padding(.vertical, 4)
        .scheduleGlassPanel(cornerRadius: 14)
    }
}


// MARK: - Единый вид полей и кнопок фильтра (Денис 07.10 04:15–04:17)
//
// Форма — как ячейка задания на полёт («Начало работы»): та же пропорция скругления
// (у ячейки ~48 pt — радиус 10, у поля 34 pt — радиус 7) и тот же цвет плашки.

enum ScheduleFilterStyle {
    // Денис 07.10 06:47–06:50: ниже (28), заливка и форма скругления — как у больших карточек,
    // радиус пропорционально меньше.
    static let cornerRadius: CGFloat = 8
    static let height: CGFloat = 28
    static let fill = Color(uiColor: .secondarySystemGroupedBackground)
}

extension View {
    func scheduleFilterTile(active: Bool = false) -> some View {
        padding(.horizontal, 10)
            .frame(height: ScheduleFilterStyle.height)
            .background(
                RoundedRectangle(cornerRadius: ScheduleFilterStyle.cornerRadius, style: .continuous)
                    // Без бирюзовой заливки при выборе (Денис 07.10 04:49): бирюзовые только цифры.
                    .fill(ScheduleFilterStyle.fill)
            )
    }
}


// MARK: - Тап «мимо» на всё окно (Денис 07.10 06:47)
//
// Прокручиваемые таблица и календарь забирают тап у жестов SwiftUI, поэтому
// на время экрана расписания на окно ставится UIKit-распознаватель, который
// не мешает остальным касаниям: тап вне поля ввода гасит курсор, а экран
// получает точку тапа (закрыть крутилки).
final class ScheduleTapCatcher: NSObject, UIGestureRecognizerDelegate {
    private var recognizer: UITapGestureRecognizer?
    private weak var window: UIWindow?
    var onTap: ((CGPoint) -> Void)?
    static let tapNotification = Notification.Name("AeroUchet.scheduleTap")

    func install() {
        guard recognizer == nil,
              let window = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
                .first else { return }
        let tap = UITapGestureRecognizer(target: self, action: #selector(handle(_:)))
        tap.cancelsTouchesInView = false
        tap.delaysTouchesBegan = false
        tap.delaysTouchesEnded = false
        tap.delegate = self
        window.addGestureRecognizer(tap)
        recognizer = tap
        self.window = window
    }

    func remove() {
        if let recognizer { window?.removeGestureRecognizer(recognizer) }
        recognizer = nil
    }

    @objc private func handle(_ gesture: UITapGestureRecognizer) {
        guard let window else { return }
        let point = gesture.location(in: window)
        var view = window.hitTest(point, with: nil)
        var onTextField = false
        while let current = view {
            if current is UITextField || current is UITextView { onTextField = true; break }
            view = current.superview
        }
        if !onTextField { window.endEditing(true) }
        onTap?(point)
        NotificationCenter.default.post(name: Self.tapNotification, object: point)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool { true }
}


// MARK: - Выпадающие окна «стекло» (Денис 07.10 11:37): матовый фон, едва заметная
// окантовка, мягкая тень — как системное окно, но без резкой серой рамки.
extension View {
    func scheduleGlassPanel(cornerRadius: CGFloat = 20) -> some View {
        // Темнее и прозрачнее (Денис 07.10 13:02): слабое размытие + тёмная тонировка,
        // сквозь окно видно то, что под ним; на любой подложке один вид.
        // Вид задаётся ползунками в «Ещё → Вид окон» (Денис 07.10 22:11).
        background { ScheduleGlassBackground(cornerRadius: cornerRadius) }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
    }
}


/// Своё размытие (Денис 07.10 22:43): системное «дробное» размытие сбрасывалось
/// при перерисовке. Здесь каждый кадр снимается то, что лежит ПОД окном (всё, что
/// выше этого слоя — текст и рамка окна, — на время снимка скрывается), и снимок
/// размывается фильтром CIGaussianBlur. Сила `radius` — в точках.
struct ScheduleLightBlur: UIViewRepresentable {
    let radius: CGFloat

    final class LinkProxy: NSObject {
        weak var view: BlurView?
        @objc func tick() { view?.refresh() }
    }

    final class BlurView: UIView {
        var radius: CGFloat = 6
        private var link: CADisplayLink?
        private static let context = CIContext(options: [.cacheIntermediates: false])
        // Снимок в половинном разрешении: после размытия разницы не видно, а считать вдвое меньше.
        private let captureScale: CGFloat = 0.5

        override func didMoveToWindow() {
            super.didMoveToWindow()
            stopLink()
            guard window != nil else { return }
            let proxy = LinkProxy()
            proxy.view = self
            let link = CADisplayLink(target: proxy, selector: #selector(LinkProxy.tick))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)
            link.add(to: .main, forMode: .common)
            self.link = link
            refresh()
        }

        override func willMove(toWindow newWindow: UIWindow?) {
            super.willMove(toWindow: newWindow)
            if newWindow == nil { stopLink() }
        }

        private func stopLink() {
            link?.invalidate()
            link = nil
        }

        func refresh() {
            guard let window, bounds.width > 1, bounds.height > 1 else { return }
            let rect = convert(bounds, to: window)

            // Скрыть всё, что рисуется поверх этого слоя, и сам слой — только на время снимка.
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            var hidden: [CALayer] = []
            var child: CALayer = layer
            while let parent = child.superlayer {
                if let subs = parent.sublayers, let index = subs.firstIndex(where: { $0 === child }) {
                    for above in subs[(index + 1)...] where !above.isHidden {
                        above.isHidden = true
                        hidden.append(above)
                    }
                }
                if parent === window.layer { break }
                child = parent
            }
            layer.isHidden = true

            let format = UIGraphicsImageRendererFormat()
            format.scale = captureScale
            format.opaque = false
            let shot = UIGraphicsImageRenderer(size: bounds.size, format: format).image { ctx in
                ctx.cgContext.translateBy(x: -rect.minX, y: -rect.minY)
                window.layer.render(in: ctx.cgContext)
            }

            layer.isHidden = false
            for item in hidden { item.isHidden = false }
            CATransaction.commit()

            guard let cg = shot.cgImage else { return }
            let input = CIImage(cgImage: cg)
            let sigma = radius * captureScale
            var result = cg
            if sigma > 0.05 {
                let blurred = input.clampedToExtent()
                    .applyingGaussianBlur(sigma: Double(sigma))
                    .cropped(to: input.extent)
                if let out = Self.context.createCGImage(blurred, from: input.extent) {
                    result = out
                }
            }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.contents = result
            CATransaction.commit()
        }
    }

    func makeUIView(context: Context) -> BlurView {
        let view = BlurView()
        view.isUserInteractionEnabled = false
        view.layer.contentsGravity = .resize
        view.radius = radius
        return view
    }

    func updateUIView(_ view: BlurView, context: Context) {
        view.radius = radius
    }
}


// MARK: - Вид окон (ползунки в настройках)

enum ScheduleGlassSettings {
    static let blurKey = "aerouchet.glass.blur"
    static let opacityKey = "aerouchet.glass.opacity"
    static let tintKey = "aerouchet.glass.tint"
    // Размытие: 0…1 ползунка = 0…20 точек своего размытия (v169).
    static let maxBlurRadius: CGFloat = 20
    static let defaultBlur: Double = 0.3
    static let defaultOpacity: Double = 0.6
    static let defaultTint: Double = 0
}

/// Фон окна «стекло»: размытие, прозрачность и тёмный оттенок из настроек.
struct ScheduleGlassBackground: View {
    let cornerRadius: CGFloat
    @AppStorage(ScheduleGlassSettings.blurKey) private var blur = ScheduleGlassSettings.defaultBlur
    @AppStorage(ScheduleGlassSettings.opacityKey) private var opacity = ScheduleGlassSettings.defaultOpacity
    @AppStorage(ScheduleGlassSettings.tintKey) private var tint = ScheduleGlassSettings.defaultTint

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            ScheduleLightBlur(radius: CGFloat(blur) * ScheduleGlassSettings.maxBlurRadius)
                .clipShape(shape)
                .opacity(opacity)
            shape.fill(Color.black.opacity(tint))
        }
    }
}

/// «Ещё → Вид окон»: образец окна поверх календаря и три ползунка.
struct GlassAppearanceSettingsView: View {
    @AppStorage(ScheduleGlassSettings.blurKey) private var blur = ScheduleGlassSettings.defaultBlur
    @AppStorage(ScheduleGlassSettings.opacityKey) private var opacity = ScheduleGlassSettings.defaultOpacity
    @AppStorage(ScheduleGlassSettings.tintKey) private var tint = ScheduleGlassSettings.defaultTint

    var body: some View {
        Form {
            Section("Образец") {
                ZStack {
                    sampleCalendar
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Перейти к месяцу")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Image(systemName: "checkmark")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.teal)
                        }
                        ForEach(["Сентябрь   2025", "Октябрь   2026", "Ноябрь   2027"], id: \.self) { line in
                            Text(line)
                                .font(.title3)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(18)
                    .frame(width: 240)
                    .scheduleGlassPanel()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            Section {
                slider("Размытие", value: $blur, range: 0...1, text: percent(blur))
                slider("Прозрачность стекла", value: $opacity, range: 0...1, text: percent(opacity))
                slider("Тёмный оттенок", value: $tint, range: 0...0.6, text: percent(tint))
            } footer: {
                Text("Применяется к окнам «Перейти к месяцу» и «Тип ВС». Подберёшь — пришли эти три числа, их зашьём как стандарт.")
            }

            Section {
                Button("Сбросить") {
                    blur = ScheduleGlassSettings.defaultBlur
                    opacity = ScheduleGlassSettings.defaultOpacity
                    tint = ScheduleGlassSettings.defaultTint
                }
            }
        }
        .navigationTitle("Вид окон")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded())) %"
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(text)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: 0.01)
                .tint(.teal)
        }
    }

    /// Кусочек календаря под образцом — чтобы видно было размытие и прозрачность.
    private var sampleCalendar: some View {
        VStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(1...7, id: \.self) { column in
                        let day = row * 7 + column
                        Text(String(day))
                            .font(.callout.monospacedDigit())
                            .frame(width: 34, height: 34)
                            .background(
                                Circle().fill(day % 3 == 0 ? Color.teal : Color.teal.opacity(0.35))
                            )
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}
