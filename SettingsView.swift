import SwiftUI
import Foundation


// MARK: - Модель экрана синхронизации

@MainActor
final class ProductionCalendarSyncModel:
    ObservableObject {
    
    @Published
    var isWorking =
    false
    
    
    @Published
    var message:
    String?
    
    
    @Published
    var revision =
    0
    
    
    // MARK: Главная кнопка
    
    func runPrimaryAction()
    async {
        
        guard
            !isWorking
                
        else {
            
            return
        }
        
        
        isWorking =
        true
        
        
        let currentYear =
        moscowCalendar.component(
            .year,
            from:
                Date()
        )
        
        
        let problems =
        productionCalendarProblemYears(
            currentYear:
                currentYear
        )
        
        
        let report:
        ProductionCalendarSyncReport
        
        
        if !problems.isEmpty {
            
            message =
            "Загружаем производственные календари РФ…"
            
            
            report =
            await ProductionCalendarUpdater
                .shared
                .downloadRequiredCalendars()
            
        } else {
            
            message =
            "Проверяем календарь следующего года…"
            
            
            report =
            await ProductionCalendarUpdater
                .shared
                .checkNextYear()
        }
        
        
        isWorking =
        false
        
        
        revision += 1
        
        
        message =
        makeMessage(
            report:
                report
        )
    }
    
    
    // MARK: Удаление календарей
    
    func deleteAllCalendars() {
        
        ProductionCalendarCache
            .shared
            .deleteAllCalendars()
        
        
        message =
        "Все производственные календари удалены."
        
        
        revision += 1
    }
    
    
    // MARK: Результат
    
    private func makeMessage(
        report:
        ProductionCalendarSyncReport
    ) -> String {
        
        var parts:
        [String] = []
        
        
        if !report.downloadedYears.isEmpty {
            
            let years =
            report.downloadedYears
                .sorted()
                .map {
                    String($0)
                }
                .joined(
                    separator:
                        ", "
                )
            
            
            parts.append(
                "Загружено: "
                +
                years
                +
                "."
            )
        }
        
        
        if !report.refreshedYears.isEmpty {
            
            let years =
            report.refreshedYears
                .sorted()
                .map {
                    String($0)
                }
                .joined(
                    separator:
                        ", "
                )
            
            
            parts.append(
                "Обновлено: "
                +
                years
                +
                "."
            )
        }
        
        
        if !report.unavailableYears.isEmpty {
            
            let years =
            report.unavailableYears
                .sorted()
                .map {
                    String($0)
                }
                .joined(
                    separator:
                        ", "
                )
            
            
            parts.append(
                "В источнике пока нет календаря: "
                +
                years
                +
                "."
            )
        }
        
        
        if !report.failedYears.isEmpty {
            
            let years =
            report.failedYears
                .sorted()
                .map {
                    String($0)
                }
                .joined(
                    separator:
                        ", "
                )
            
            
            parts.append(
                "Не удалось загрузить: "
                +
                years
                +
                "."
            )
        }
        
        
        if !report.blockedByProblemYears.isEmpty {
            
            let years =
            report.blockedByProblemYears
                .sorted()
                .map {
                    String($0)
                }
                .joined(
                    separator:
                        ", "
                )
            
            
            parts.append(
                "Сначала нужно восстановить календари: "
                +
                years
                +
                "."
            )
        }
        
        
        if parts.isEmpty {
            
            return
            "Все производственные календари уже актуальны."
        }
        
        
        return parts.joined(
            separator:
                " "
        )
    }
}


// MARK: - Экран "Ещё"

struct SettingsRootView: View {
    
