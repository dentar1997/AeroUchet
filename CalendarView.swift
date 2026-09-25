import SwiftUI
import Foundation


// MARK: - Подготовленные данные календаря

struct CalendarSnapshot {
    
    let totals:
    [Int: DailyTimeTotals]
    
    let flights:
    [Int: [FlightLeg]]
    
    let workEvents:
    [Int: [WorkEvent]]
    
    let absences:
    [Int: [AbsenceEvent]]
    
    
    init(
        store: AppStore,
        absenceStore: AbsenceStore
    ) {
        
        totals =
        store.dailyIndex
        
        
        flights =
        store.flightsByDay
        
        
        workEvents =
        store.workEventsByDay
        
        
        absences =
        buildAbsencesByDay(
            absences:
                absenceStore.absences
        )
    }
}


// MARK: - Событие для маленькой ячейки календаря

struct CalendarDisplayEvent:
    Identifiable {
    
    let id: String
    
    let title: String
    
    let icon: String
    
    let color: Color
    
    
    let continuesFromPreviousDay:
    Bool
    
    
    let continuesToNextDay:
    Bool
    
    
    init(
        id: String,
        title: String,
        icon: String,
        color: Color,
        continuesFromPreviousDay: Bool = false,
        continuesToNextDay: Bool = false
    ) {
        
        self.id =
        id
        
        self.title =
        title
        
        self.icon =
        icon
        
        self.color =
        color
        
        self.continuesFromPreviousDay =
        continuesFromPreviousDay
        
        self.continuesToNextDay =
        continuesToNextDay
    }
}


func calendarDisplayEvents(
    day: Date,
    flights: [FlightLeg],
    workEvents: [WorkEvent],
    absences: [AbsenceEvent]
) -> [CalendarDisplayEvent] {
    
    let startOfDay =
    moscowCalendar
        .startOfDay(
            for: day
        )
    
    
    var timedEvents:
    [(date: Date, event: CalendarDisplayEvent)] = []
    
    
    // Отсутствия
    
    for absence in absences {
        
        let eventDate =
        max(
            absence.normalizedStart,
            startOfDay
        )
        
        
        timedEvents.append(
            (
                date:
                    eventDate,
                event:
                    CalendarDisplayEvent(
                        id:
                            "absence-\(absence.id.uuidString)",
                        title:
                            absence.type.rawValue,
                        icon:
                            absence.type.icon,
                        color:
                            absence.type.color
                    )
            )
        )
    }
    
    
    // Рейсы
    
    for flight in flights {
        
        let startsToday =
        dayKey(day)
        ==
        dayKey(
            flight.timeline.engineOn
        )
        
        
        let endsToday =
        dayKey(day)
        ==
        dayKey(
            flight.timeline.engineOff
        )
        
        
        let weekday =
        moscowCalendar.component(
            .weekday,
            from: day
        )
        
        
        let canConnectFromLeft =
        weekday != 2
        
        
        let canConnectToRight =
        weekday != 1
        
        
        // Если рейс начался вчера,
        // в сегодняшней ячейке считаем его
        // начинающимся в 00:00.
        
        let eventDate =
        max(
            flight.timeline.engineOn,
            startOfDay
        )
        
        
        timedEvents.append(
            (
                date:
                    eventDate,
                event:
                    CalendarDisplayEvent(
                        id:
                            "flight-\(flight.id.uuidString)",
                        title:
                            "\(flight.flightNumber) \(flight.departure)→\(flight.arrival)",
                        icon:
                            "airplane",
                        color:
                                .blue,
                        continuesFromPreviousDay:
                            !startsToday
                        &&
                        canConnectFromLeft,
                        continuesToNextDay:
                            !endsToday
                        &&
                        canConnectToRight
                    )
            )
        )
    }
    
    
    // Наземная работа
    
    for event in workEvents {
        
        let eventDate =
        max(
            event.startDate,
            startOfDay
        )
        
        
        timedEvents.append(
            (
                date:
                    eventDate,
                event:
                    CalendarDisplayEvent(
                        id:
                            "work-\(event.id.uuidString)",
                        title:
                            event.type.rawValue,
                        icon:
                            event.type.icon,
                        color:
                            event.type.color
                    )
            )
        )
    }
    
    
    // Единая хронология дня:
    // раннее событие выше,
    // следующее ниже.
    
    timedEvents.sort {
        
        if $0.date == $1.date {
            
            return
            $0.event.title
            <
                $1.event.title
        }
        
        
        return
        $0.date
        <
            $1.date
    }
    
    
    return
    timedEvents.map {
        $0.event
    }
}


// MARK: - 42 клетки месяца

func calendarCells(
    for month: Date
) -> [Date?] {
    
    let days =
    daysInMonth(
        month
    )
    
    
    let offset =
    calendarOffset(
        for: month
    )
    
    
    var result =
    Array<Date?>(
        repeating: nil,
        count: 42
    )
    
    
    for index in days.indices {
        
        let position =
        offset + index
        
        
        if position < result.count {
            
            result[position] =
            days[index]
        }
    }
    
    
    return result
}


