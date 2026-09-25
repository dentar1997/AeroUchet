import SwiftUI


// MARK: - Учёт

struct AccountingView: View {
    
    @ObservedObject
    var store:
    AppStore
    
    
    @ObservedObject
    var absenceStore:
    AbsenceStore
    
    @ObservedObject
    var calendarSync:
    ProductionCalendarSyncModel
    
    @State
    private var selectedMonth =
    startOfMonth(
        Date()
    )
    
    
    @State
    private var initialized =
    false
    
    
    @State
    private var showAddAbsence =
    false
    
    
    var body: some View {
        
        let _ =
        calendarSync.revision
        
        
        let index =
        store.dailyIndex
        
        
        let totals =
        monthTotals(
            month:
                selectedMonth,
            index:
                index
        )
        
        
        let calendarNorm =
        productionMonthlyNorm(
            month:
                selectedMonth
        )
        
        
        let absenceMinutes =
        totalAbsenceMinutes(
            month:
                selectedMonth,
            absences:
                absenceStore
                .absences
        )
        
        
        let adjustedNorm =
        max(
            0,
            calendarNorm
            -
            absenceMinutes
        )
        
        
        let balance =
        totals.workMinutes
        -
        adjustedNorm
        
        
        NavigationStack {
            
            ScrollView {
                
                VStack(
                    alignment:
                            .leading,
                    spacing: 22
                ) {
                    
                    monthSelector
                    
                    
                    ProductionCalendarStatusCard(
                        month:
                            selectedMonth,
                        refreshToken:
                            calendarSync.revision
                    )
                    
                    
                    NormStatusCard(
                        calendarNorm:
                            calendarNorm,
                        absenceMinutes:
                            absenceMinutes,
                        adjustedNorm:
                            adjustedNorm,
                        workedMinutes:
                            totals.workMinutes
                    )
                    
                    
                    Text(
                        "Рабочее время"
                    )
                    .font(.title2)
                    .bold()
                    
                    
                    AccountingGrid {
                        
                        AccountingCard(
                            title:
                                "Всего рабочего",
                            value:
                                timeText(
                                    totals
                                        .workMinutes
                                ),
                            icon:
                                "briefcase.fill"
                        )
                        
                        
                        AccountingCard(
                            title:
                                "Работа пилотом",
                            value:
                                timeText(
                                    totals
                                        .flightWorkMinutes
                                ),
                            icon:
                                "airplane.departure"
                        )
                        
                        
                        AccountingCard(
                            title:
                                "Наземная работа",
                            value:
                                timeText(
                                    totals
                                        .groundWorkMinutes
                                ),
                            icon:
                                "building.2"
                        )
                        
                        
                        AccountingCard(
                            title:
                                balance >= 0
                            ? "Переработка"
                            : "Недоработка",
                            value:
                                timeText(
                                    abs(
                                        balance
                                    )
                                ),
                            icon:
                                balance >= 0
                            ? "arrow.up.circle.fill"
                            : "arrow.down.circle.fill"
                        )
                    }
                    
                    
                    AbsenceBreakdown(
                        month:
                            selectedMonth,
                        store:
                            absenceStore
                    )
                    
                    
                    GroundWorkBreakdown(
                        month:
                            selectedMonth,
                        events:
                            store.workEvents
                    )
                    
                    
                    Text(
                        "Налёт"
                    )
                    .font(.title2)
                    .bold()
                    
                    
                    AccountingGrid {
                        
                        AccountingCard(
                            title:
                                "Полётное",
                            value:
                                timeText(
                                    totals
                                        .flightMinutes
                                ),
                            icon:
                                "airplane"
                        )
                        
                        
                        AccountingCard(
                            title:
                                "Лётное",
                            value:
                                timeText(
                                    totals
                                        .airMinutes
                                ),
                            icon:
                                "airplane.circle"
                        )
                        
                        
                        AccountingCard(
                            title:
                                "Полётная ночь",
                            value:
                                timeText(
                                    totals
                                        .flightNightMinutes
                                ),
                            icon:
                                "moon.fill"
                        )
                        
                        
                        AccountingCard(
                            title:
                                "Лётная ночь",
                            value:
                                timeText(
                                    totals
                                        .airNightMinutes
                                ),
                            icon:
                                "moon.circle.fill"
                        )
                        
                        
                        AccountingCard(
                            title:
                                "Рабочая ночь",
                            value:
                                timeText(
                                    totals
                                        .workNightMinutes
                                ),
                            icon:
                                "moon.stars.fill"
                        )
                        
                        
                        AccountingCard(
                            title:
                                "Рабочая ночь — рейсы",
                            value:
                                timeText(
                                    totals
                                        .flightWorkNightMinutes
                                ),
                            icon:
                                "airplane.departure"
                        )
                        
                        
                        AccountingCard(
                            title:
                                "Рабочая ночь — земля",
                            value:
                                timeText(
                                    totals
                                        .groundWorkNightMinutes
                                ),
                            icon:
                                "building.2"
                        )
                    }
                }
                .padding()
            }
            
            
            .navigationTitle(
                "Учёт"
            )
            
            
            .toolbar {
                
                ToolbarItem(
                    placement:
                            .topBarTrailing
                ) {
                    
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
                
                
                let anchor =
                store.latestActivityDate
                ??
                absenceStore
                    .absences
                    .map {
                        $0.normalizedEnd
                    }
                    .max()
                ??
                Date()
                
                
                selectedMonth =
                startOfMonth(
                    anchor
                )
                
                
                initialized =
                true
            }
        }
    }
    
    
    // MARK: Месяц
    
    var monthSelector:
    some View {
        
        HStack {
            
            Button {
                
                selectedMonth =
                changeMonth(
                    selectedMonth,
                    by:
                        -1
                )
                
            } label: {
                
                Image(
                    systemName:
                        "chevron.left"
                )
                .font(.title3)
            }
            
            
            Spacer()
            
            
            VStack(
                spacing: 3
            ) {
                
                Text(
                    monthTitle(
                        selectedMonth
                    )
                )
                .font(.title2)
                .bold()
                
                
                Text(
                    "Месячный учёт"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }
            
            
            Spacer()
            
            
            Button {
                
                selectedMonth =
                changeMonth(
                    selectedMonth,
                    by:
                        1
                )
                
            } label: {
                
                Image(
                    systemName:
                        "chevron.right"
                )
                .font(.title3)
            }
        }
    }
}


// MARK: - Статус производственного календаря

struct ProductionCalendarStatusCard:
    View {
    
    let month:
    Date
    
    let refreshToken:
    Int
    
    
    var year: Int {
        
        moscowCalendar
            .component(
                .year,
                from:
                    month
            )
    }
    
    
    var official: Bool {
        
        productionMonthIsOfficial(
            month
        )
    }
    
    
    var body: some View {
        
        let _ =
        refreshToken
        
        HStack(
            spacing: 12
        ) {
            
            Image(
                systemName:
                    official
                ? "checkmark.seal.fill"
                : "exclamationmark.triangle.fill"
            )
            .font(.title2)
            .foregroundStyle(
                official
                ? .green
                : .orange
            )
            
            
            VStack(
                alignment:
                        .leading,
                spacing: 4
            ) {
                
                Text(
                    official
                    ? "Производственный календарь " + String(year)
                    : "Расчётный календарь " + String(year)
                )
                .bold()
                
                
                Text(
                    official
                    ? "Учтены праздники, переносы выходных и сокращённые рабочие дни для 36-часовой недели."
                    : "Для этого года пока используется обычная пятидневка по 7:12. Официальный календарь ещё не добавлен."
                )
                .font(.footnote)
                .foregroundStyle(
                    .secondary
                )
            }
            
            
            Spacer()
        }
        .padding()
        .background {
            
            RoundedRectangle(
                cornerRadius: 16
            )
            .fill(
                official
                ? Color.green
                    .opacity(
                        0.08
                    )
                : Color.orange
                    .opacity(
                        0.08
                    )
            )
        }
    }
}


// MARK: - Карточка нормы

struct NormStatusCard:
    View {
    
    let calendarNorm:
    Int
    
    let absenceMinutes:
    Int
    
    let adjustedNorm:
    Int
    
    let workedMinutes:
    Int
    
    
    var difference: Int {
        
        workedMinutes
        -
        adjustedNorm
    }
    
    
    var progress: Double {
        
        guard adjustedNorm > 0
        else {
            return 0
        }
        
        
        return min(
            Double(
                workedMinutes
            )
            /
            Double(
                adjustedNorm
            ),
            1
        )
    }
    
    
    var body: some View {
        
        VStack(
            alignment:
                    .leading,
            spacing: 15
        ) {
            
            HStack {
                
                VStack(
                    alignment:
                            .leading,
                    spacing: 3
                ) {
                    
                    Text(
                        "Норма рабочего времени"
                    )
                    .font(.headline)
                    
                    
                    Text(
                        "36-часовая рабочая неделя"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
                
                
                Spacer()
                
                
                Text(
                    timeText(
                        adjustedNorm
                    )
                )
                .font(.title2)
                .bold()
            }
            
            
            VStack(
                spacing: 9
            ) {
                
                NormRow(
                    name:
                        "Календарная норма",
                    value:
                        timeText(
                            calendarNorm
                        )
                )
                
                
                NormRow(
                    name:
                        "Отсутствия",
                    value:
                        "−\(timeText(absenceMinutes))"
                )
                
                
                Divider()
                
                
                NormRow(
                    name:
                        "Норма к отработке",
                    value:
                        timeText(
                            adjustedNorm
                        ),
                    bold:
                        true
                )
            }
            
            
            ProgressView(
                value:
                    progress
            )
            .scaleEffect(
                x: 1,
                y: 1.7,
                anchor:
                        .center
            )
            
            
            HStack {
                
                VStack(
                    alignment:
                            .leading,
                    spacing: 3
                ) {
                    
                    Text(
                        "Фактически учтено"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                    
                    
                    Text(
                        timeText(
                            workedMinutes
                        )
                    )
                    .font(.title3)
                    .bold()
                }
                
                
                Spacer()
                
                
                VStack(
                    alignment:
                            .trailing,
                    spacing: 3
                ) {
                    
                    Text(
                        difference >= 0
                        ? "Переработка"
                        : "Недоработка"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                    
                    
                    Text(
                        timeText(
                            abs(
                                difference
                            )
                        )
                    )
                    .font(.title3)
                    .bold()
                }
            }
        }
        .padding()
        .background {
            
            RoundedRectangle(
                cornerRadius: 20
            )
            .fill(
                .ultraThinMaterial
            )
        }
    }
}


// MARK: - Строка нормы

struct NormRow:
    View {
    
    let name:
    String
    
    let value:
    String
    
    var bold =
    false
    
    
    var body: some View {
        
        HStack {
            
            Text(
                name
            )
            
            
            Spacer()
            
            
            Text(
                value
            )
            .fontWeight(
                bold
                ? .bold
                : .regular
            )
        }
    }
}


// MARK: - Отсутствия

struct AbsenceBreakdown:
    View {
    
    let month:
    Date
    
    
    @ObservedObject
    var store:
    AbsenceStore
    
    
    var body: some View {
        
        VStack(
            alignment:
                    .leading,
            spacing: 14
        ) {
            
            HStack {
                
                Text(
                    "Отсутствия"
                )
                .font(.title2)
                .bold()
                
                
                Spacer()
                
                
                NavigationLink {
                    
                    AbsencesListView(
                        store:
                            store
                    )
                    
                } label: {
                    
                    Text(
                        "Все"
                    )
                }
            }
            
            
            VStack(
                spacing: 0
            ) {
                
                ForEach(
                    AbsenceType
                        .allCases
                ) { type in
                    
                    let minutes =
                    absenceMinutesForType(
                        type:
                            type,
                        month:
                            month,
                        absences:
                            store
                            .absences
                    )
                    
                    
                    HStack(
                        spacing: 12
                    ) {
                        
                        Image(
                            systemName:
                                type.icon
                        )
                        .foregroundStyle(
                            type.color
                        )
                        .frame(
                            width: 30
                        )
                        
                        
                        VStack(
                            alignment:
                                    .leading,
                            spacing: 2
                        ) {
                            
                            Text(
                                type.rawValue
                            )
                            
                            
                            Text(
                                type.paymentBasis
                            )
                            .font(.caption2)
                            .foregroundStyle(
                                .secondary
                            )
                        }
                        
                        
                        Spacer()
                        
                        
                        Text(
                            timeText(
                                minutes
                            )
                        )
                        .bold()
                    }
                    .padding(
                        .vertical,
                        12
                    )
                    
                    
                    if type.id
                        != AbsenceType
                        .allCases
                        .last?
                        .id {
                        
                        Divider()
                            .padding(
                                .leading,
                                42
                            )
                    }
                }
            }
            .padding(
                .horizontal
            )
            .background {
                
                RoundedRectangle(
                    cornerRadius: 18
                )
                .fill(
                    .ultraThinMaterial
                )
            }
        }
    }
}


// MARK: - Наземная работа

struct GroundWorkBreakdown:
    View {
    
    let month:
    Date
    
    let events:
    [WorkEvent]
    
    
    var body: some View {
        
        VStack(
            alignment:
                    .leading,
            spacing: 14
        ) {
            
            Text(
                "Наземная работа"
            )
            .font(.title2)
            .bold()
            
            
            VStack(
                spacing: 0
            ) {
                
                ForEach(
                    WorkEventType
                        .allCases
                ) { type in
                    
                    let minutes =
                    workEventMinutesInMonth(
                        type:
                            type,
                        month:
                            month,
                        events:
                            events
                    )
                    
                    
                    GroundWorkRow(
                        type:
                            type,
                        minutes:
                            minutes
                    )
                    
                    
                    if type.id
                        != WorkEventType
                        .allCases
                        .last?
                        .id {
                        
                        Divider()
                            .padding(
                                .leading,
                                44
                            )
                    }
                }
            }
            .padding(
                .horizontal
            )
            .background {
                
                RoundedRectangle(
                    cornerRadius: 18
                )
                .fill(
                    .ultraThinMaterial
                )
            }
        }
    }
}


// MARK: - Строка наземной работы

struct GroundWorkRow:
    View {
    
    let type:
    WorkEventType
    
    let minutes:
    Int
    
    
    var body: some View {
        
        HStack(
            spacing: 12
        ) {
            
            Image(
                systemName:
                    type.icon
            )
            .foregroundStyle(
                type.color
            )
            .frame(
                width: 30
            )
            
            
            Text(
                type.rawValue
            )
            
            
            Spacer()
            
            
            Text(
                timeText(
                    minutes
                )
            )
            .bold()
        }
        .padding(
            .vertical,
            13
        )
    }
}


// MARK: - Наземная работа одного типа за месяц

func workEventMinutesInMonth(
    type: WorkEventType,
    month: Date,
    events:
    [WorkEvent]
) -> Int {
    
    var total =
    0
    
    
    let selected =
    events.filter {
        
        $0.type
        ==
        type
    }
    
    
    for day in daysInMonth(
        month
    ) {
        
        for event in selected {
            
            total +=
            creditedWorkMinutes(
                event:
                    event,
                day:
                    day
            )
        }
    }
    
    
    return total
}


// MARK: - Сетка карточек

struct AccountingGrid<
    Content: View
>: View {
    
    @ViewBuilder
    let content:
    Content
    
    
    let columns = [
        
        GridItem(
            .adaptive(
                minimum: 150
            ),
            spacing: 12
        )
    ]
    
    
    var body: some View {
        
        LazyVGrid(
            columns:
                columns,
            spacing: 12
        ) {
            
            content
        }
    }
}


// MARK: - Карточка показателя

struct AccountingCard:
    View {
    
    let title:
    String
    
    let value:
    String
    
    let icon:
    String
    
    
    var body: some View {
        
        VStack(
            alignment:
                    .leading,
            spacing: 12
        ) {
            
            Image(
                systemName:
                    icon
            )
            .foregroundStyle(
                .blue
            )
            
            
            Text(
                title
            )
            .foregroundStyle(
                .secondary
            )
            
            
            Text(
                value
            )
            .font(
                .system(
                    size: 27,
                    weight: .bold,
                    design: .rounded
                )
            )
        }
        .frame(
            maxWidth:
                    .infinity,
            alignment:
                    .leading
        )
        .padding()
        .background {
            
            RoundedRectangle(
                cornerRadius: 18
            )
            .fill(
                .ultraThinMaterial
            )
        }
    }
}