    @ObservedObject
    var store:
    AppStore
    
    
    @ObservedObject
    var absenceStore:
    AbsenceStore
    
    
    @ObservedObject
    var calendarSync:
    ProductionCalendarSyncModel
    
    
    @StateObject
    private var flightNormStore =
    FlightNormStore()
    
    
    var body: some View {
        
        NavigationStack {
            
            List {
                
                Section(
                    "Работа"
                ) {
                    
                    NavigationLink {
                        
                        WorkEventsListView(
                            store:
                                store
                        )
                        
                    } label: {
                        
                        HStack {
                            
                            Label(
                                "План работ",
                                systemImage:
                                    "calendar.badge.clock"
                            )
                            
                            
                            Spacer()
                            
                            
                            Text(
                                String(
                                    store.workEvents.count
                                )
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }
                    
                    
                    NavigationLink {
                        
                        AbsencesListView(
                            store:
                                absenceStore
                        )
                        
                    } label: {
                        
                        HStack {
                            
                            Label(
                                "Отсутствия",
                                systemImage:
                                    "calendar.badge.minus"
                            )
                            
                            
                            Spacer()
                            
                            
                            Text(
                                String(
                                    absenceStore.absences.count
                                )
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }
                }
                
                
                Section(
                    "Настройки"
                ) {
                    
                    NavigationLink {
                        
                        ProductionCalendarSettingsView(
                            calendarSync:
                                calendarSync
                        )
                        
                    } label: {
                        
                        Label(
                            "Производственный календарь",
                            systemImage:
                                "calendar.badge.checkmark"
                        )
                    }
                }
                
                
                Section(
                    "База"
                ) {
                    
                    NavigationLink {
                        
                        FlightNormsView(
                            store:
                                flightNormStore
                        )
                        
                    } label: {
                        
                        HStack {
                            
                            Label(
                                "Расчётное время • GitHub",
                                systemImage:
                                    "tablecells"
                            )
                            
                            
                            Spacer()
                            
                            
                            Text(
                                String(
                                    flightNormStore
                                        .versions
                                        .count
                                )
                            )
                            .foregroundStyle(
                                .secondary
                            )
                        }
                    }
                    
                    
                    HStack {
                        
                        Text(
                            "Легов"
                        )
                        
                        
                        Spacer()
                        
                        
                        Text(
                            String(
                                store.flights.count
                            )
                        )
                    }
                    
                    
                    HStack {
                        
                        Text(
                            "Полётных смен"
                        )
                        
                        
                        Spacer()
                        
                        
                        Text(
                            String(
                                store.duties.count
                            )
                        )
                    }
                }
            }
            
            
            .navigationTitle(
                "Ещё"
            )
        }
    }
}


// MARK: - Производственный календарь

struct ProductionCalendarSettingsView:
    View {
    
    @ObservedObject
    var calendarSync:
    ProductionCalendarSyncModel
    
    
    @State
    private var showDeleteConfirmation =
    false
    
    
    var currentYear: Int {
        
        moscowCalendar.component(
            .year,
            from:
                Date()
        )
    }
    
    
    var nextYear: Int {
        
        currentYear + 1
    }
    
    
    var requiredYears:
    [Int] {
        
        requiredProductionCalendarYears(
            currentYear:
                currentYear
        )
    }
    
    
    var problemYears:
    [Int] {
        
        productionCalendarProblemYears(
            currentYear:
                currentYear
        )
    }
    
    
    var loadedRequiredCount: Int {
        
        productionCalendarLoadedRequiredCount(
            currentYear:
                currentYear
        )
    }
    
    
    var allRequiredHealthy: Bool {
        
        problemYears.isEmpty
    }
    
    
    var nextYearReady: Bool {
        
        productionCalendarSupported(
            year:
                nextYear
        )
    }
    
    
    var displayedYears:
    [Int] {
        
        guard
            nextYear
                >=
                productionCalendarFirstYear
                
        else {
            
            return []
        }
        
        
        return Array(
            productionCalendarFirstYear
            ...
            nextYear
        )
    }
    
    
    // MARK: Название главной кнопки
    
    var actionTitle: String {
        
        if loadedRequiredCount == 0 {
            
            return
            "Загрузить производственные календари"
        }
        
        
        if !allRequiredHealthy {
            
            return
            "Загрузить недостающие календари"
        }
        
        
        if nextYearReady {
            
            return
            "Обновить календарь "
            +
            String(
                nextYear
            )
        }
        
        
        return
        "Найти календарь "
        +
        String(
            nextYear
        )
    }
    
    
    var body: some View {
        
        let _ =
        calendarSync.revision
        
        
        List {
            
            Section {
                
                CalendarDatabaseStatusRow(
                    loadedCount:
                        loadedRequiredCount,
                    totalCount:
                        requiredYears.count,
                    allRequiredHealthy:
                        allRequiredHealthy,
                    nextYearReady:
                        nextYearReady,
                    currentYear:
                        currentYear,
                    nextYear:
                        nextYear
                )
                
                
                HStack {
                    
                    Text(
                        "Страна"
                    )
                    
                    
                    Spacer()
                    
                    
                    Text(
                        productionCalendarCountryName
                        +
                        " ("
                        +
                        productionCalendarCountryCode
                        +
                        ")"
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
                
                
                HStack {
                    
                    Text(
                        "Синхронизация"
                    )
                    
                    
                    Spacer()
                    
                    
                    Text(
                        "Только вручную"
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
                
            } header: {
                
                Text(
                    "Производственный календарь"
                )
            }
            
            
            Section(
                "Календари"
            ) {
                
                ForEach(
                    displayedYears,
                    id:
                        \.self
                ) { year in
                    
                    ProductionCalendarYearRow(
                        year:
                            year,
                        isNextYear:
                            year == nextYear,
                        refreshToken:
                            calendarSync.revision
                    )
                }
            }
            
            
            Section {
                
                Button {
                    
                    Task {
                        
                        await calendarSync
                            .runPrimaryAction()
                    }
                    
                } label: {
                    
                    HStack(
                        spacing: 12
                    ) {
                        
                        if calendarSync
                            .isWorking {
                            
                            ProgressView()
                            
                        } else {
                            
                            Image(
                                systemName:
                                    allRequiredHealthy
                                ? "magnifyingglass"
                                : "icloud.and.arrow.down"
                            )
                        }
                        
                        
                        Text(
                            calendarSync.isWorking
                            ? "Подождите…"
                            : actionTitle
                        )
                        
                        
                        Spacer()
                    }
                }
                .disabled(
                    calendarSync.isWorking
                )
                
                
                if let message =
                    calendarSync.message {
                    
                    Text(
                        message
                    )
                    .font(.footnote)
                    .foregroundStyle(
                        .secondary
                    )
                }
                
                
                if let last =
                    productionCalendarLastManualActionDate() {
                    
                    HStack {
                        
                        Text(
                            "Последняя проверка"
                        )
                        
                        
                        Spacer()
                        
                        
                        Text(
                            formatDateTime(
                                last
                            )
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }
                
            } header: {
                
                Text(
                    "Ручное обновление"
                )
                
            } footer: {
                
                Text(
                    footerText
                )
            }
            
            
            Section(
                "Тестирование"
            ) {
                
                Button(
                    role:
                            .destructive
                ) {
                    
                    showDeleteConfirmation =
                    true
                    
                } label: {
                    
                    Label(
                        "Удалить все календари",
                        systemImage:
                            "trash"
                    )
                }
                
                
                Text(
                    "Удаляются только загруженные производственные календари. Рейсы, рабочие события и отсутствия останутся без изменений."
                )
                .font(.footnote)
                .foregroundStyle(
                    .secondary
                )
            }
            
            
            Section(
                "Проверка данных"
            ) {
                
                Label(
                    "Каждый сохранённый год проверяется на количество дней, страну и контрольную сумму.",
                    systemImage:
                        "checkmark.shield"
                )
                
                
                Label(
                    "Если календарь отсутствует или повреждён, он будет предложен для повторной загрузки.",
                    systemImage:
                        "arrow.clockwise"
                )
                
                
                Label(
                    "Никаких автоматических интернет-запросов приложение не выполняет.",
                    systemImage:
                        "hand.tap"
                )
            }
        }
        
        
        .navigationTitle(
            "Календарь РФ"
        )
        
        
        .navigationBarTitleDisplayMode(
            .inline
        )
        
        
        .alert(
            "Удалить все производственные календари?",
            isPresented:
                $showDeleteConfirmation
        ) {
            
            Button(
                "Отмена",
                role:
                        .cancel
            ) {}
            
            
            Button(
                "Удалить",
                role:
                        .destructive
            ) {
                
                calendarSync
                    .deleteAllCalendars()
            }
            
        } message: {
            
            Text(
                "Будут удалены только производственные календари. Остальные данные АэроУчёта не изменятся."
            )
        }
    }
    
    
    // MARK: Подсказка
    
    var footerText: String {
        
        if !allRequiredHealthy {
            
            return
            "Сначала приложение загрузит отсутствующие календари с "
            +
            String(
                productionCalendarFirstYear
            )
            +
            " по "
            +
            String(
                currentYear
            )
            +
            " год."
        }
        
        
        if nextYearReady {
            
            return
            "Все обязательные календари загружены. При необходимости можно повторно проверить календарь "
            +
            String(
                nextYear
            )
            +
            "."
        }
        
        
        return
        "Все обязательные календари актуальны. Теперь можно проверить, появился ли календарь "
        +
        String(
            nextYear
        )
        +
        "."
    }
}


// MARK: - Общий статус базы

struct CalendarDatabaseStatusRow:
    View {
    
    let loadedCount:
    Int
    
    let totalCount:
    Int
    
    let allRequiredHealthy:
    Bool
    
    let nextYearReady:
    Bool
    
    let currentYear:
    Int
    
    let nextYear:
    Int
    
    
    var body: some View {
        
        HStack(
            alignment:
                    .top,
            spacing: 12
        ) {
            
            Image(
                systemName:
                    statusIcon
            )
            .font(.title2)
            .foregroundStyle(
                statusColor
            )
            
            
            VStack(
                alignment:
                        .leading,
                spacing: 5
            ) {
                
                Text(
                    statusTitle
                )
                .bold()
                
                
                Text(
                    statusDetail
                )
                .font(.footnote)
                .foregroundStyle(
                    .secondary
                )
            }
        }
        .padding(
            .vertical,
            4
        )
    }
    
    
    var statusTitle: String {
        
        if loadedCount == 0 {
            
            return
            "Календари ещё не загружены"
        }
        
        
        if !allRequiredHealthy {
            
            return
            "Загружены не все календари"
        }
        
        
        if nextYearReady {
            
            return
            "Все производственные календари актуальны"
        }
        
        
        return
        "Все обязательные календари актуальны"
    }
    
    
    var statusDetail: String {
        
        if loadedCount == 0 {
            
            return
            "Нажмите кнопку ниже, чтобы загрузить календари РФ."
        }
        
        
        if !allRequiredHealthy {
            
            return
            "Загружено "
            +
            String(
                loadedCount
            )
            +
            " из "
            +
            String(
                totalCount
            )
            +
            " обязательных годов."
        }
        
        
        if nextYearReady {
            
            return
            "Календари с "
            +
            String(
                productionCalendarFirstYear
            )
            +
            " по "
            +
            String(
                nextYear
            )
            +
            " доступны."
        }
        
        
        return
        "Календари с "
        +
        String(
            productionCalendarFirstYear
        )
        +
        " по "
        +
        String(
            currentYear
        )
        +
        " доступны."
    }
    
    
    var statusIcon: String {
        
        if loadedCount == 0 {
            
            return
            "icloud.and.arrow.down"
        }
        
        
        if !allRequiredHealthy {
            
            return
            "exclamationmark.triangle.fill"
        }
        
        
        return
        "checkmark.seal.fill"
    }
    
    
    var statusColor: Color {
        
        if loadedCount == 0 {
            
            return .blue
        }
        
        
        if !allRequiredHealthy {
            
            return .orange
        }
        
        
        return .green
    }
}


// MARK: - Строка года

struct ProductionCalendarYearRow:
    View {
    
    let year:
    Int
    
    let isNextYear:
    Bool
    
    let refreshToken:
    Int
    
    
    var status:
    ProductionCalendarYearStatus {
        
        productionCalendarYearStatus(
            year:
                year
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
                    iconName
            )
            .foregroundStyle(
                iconColor
            )
            .frame(
                width: 24
            )
            
            
            VStack(
                alignment:
                        .leading,
                spacing: 3
            ) {
                
                HStack(
                    spacing: 8
                ) {
                    
                    Text(
                        String(
                            year
                        )
                    )
                    .bold()
                    
                    
                    if isNextYear {
                        
                        Text(
                            "следующий год"
                        )
                        .font(.caption2)
                        .padding(
                            .horizontal,
                            6
                        )
                        .padding(
                            .vertical,
                            2
                        )
                        .background {
                            
                            Capsule()
                                .fill(
                                    Color.blue
                                        .opacity(
                                            0.12
                                        )
                                )
                        }
                    }
                }
                
                
                Text(
                    detailText
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }
            
            
            Spacer()
            
            
            Text(
                stateText
            )
            .font(.subheadline)
            .foregroundStyle(
                iconColor
            )
        }
        .padding(
            .vertical,
            3
        )
    }
    
    
    var stateText: String {
        
        switch status.state {
            
        case .downloaded:
            return "Загружен"
            
        case .missing:
            return "Нет данных"
            
        case .corrupt:
            return "Ошибка"
        }
    }
    
    
    var detailText: String {
        
        switch status.state {
            
        case .downloaded:
            
            if let date =
                status.downloadedAt {
                
                return
                (
                    status.source
                    ??
                    "Интернет"
                )
                +
                " • "
                +
                formatDate(
                    date
                )
            }
            
            
            return
            status.source
            ??
            "Загружен"
            
            
        case .missing:
            
            if isNextYear {
                
                return
                "Можно проверить после загрузки основной базы"
            }
            
            
            return
            "Требуется загрузка"
            
            
        case .corrupt:
            
            return
            "Требуется повторная загрузка"
        }
    }
    
    
    var iconName: String {
        
        switch status.state {
            
        case .downloaded:
            return "checkmark.circle.fill"
            
        case .missing:
            return "circle.dashed"
            
        case .corrupt:
            return "exclamationmark.triangle.fill"
        }
    }
    
    
    var iconColor: Color {
        
        switch status.state {
            
        case .downloaded:
            return .green
            
        case .missing:
            return .secondary
            
        case .corrupt:
            return .orange
        }
    }
}