// MARK: - Главный экран календаря

struct CalendarView: View {
    
    @ObservedObject
    var store: AppStore
    
    
    @ObservedObject
    var absenceStore: AbsenceStore
    
    
    @ObservedObject
    var calendarSync:
    ProductionCalendarSyncModel
    
    
    @Environment(
        \.horizontalSizeClass
    )
    private var horizontalSizeClass
    
    
    @State
    private var selectedMonth =
    startOfMonth(
        Date()
    )
    
    
    @State
    private var selectedDay =
    moscowCalendar
        .startOfDay(
            for: Date()
        )
    
    
    @State
    private var initialized =
    false
    
    
    @State
    private var showAddWork =
    false
    
    
    @State
    private var showAddAbsence =
    false
    
    
    var body: some View {
        
        let refreshToken =
        calendarSync.revision
        
        
        let snapshot =
        CalendarSnapshot(
            store: store,
            absenceStore:
                absenceStore
        )
        
        
        NavigationStack {
            
            Group {
                
                if horizontalSizeClass
                    == .regular {
                    
                    HStack(
                        spacing: 0
                    ) {
                        
                        CalendarMonthPane(
                            month:
                                $selectedMonth,
                            selectedDay:
                                $selectedDay,
                            snapshot:
                                snapshot,
                            refreshToken:
                                refreshToken
                        )
                        .frame(
                            maxWidth:
                                    .infinity
                        )
                        
                        
                        Divider()
                        
                        
                        CalendarDayDetail(
                            day:
                                selectedDay,
                            snapshot:
                                snapshot,
                            refreshToken:
                                refreshToken
                        )
                        .frame(
                            width: 380
                        )
                    }
                    
                } else {
                    
                    ScrollView {
                        
                        VStack(
                            spacing: 18
                        ) {
                            
                            CalendarMonthPane(
                                month:
                                    $selectedMonth,
                                selectedDay:
                                    $selectedDay,
                                snapshot:
                                    snapshot,
                                refreshToken:
                                    refreshToken
                            )
                            
                            
                            CalendarDayDetail(
                                day:
                                    selectedDay,
                                snapshot:
                                    snapshot,
                                refreshToken:
                                    refreshToken
                            )
                        }
                    }
                }
            }
            
            
            .navigationTitle(
                "Календарь"
            )
            
            
            .toolbar {
                
                ToolbarItemGroup(
                    placement:
                            .topBarTrailing
                ) {
                    
                    Button(
                        "Сегодня"
                    ) {
                        
                        let today =
                        moscowCalendar
                            .startOfDay(
                                for: Date()
                            )
                        
                        
                        selectedMonth =
                        startOfMonth(
                            today
                        )
                        
                        
                        selectedDay =
                        today
                    }
                    
                    
                    Button {
                        
                        showAddWork =
                        true
                        
                    } label: {
                        
                        Image(
                            systemName:
                                "plus"
                        )
                    }
                    
                    
                    Button {
                        
                        showAddAbsence =
                        true
                        
                    } label: {
                        
                        Image(
                            systemName:
                                "calendar.badge.minus"
                        )
                    }
                }
            }
            
            
            .sheet(
                isPresented:
                    $showAddWork
            ) {
                
                AddWorkEventView {
                    
                    event in
                    
                    store.addWorkEvent(
                        event
                    )
                }
            }
            
            
            .sheet(
                isPresented:
                    $showAddAbsence
            ) {
                
                AddAbsenceView {
                    
                    absence in
                    
                    absenceStore.add(
                        absence
                    )
                }
            }
            
            
            .onAppear {
                
                guard !initialized
                else {
                    return
                }
                
                
                var dates:
                [Date] = []
                
                
                if let flightDate =
                    store.latestActivityDate {
                    
                    dates.append(
                        flightDate
                    )
                }
                
                
                if let absenceDate =
                    absenceStore.absences
                    .map({
                        $0.normalizedEnd
                    })
                        .max() {
                    
                    dates.append(
                        absenceDate
                    )
                }
                
                
                let anchor =
                dates.max()
                ?? Date()
                
                
                selectedMonth =
                startOfMonth(
                    anchor
                )
                
                
                selectedDay =
                moscowCalendar
                    .startOfDay(
                        for: anchor
                    )
                
                
                initialized =
                true
            }
        }
        .environmentObject(
            store
        )
        .environmentObject(
            absenceStore
        )
    }
}


// MARK: - Левая часть календаря

struct CalendarMonthPane: View {
    
    @Binding
    var month: Date
    
    
    @Binding
    var selectedDay: Date
    
    
    let snapshot:
    CalendarSnapshot
    
    
    let refreshToken:
    Int
    
    
    var body: some View {
        
        let _ =
        refreshToken
        
        
        VStack(
            spacing: 8
        ) {
            
            CalendarMonthHeader(
                month:
                    $month,
                selectedDay:
                    $selectedDay
            )
            
            
            CalendarWeekdayHeader()
            
            
            CalendarMonthGrid(
                month:
                    month,
                selectedDay:
                    $selectedDay,
                snapshot:
                    snapshot,
                refreshToken:
                    refreshToken
            )
        }
        .padding(
            .top,
            8
        )
    }
}


// MARK: - Заголовок месяца

struct CalendarMonthHeader: View {
    
    @Binding
    var month: Date
    
    
    @Binding
    var selectedDay: Date
    
    
    var body: some View {
        
        HStack {
            
            Button {
                
                month =
                changeMonth(
                    month,
                    by: -1
                )
                
                
                selectedDay =
                month
                
            } label: {
                
                Image(
                    systemName:
                        "chevron.left"
                )
                .font(.title3)
            }
            
            
            Spacer()
            
            
            Text(
                monthTitle(
                    month
                )
            )
            .font(.title2)
            .bold()
            
            
            Spacer()
            
            
            Button {
                
                month =
                changeMonth(
                    month,
                    by: 1
                )
                
                
                selectedDay =
                month
                
            } label: {
                
                Image(
                    systemName:
                        "chevron.right"
                )
                .font(.title3)
            }
        }
        .padding(
            .horizontal
        )
    }
}


// MARK: - Дни недели

struct CalendarWeekdayHeader: View {
    
    let weekdays = [
        "Пн",
        "Вт",
        "Ср",
        "Чт",
        "Пт",
        "Сб",
        "Вс"
    ]
    
    
    let columns =
    Array(
        repeating:
            GridItem(
                .flexible(),
                spacing: 0
            ),
        count: 7
    )
    
    
    var body: some View {
        
        LazyVGrid(
            columns: columns,
            spacing: 0
        ) {
            
            ForEach(
                weekdays,
                id: \.self
            ) { name in
                
                Text(
                    name
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
                .frame(
                    maxWidth:
                            .infinity
                )
                .padding(
                    .vertical,
                    5
                )
            }
        }
    }
}


// MARK: - Сетка месяца

struct CalendarMonthGrid: View {
    
    let month: Date
    
    
    @Binding
    var selectedDay: Date
    
    
    let snapshot:
    CalendarSnapshot
    
    
    let refreshToken:
    Int
    
    
    let columns =
    Array(
        repeating:
            GridItem(
                .flexible(),
                spacing: 1
            ),
        count: 7
    )
    
    
    var body: some View {
        
        let _ =
        refreshToken
        
        
        let cells =
        calendarCells(
            for: month
        )
        
        
        LazyVGrid(
            columns: columns,
            spacing: 1
        ) {
            
            ForEach(
                Array(
                    cells.enumerated()
                ),
                id: \.offset
            ) { _, date in
                
                if let day = date {
                    
                    let key =
                    dayKey(
                        day
                    )
                    
                    
                    CalendarDayCell(
                        day:
                            day,
                        selected:
                            moscowCalendar
                            .isDate(
                                day,
                                inSameDayAs:
                                    selectedDay
                            ),
                        totals:
                            snapshot.totals[
                                key
                            ]
                        ?? .zero,
                        flights:
                            snapshot.flights[
                                key
                            ]
                        ?? [],
                        workEvents:
                            snapshot.workEvents[
                                key
                            ]
                        ?? [],
                        absences:
                            snapshot.absences[
                                key
                            ]
                        ?? []
                    ) {
                        
                        selectedDay =
                        day
                    }
                    
                } else {
                    
                    Color.clear
                        .frame(
                            minHeight:
                                112
                        )
                }
            }
        }
        .background(
            Color.secondary
                .opacity(
                    0.12
                )
        )
    }
}


// MARK: - Один день

struct CalendarDayCell: View {
    
    let day: Date
    
    let selected: Bool
    
    let totals:
    DailyTimeTotals
    
    let flights:
    [FlightLeg]
    
    let workEvents:
    [WorkEvent]
    
    let absences:
    [AbsenceEvent]
    
    let action:
    () -> Void
    
    
    var productionInfo:
    ProductionDayInfo {
        
        productionDayInfo(
            for:
                day
        )
    }
    
    
    var events:
    [CalendarDisplayEvent] {
        
        calendarDisplayEvents(
            day: day,
            flights: flights,
            workEvents:
                workEvents,
            absences:
                absences
        )
    }
    
    
    var hiddenCount: Int {
        
        max(
            0,
            events.count - 3
        )
    }
    
    
    var body: some View {
        
        Button(
            action:
                action
        ) {
            
            VStack(
                alignment:
                        .leading,
                spacing: 4
            ) {
                
                ViewThatFits(
                    in: .horizontal
                ) {
                    
                    // Обычный вариант —
                    // такой же, как сейчас
                    
                    HStack(
                        alignment: .center,
                        spacing: 5
                    ) {
                        
                        Spacer(
                            minLength: 0
                        )
                        
                        
                        CalendarProductionBadge(
                            info:
                                productionInfo
                        )
                        
                        
                        CalendarDayNumber(
                            day:
                                day,
                            productionInfo:
                                productionInfo
                        )
                    }
                    
                    
                    // Компактный вариант
                    // для узкого окна iPad
                    
                    HStack(
                        alignment: .center,
                        spacing: 1
                    ) {
                        
                        Spacer(
                            minLength: 0
                        )
                        
                        
                        CalendarProductionBadge(
                            info:
                                productionInfo
                        )
                        .scaleEffect(
                            0.72
                        )
                        .frame(
                            width: 13,
                            height: 18
                        )
                        
                        
                        CalendarDayNumber(
                            day:
                                day,
                            productionInfo:
                                productionInfo
                        )
                        .scaleEffect(
                            0.86
                        )
                        .frame(
                            width: 24,
                            height: 28
                        )
                    }
                }
                
                
                ForEach(
                    Array(
                        events.prefix(3)
                    )
                ) { event in
                    
                    CalendarEventLine(
                        event:
                            event
                    )
                }
                
                
                if hiddenCount > 0 {
                    
                    Text(
                        "ещё \(hiddenCount)"
                    )
                    .font(.caption2)
                    .foregroundStyle(
                        .secondary
                    )
                }
                
                
                Spacer(
                    minLength: 0
                )
                
                
                if totals.workMinutes > 0 {
                    
                    HStack(
                        spacing: 4
                    ) {
                        
                        Image(
                            systemName:
                                "briefcase.fill"
                        )
                        .font(
                            .system(
                                size: 9,
                                weight:
                                        .semibold
                            )
                        )
                        .symbolRenderingMode(
                            .hierarchical
                        )
                        
                        
                        Text(
                            timeText(
                                totals.workMinutes
                            )
                        )
                        .font(
                            .caption2
                        )
                    }
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
            .padding(6)
            .frame(
                maxWidth:
                        .infinity,
                minHeight:
                    112,
                alignment:
                        .top
            )
            
            // Делает нажимаемой всю площадь ячейки,
            // даже если рабочий день полностью пустой.
            
            .contentShape(
                Rectangle()
            )
            
            .background {
                
                CalendarDayBackground(
                    day:
                        day,
                    selected:
                        selected,
                    productionInfo:
                        productionInfo
                )
            }
            
            .overlay {
                
                if selected {
                    
                    RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    )
                    .strokeBorder(
                        Color.blue,
                        lineWidth: 2
                    )
                }
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 10,
                    style: .continuous
                )
            )
        }
        .buttonStyle(
            .plain
        )
        .contentShape(
            Rectangle()
        )
    }
}


// MARK: - Значок производственного календаря

// MARK: - Значок производственного календаря

struct CalendarProductionBadge: View {
    
    let info:
    ProductionDayInfo
    
    
    @ViewBuilder
    var body: some View {
        
        if info.isOfficial {
            
            switch info.kind {
                
                // Праздник — радиальный салют
                
            case .holiday:
                
                ZStack {
                    
                    // Основной взрыв
                    
                    Image(
                        systemName:
                            "sparkles"
                    )
                    .font(
                        .system(
                            size: 11,
                            weight: .bold
                        )
                    )
                    .offset(
                        x: 2,
                        y: -3
                    )
                    
                    
                    // Маленькая искра справа сверху
                    
                    Image(
                        systemName:
                            "sparkles"
                    )
                    .font(
                        .system(
                            size: 6,
                            weight: .bold
                        )
                    )
                    .offset(
                        x: 8,
                        y: -8
                    )
                    
                    
                    // Маленькая искра справа
                    
                    Image(
                        systemName:
                            "sparkles"
                    )
                    .font(
                        .system(
                            size: 5,
                            weight: .bold
                        )
                    )
                    .offset(
                        x: 9,
                        y: 1
                    )
                }
                .symbolRenderingMode(
                    .monochrome
                )
                .foregroundStyle(
                    .red
                )
                .frame(
                    width: 20,
                    height: 18
                )
                
                
                // Перенесённый выходной
                
            case .transferredDayOff:
                
                CalendarBadgeSymbol(
                    systemName:
                        "bed.double.fill",
                    color:
                            .red
                )
                
                
                // Рабочий день вместо выходного
                
            case .transferredWorkday:
                
                CalendarBadgeSymbol(
                    systemName:
                        "briefcase.fill",
                    color:
                            .green
                )
                
                
                // Сокращённый день
                
            case .shortened:
                
                CalendarShortenedBadge()
                
                
                // Для обычных дней вообще
                // не занимаем место рядом с числом
                
            case .workday,
                    .weekend:
                
                EmptyView()
            }
            
        } else {
            
            EmptyView()
        }
    }
}


// MARK: - Качественный SF Symbol

struct CalendarBadgeSymbol: View {
    
    let systemName:
    String
    
    let color:
    Color
    
    
    var body: some View {
        
        Image(
            systemName:
                systemName
        )
        .font(
            .system(
                size: 13,
                weight: .semibold
            )
        )
        .symbolRenderingMode(
            .hierarchical
        )
        .foregroundStyle(
            color
        )
        .frame(
            width: 18,
            height: 18
        )
    }
}


// MARK: - Сокращённый день: часы с минусом

struct CalendarShortenedBadge: View {
    
    var body: some View {
        
        ZStack(
            alignment:
                    .bottomTrailing
        ) {
            
            Image(
                systemName:
                    "clock.fill"
            )
            .font(
                .system(
                    size: 13,
                    weight: .semibold
                )
            )
            .symbolRenderingMode(
                .hierarchical
            )
            .foregroundStyle(
                .orange
            )
            
            
            ZStack {
                
                Circle()
                    .fill(
                        Color.orange
                    )
                    .frame(
                        width: 9,
                        height: 9
                    )
                
                
                Image(
                    systemName:
                        "minus"
                )
                .font(
                    .system(
                        size: 6,
                        weight: .black
                    )
                )
                .foregroundStyle(
                    .white
                )
            }
            .overlay {
                
                Circle()
                    .stroke(
                        Color(.systemBackground),
                        lineWidth: 1.5
                    )
                    .frame(
                        width: 10,
                        height: 10
                    )
            }
            .offset(
                x: 2,
                y: 2
            )
        }
        .frame(
            width: 18,
            height: 18
        )
    }
}


// MARK: - Число дня

struct CalendarDayNumber: View {
    
    let day: Date
    
    
    let productionInfo:
    ProductionDayInfo
    
    
    var body: some View {
        
        let today =
        moscowCalendar
            .isDateInToday(
                day
            )
        
        
        ZStack {
            
            // Сегодня сохраняем как в Apple Calendar:
            // красный круг и белое число.
            
            if today {
                
                Circle()
                    .fill(
                        Color.red
                    )
                    .frame(
                        width: 28,
                        height: 28
                    )
            }
            
            
            Text(
                String(
                    moscowCalendar.component(
                        .day,
                        from:
                            day
                    )
                )
            )
            .font(.subheadline)
            .fontWeight(
                today
                ? .bold
                : .semibold
            )
            .foregroundStyle(
                today
                ? Color.white
                : numberColor
            )
        }
        .frame(
            width: 28,
            height: 28
        )
    }
    
    
    var numberColor:
    Color {
        
        guard productionInfo.isOfficial
        else {
            
            return .primary
        }
        
        
        switch productionInfo.kind {
            
            // Красное число
            
        case .holiday,
                .transferredDayOff:
            
            return .red
            
            
            // Сокращённый рабочий день
            
        case .shortened:
            
            return .orange
            
            
            // Остальные
            
        case .transferredWorkday:
            
            return .green
            
            
        case .workday,
                .weekend:
            
            return .primary
        }
    }
}


// MARK: - Фон дня

struct CalendarDayBackground: View {
    
    let day: Date
    
    let selected: Bool
    
    let productionInfo:
    ProductionDayInfo
    
    
    var body: some View {
        
        ZStack {
            
            // Специальные дни больше не красим
            // красным/оранжевым целиком.
            //
            // Серым оставляем только обычный
            // календарный выходной.
            
            if shouldShadeWeekend {
                
                Color.secondary
                    .opacity(
                        0.07
                    )
            }
            
            
            if selected {
                
                Color.blue
                    .opacity(
                        0.13
                    )
            }
        }
    }
    
    
    var shouldShadeWeekend:
    Bool {
        
        if productionInfo.isOfficial {
            
            switch productionInfo.kind {
                
                // Обычный выходной
                
            case .weekend:
                
                return true
                
                
                // Официальный праздник тоже
                // является нерабочим днём
                
            case .holiday:
                
                return true
                
                
                // Перенесённый выходной
                
            case .transferredDayOff:
                
                return true
                
                
                // Рабочие дни остаются
                // с обычным фоном
                
            case .workday,
                    .shortened,
                    .transferredWorkday:
                
                return false
            }
        }
        
        
        // Если официальный календарь
        // ещё не загружен —
        // обычная пятидневная неделя.
        
        return isWeekend(
            day
        )
    }
}


// MARK: - Одна строка события

struct CalendarEventLine: View {
    
    let event:
    CalendarDisplayEvent
    
    
    var body: some View {
        
        HStack(
            spacing: 5
        ) {
            
            Image(
                systemName:
                    event.icon
            )
            .font(
                .system(
                    size: 11,
                    weight: .semibold
                )
            )
            .symbolRenderingMode(
                .hierarchical
            )
            .foregroundStyle(
                event.color
            )
            .frame(
                width: 15,
                height: 15
            )
            
            
            Text(
                event.title
            )
            .font(
                .system(
                    size: 10,
                    weight: .medium
                )
            )
            .lineLimit(1)
            .minimumScaleFactor(
                0.75
            )
            
            
            Spacer(
                minLength: 0
            )
        }
        
        // Если рейс пришёл из предыдущего дня,
        // оставляем место для входящей линии.
        
        .padding(
            .trailing,
            event.continuesFromPreviousDay
            ||
            event.continuesToNextDay
            ? 12
            : 0
        )
        
        .overlay(
            alignment:
                    .trailing
        ) {
            
            if event.continuesToNextDay {
                
                Image(
                    systemName:
                        "arrow.right"
                )
                .font(
                    .system(
                        size: 9,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    event.color
                )
                .offset(
                    x: 2
                )
                
            } else if event.continuesFromPreviousDay {
                
                Image(
                    systemName:
                        "arrow.left"
                )
                .font(
                    .system(
                        size: 9,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    event.color
                )
                .offset(
                    x: 2
                )
            }
        }
    }
}


// MARK: - Правая панель дня

struct CalendarDayDetail: View {
    
    @EnvironmentObject
    private var store:
    AppStore
    
    
    @EnvironmentObject
    private var absenceStore:
    AbsenceStore
    
    
    let day: Date
    
    let snapshot:
    CalendarSnapshot
    
    let refreshToken:
    Int
    
    
    var key: Int {
        
        dayKey(
            day
        )
    }
    
    
    var productionInfo:
    ProductionDayInfo {
        
        productionDayInfo(
            for:
                day
        )
    }
    
    
    var totals:
    DailyTimeTotals {
        
        snapshot.totals[
            key
        ]
        ?? .zero
    }
    
    
    var flights:
    [FlightLeg] {
        
        snapshot.flights[
            key
        ]
        ?? []
    }
    
    
    var workEvents:
    [WorkEvent] {
        
        snapshot.workEvents[
            key
        ]
        ?? []
    }
    
    
    var absences:
    [AbsenceEvent] {
        
        snapshot.absences[
            key
        ]
        ?? []
    }
    
    
    var body: some View {
        
        let _ =
        refreshToken
        
        
        ScrollView {
            
            VStack(
                alignment:
                        .leading,
                spacing: 18
            ) {
                
                Text(
                    longDateTitle(
                        day
                    )
                )
                .font(.title2)
                .bold()
                
                
                Text(
                    weekdayName(
                        day
                    )
                )
                .foregroundStyle(
                    .secondary
                )
                
                
                CalendarProductionDayCard(
                    day:
                        day,
                    info:
                        productionInfo
                )
                
                
                CalendarDayTotalsCard(
                    totals:
                        totals
                )
                
                
                if !absences.isEmpty {
                    
                    CalendarSectionTitle(
                        title:
                            "Отсутствия"
                    )
                    
                    
                    ForEach(
                        absences
                    ) { absence in
                        
                        NavigationLink {
                            
                            AbsenceDetailView(
                                absence:
                                    absence,
                                store:
                                    absenceStore
                            )
                            
                        } label: {
                            
                            CalendarAbsenceRow(
                                absence:
                                    absence
                            )
                        }
                        .buttonStyle(
                            .plain
                        )
                    }
                }
                
                
                if !flights.isEmpty {
                    
                    CalendarSectionTitle(
                        title:
                            "Полёты"
                    )
                    
                    
                    ForEach(
                        flights
                    ) { flight in
                        
                        NavigationLink {
                            if let duty = store.duties.first(where: {
                                $0.legs.contains(where: { $0.id == flight.id })
                            }) {
                                DutyDetailView(duty: duty)
                            } else {
                                Text("Смена для этого рейса не найдена")
                            }
                        } label: {
                            
                            CalendarFlightRow(
                                flight:
                                    flight,
                                day:
                                    day
                            )
                        }
                        .buttonStyle(
                            .plain
                        )
                    }
                }
                
                
                if !workEvents.isEmpty {
                    
                    CalendarSectionTitle(
                        title:
                            "План работ"
                    )
                    
                    
                    ForEach(
                        workEvents
                    ) { event in
                        
                        NavigationLink {
                            
                            WorkEventDetailView(
                                event:
                                    event
                            )
                            
                        } label: {
                            
                            CalendarWorkEventRow(
                                event:
                                    event
                            )
                        }
                        .buttonStyle(
                            .plain
                        )
                    }
                }
                
                
                if absences.isEmpty
                    &&
                    flights.isEmpty
                    &&
                    workEvents.isEmpty {
                    
                    Text(
                        "На этот день событий нет."
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .padding(
                        .vertical
                    )
                }
            }
            .padding()
        }
    }
}


// MARK: - Производственный день справа

struct CalendarProductionDayCard: View {
    
    let day:
    Date
    
    
    let info:
    ProductionDayInfo
    
    
    var body: some View {
        
        HStack(
            spacing: 12
        ) {
            
            Image(
                systemName:
                    iconName
            )
            .font(.title3)
            .symbolRenderingMode(
                .hierarchical
            )
            .foregroundStyle(
                iconColor
            )
            .frame(
                width: 28
            )
            
            
            VStack(
                alignment:
                        .leading,
                spacing: 4
            ) {
                
                Text(
                    displayTitle
                )
                .font(.headline)
                
                
                Text(
                    info.isOfficial
                    ? "Производственный календарь РФ"
                    : "Официальный календарь на этот год не загружен"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }
            
            
            Spacer()
            
            
            VStack(
                alignment:
                        .trailing,
                spacing: 3
            ) {
                
                Text(
                    "Норма"
                )
                .font(.caption2)
                .foregroundStyle(
                    .secondary
                )
                
                
                Text(
                    timeText(
                        info.scheduledMinutes
                    )
                )
                .bold()
            }
        }
        .padding()
        .background {
            
            RoundedRectangle(
                cornerRadius: 16
            )
            .fill(
                cardBackground
            )
        }
    }
    
    var displayTitle:
    String {
        
        guard info.isOfficial,
              info.kind == .holiday
        else {
            
            return info.title
        }
        
        
        let components =
        moscowCalendar.dateComponents(
            [
                .month,
                .day
            ],
            from:
                day
        )
        
        
        guard let month =
                components.month,
              let dayNumber =
                components.day
        else {
            
            return info.title
        }
        
        
        switch (
            month,
            dayNumber
        ) {
            
        case (1, 1),
            (1, 2),
            (1, 3),
            (1, 4),
            (1, 5),
            (1, 6),
            (1, 8):
            
            return
            "Новогодние каникулы"
            
            
        case (1, 7):
            
            return
            "Рождество Христово"
            
            
        case (2, 23):
            
            return
            "День защитника Отечества"
            
            
        case (3, 8):
            
            return
            "Международный женский день"
            
            
        case (5, 1):
            
            return
            "Праздник Весны и Труда"
            
            
        case (5, 9):
            
            return
            "День Победы"
            
            
        case (6, 12):
            
            return
            "День России"
            
            
        case (11, 4):
            
            return
            "День народного единства"
            
            
        default:
            
            return info.title
        }
    }
    
    var iconName:
    String {
        
        if !info.isOfficial {
            
            return
            "exclamationmark.triangle.fill"
        }
        
        
        switch info.kind {
            
        case .workday:
            
            return
            "briefcase.fill"
            
            
        case .holiday,
                .transferredDayOff,
                .shortened:
            
            return
            "calendar.badge.minus"
            
            
        case .weekend:
            
            return
            "house.fill"
            
            
        case .transferredWorkday:
            
            return
            "calendar.badge.plus"
        }
    }
    
    
    var iconColor:
    Color {
        
        if !info.isOfficial {
            
            return .orange
        }
        
        
        switch info.kind {
            
        case .holiday,
                .transferredDayOff:
            return .red
            
        case .shortened:
            return .orange
            
        case .transferredWorkday:
            return .green
            
        case .workday:
            return .blue
            
        case .weekend:
            return .secondary
        }
    }
    
    
    var cardBackground:
    Color {
        
        if !info.isOfficial {
            
            return Color.orange
                .opacity(
                    0.08
                )
        }
        
        
        switch info.kind {
            
        case .holiday,
                .transferredDayOff:
            
            return Color.red
                .opacity(
                    0.07
                )
            
            
        case .shortened:
            
            return Color.orange
                .opacity(
                    0.08
                )
            
            
        case .transferredWorkday:
            
            return Color.green
                .opacity(
                    0.07
                )
            
            
        case .workday,
                .weekend:
            
            return Color.secondary
                .opacity(
                    0.06
                )
        }
    }
}


// MARK: - Заголовок раздела

struct CalendarSectionTitle: View {
    
    let title: String
    
    
    var body: some View {
        
        Text(
            title
        )
        .font(.headline)
    }
}


// MARK: - Итоги дня

struct CalendarDayTotalsCard: View {
    
    let totals:
    DailyTimeTotals
    
    
    var body: some View {
        
        VStack(
            spacing: 10
        ) {
            
            CalendarTotalRow(
                title:
                    "Рабочее всего",
                value:
                    timeText(
                        totals.workMinutes
                    )
            )
            
            
            CalendarTotalRow(
                title:
                    "Рабочее — рейсы",
                value:
                    timeText(
                        totals.flightWorkMinutes
                    )
            )
            
            
            CalendarTotalRow(
                title:
                    "Рабочее — земля",
                value:
                    timeText(
                        totals.groundWorkMinutes
                    )
            )
            
            
            Divider()
            
            
            CalendarTotalRow(
                title:
                    "Полётное",
                value:
                    timeText(
                        totals.flightMinutes
                    )
            )
            
            
            CalendarTotalRow(
                title:
                    "Лётное",
                value:
                    timeText(
                        totals.airMinutes
                    )
            )
            
            
            CalendarTotalRow(
                title:
                    "Полётная ночь",
                value:
                    timeText(
                        totals.flightNightMinutes
                    )
            )
            
            
            CalendarTotalRow(
                title:
                    "Лётная ночь",
                value:
                    timeText(
                        totals.airNightMinutes
                    )
            )
            
            
            CalendarTotalRow(
                title:
                    "Рабочая ночь",
                value:
                    timeText(
                        totals.workNightMinutes
                    )
            )
            
            
            CalendarTotalRow(
                title:
                    "Рабочая ночь — рейсы",
                value:
                    timeText(
                        totals.flightWorkNightMinutes
                    )
            )
            
            
            CalendarTotalRow(
                title:
                    "Рабочая ночь — земля",
                value:
                    timeText(
                        totals.groundWorkNightMinutes
                    )
            )
        }
        .padding()
        .background {
            
            RoundedRectangle(
                cornerRadius: 16
            )
            .fill(
                .ultraThinMaterial
            )
        }
    }
}


struct CalendarTotalRow: View {
    
    let title: String
    
    let value: String
    
    
    var body: some View {
        
        HStack {
            
            Text(
                title
            )
            
            
            Spacer()
            
            
            Text(
                value
            )
            .bold()
        }
    }
}


// MARK: - Рейс справа

struct CalendarFlightRow: View {
    
    let flight:
    FlightLeg
    
    let day:
    Date
    
    
    var minutesToday: Int {
        
        minutesInDay(
            from:
                flight.timeline.engineOn,
            to:
                flight.timeline.engineOff,
            day:
                day
        )
    }
    
    
    var body: some View {
        
        HStack(
            spacing: 12
        ) {
            
            Image(
                systemName:
                    "airplane"
            )
            .font(.title2)
            .symbolRenderingMode(
                .hierarchical
            )
            .foregroundStyle(
                .blue
            )
            
            
            VStack(
                alignment:
                        .leading,
                spacing: 4
            ) {
                
                Text(
                    "\(flight.departure) → \(flight.arrival)"
                )
                .bold()
                
                
                Text(
                    "\(flight.flightNumber) • \(flight.aircraft)"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
                
                
                Text(
                    "\(formatClock(flight.timeline.engineOn)) – \(formatClock(flight.timeline.engineOff))"
                )
                .font(.caption2)
                .foregroundStyle(
                    .secondary
                )
            }
            
            
            Spacer()
            
            
            Text(
                timeText(
                    minutesToday
                )
            )
            .bold()
        }
        .padding()
        .background {
            
            RoundedRectangle(
                cornerRadius: 14
            )
            .fill(
                .ultraThinMaterial
            )
        }
    }
}


// MARK: - Отсутствие справа

struct CalendarAbsenceRow: View {
    
    let absence:
    AbsenceEvent
    
    
    var body: some View {
        
        HStack(
            spacing: 12
        ) {
            
            Image(
                systemName:
                    absence.type.icon
            )
            .font(.title2)
            .symbolRenderingMode(
                .hierarchical
            )
            .foregroundStyle(
                absence.type.color
            )
            
            
            VStack(
                alignment:
                        .leading,
                spacing: 4
            ) {
                
                Text(
                    absence.type.rawValue
                )
                .bold()
                
                
                Text(
                    absencePeriodText(
                        absence
                    )
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
                
                
                Text(
                    absence.type.paymentBasis
                )
                .font(.caption2)
                .foregroundStyle(
                    .secondary
                )
                
                
                if !absence.note.isEmpty {
                    
                    Text(
                        absence.note
                    )
                    .font(.caption2)
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
            
            
            Spacer()
        }
        .padding()
        .background {
            
            RoundedRectangle(
                cornerRadius: 14
            )
            .fill(
                absence.type.color
                    .opacity(
                        0.08
                    )
            )
        }
    }
}
// MARK: - План работ справа

struct CalendarWorkEventRow: View {
    
    let event:
    WorkEvent
    
    
    var body: some View {
        
        HStack(
            spacing: 12
        ) {
            
            Image(
                systemName:
                    event.type.icon
            )
            .font(.title2)
            .symbolRenderingMode(
                .hierarchical
            )
            .foregroundStyle(
                event.type.color
            )
            
            
            VStack(
                alignment:
                        .leading,
                spacing: 4
            ) {
                
                Text(
                    event.type.rawValue
                )
                .bold()
                
                
                Text(
                    "\(event.startTime) – \(event.endTime)"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
                
                
                if !event.note.isEmpty {
                    
                    Text(
                        event.note
                    )
                    .font(.caption2)
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
            
            
            Spacer()
            
            
            Text(
                timeText(
                    event.creditedMinutes
                )
            )
            .bold()
        }
        .padding()
        .background {
            
            RoundedRectangle(
                cornerRadius: 14
            )
            .fill(
                event.type.color
                    .opacity(
                        0.08
                    )
            )
        }
    }
}
